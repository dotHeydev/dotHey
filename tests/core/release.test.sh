# shellcheck shell=bash

test_release_settings_are_required() {
  git -C "$SANDBOX" init -q
  hey release:create 1.0.0
  assert_failure
  assert_equal "$STATUS" 1
}

test_release_remotes_must_be_set_and_https_without_credentials() {
  hey release:token github
  assert_failure
  assert_equal "$STATUS" 1
  sandbox::settings '"release": {"remotes": {"example": "https://github.com/_USER_/_REPO_.git"}}'
  hey release:token example
  assert_failure "an example remote is never used"
  assert_equal "$STATUS" 1
  sandbox::settings '"release": {"remotes": {"github": "https://user:secret@github.com/acme/repo.git"}}'
  hey release:token github
  assert_failure
  assert_equal "$STATUS" 1
}

release_repository() {
  git -C "$SANDBOX" init -q
  printf 'tracked\n' > "$SANDBOX/tracked.txt"
  printf '.hey/\nbuild/\n.env\n' > "$SANDBOX/.gitignore"
  git -C "$SANDBOX" add tracked.txt .gitignore
  git -C "$SANDBOX" -c user.name=t -c user.email=t@t -c commit.gpgsign=false commit -qm initial
}

test_release_exclusions_stay_inside_the_project_and_never_ship_the_env() {
  local entry reason
  release_repository
  mkdir -p "$SANDBOX/build"
  : > "$SANDBOX/build/out"
  : > "$SANDBOX/.env"
  while IFS='|' read -r entry reason; do
    sandbox::settings "\"release\": {\"exclude\": [\"$entry\"]}"
    core "cd '$SANDBOX'; hey::use core.modules.release.service; core.modules.release.service::read_exclusions"
    assert_failure "$entry"
    assert_equal "$STATUS" 1
  done <<'CASES'
../outside|outside the project
!.env|holds the project's .env
!tracked.txt|must be a git-ignored path
track*|not a start (x*)
CASES
  sandbox::settings '"release": {"exclude": "@env:RELEASE_EXCLUDE"}'
  printf 'RELEASE_EXCLUDE=["!build", ".gitignore"]\n' > "$SANDBOX/.env"
  core "cd '$SANDBOX'; hey::use core.modules.release.service; core.modules.release.service::read_exclusions; printf '%s\n' \"\${RELEASE_COPIED[@]}\" \"\${RELEASE_EXCLUDED[@]}\""
  assert_success
  assert_equal "$OUTPUT" "build
.gitignore"
}

test_release_stops_only_on_changes_to_what_it_ships() {
  release_repository
  printf 'other\n' > "$SANDBOX/other.txt"
  git -C "$SANDBOX" add other.txt
  git -C "$SANDBOX" -c user.name=t -c user.email=t@t -c commit.gpgsign=false commit -qm other
  sandbox::settings '"release": {"exclude": ["other.txt", "scratch", "hey", ".stderr"]}'
  printf 'edited\n' > "$SANDBOX/other.txt"
  mkdir -p "$SANDBOX/scratch"
  : > "$SANDBOX/scratch/untracked"
  core "cd '$SANDBOX'; hey::use core.modules.release.service; core.modules.release.service::read_exclusions; core.modules.release.service::ships_clean"
  assert_success "changes outside the export must not count"
  : > "$SANDBOX/untracked-shipped"
  core "cd '$SANDBOX'; hey::use core.modules.release.service; core.modules.release.service::read_exclusions; core.modules.release.service::ships_clean"
  assert_failure "an untracked file in the export must count"
  assert_equal "$STATUS" 1
  rm "$SANDBOX/untracked-shipped"
  printf 'edited\n' > "$SANDBOX/tracked.txt"
  core "cd '$SANDBOX'; hey::use core.modules.release.service; core.modules.release.service::read_exclusions; core.modules.release.service::ships_clean"
  assert_failure "a change to a shipped file must count"
  assert_equal "$STATUS" 1
}

test_release_warns_only_of_exclusions_that_match_nothing() {
  release_repository
  mkdir -p "$SANDBOX/build"
  sandbox::settings '"release": {"exclude": ["tracked.txt", "build", ".env", "typo.txt"]}'
  core "cd '$SANDBOX'; hey::use core.modules.release.service; core.modules.release.service::read_exclusions; printf '%s\n' \"\${RELEASE_WARNINGS[@]}\""
  assert_success
  assert_equal "$OUTPUT" "release.exclude lists typo.txt, which is neither committed nor git-ignored; nothing to leave out."
}

test_release_export_refuses_secrets() {
  local destination="$SANDBOX/export"
  mkdir -p "$destination"
  printf 'token=ghp_%s\n' "$(fake_secret 9)" > "$destination/config.txt"
  core "hey::use core.modules.release.service; RELEASE_DESTINATION='$destination'; core.modules.release.service::scan_secrets"
  assert_failure
  assert_equal "$STATUS" 1
  assert_contains "$ERRORS" "config.txt"
  printf 'nothing to see\n' > "$destination/config.txt"
  core "hey::use core.modules.release.service; RELEASE_DESTINATION='$destination'; core.modules.release.service::scan_secrets"
  assert_success
}

test_release_export_refuses_secret_assignments_without_showing_them() {
  local destination="$SANDBOX/export" line fake
  fake=$(fake_secret)
  mkdir -p "$destination"
  while IFS= read -r line; do
    printf '%s\n' "$line" > "$destination/config.txt"
    core "hey::use core.modules.release.service; RELEASE_DESTINATION='$destination'; core.modules.release.service::scan_secrets"
    assert_failure "$line must be refused"
    assert_equal "$STATUS" 1
    assert_contains "$ERRORS" "config.txt:1"
    assert_not_contains "$ERRORS" "$fake"
  done <<CASES
STRIPE_API_KEY=$fake
  "client_secret": "$fake",
db_password: $fake
xoxb-$fake
glpat-$fake
CASES
  printf 'GH_TOKEN=\nTOKEN=short\ntoken = os.environ["TOKEN"]\napi_key=${API_KEY}\nSECRET=%s # dothey:not-a-secret\nTOKEN_PREFIX="HEY_RELEASE_TOKEN_"\n# settings and secrets: HEY_ACME_WIDGETS__ for\nHEY_GH_TOKEN=from-environment\n' "$fake" > "$destination/config.txt"
  core "hey::use core.modules.release.service; RELEASE_DESTINATION='$destination'; core.modules.release.service::scan_secrets"
  assert_success
}

test_release_commits_and_tags_as_its_author_whatever_the_environment_says() {
  command -v ssh-keygen >/dev/null && command -v ssh-agent >/dev/null || return 0
  release_repository
  mkdir -p "$SANDBOX/home/.ssh"
  ssh-keygen -q -t ed25519 -N '' -C release -f "$SANDBOX/home/.ssh/release" || fail "could not make a signing key"
  chmod 600 "$SANDBOX/home/.ssh/release"
  core "hey::use core.modules.release.service
    export HOME='$SANDBOX/home' GIT_COMMITTER_NAME=GitHub GIT_COMMITTER_EMAIL=noreply@github.com GIT_AUTHOR_EMAIL=other@x.test
    RELEASE_PROJECT='$SANDBOX' RELEASE_DESTINATION='$SANDBOX/build' RELEASE_SIGNING_NAME=release
    RELEASE_AUTHOR_NAME='Rel Author' RELEASE_AUTHOR_EMAIL=rel@x.test RELEASE_COPIED=()
    core.modules.release.service::check_signing_identity
    core.modules.release.service::prepare_repository main v1.0.0
    core.modules.release.service::configure_signing
    core.modules.release.service::start_agent
    printf 'shipped\n' > '$SANDBOX/build/tracked.txt'
    core.modules.release.service::commit v1.0.0
    core.modules.release.service::stop_agent"
  assert_success
  assert_equal "$(git -C "$SANDBOX/build" log -1 --format='%an <%ae> %cn <%ce>')" "Rel Author <rel@x.test> Rel Author <rel@x.test>"
  assert_equal "$(git -C "$SANDBOX/build" for-each-ref --format='%(taggername) %(taggeremail)' refs/tags/v1.0.0)" "Rel Author <rel@x.test>"
}


test_release_writes_its_version_into_the_files_it_names() {
  local destination="$SANDBOX/export"
  mkdir -p "$destination/dist"
  printf '{\n  "state": {\n    "version": "",\n    "commit": ""\n  }\n}\n' > "$destination/dist/hey.json"
  sandbox::settings '"release": {"versionFiles": {"dist/hey.json": "state.version"}}'
  core "hey::use core.modules.release.service; RELEASE_DESTINATION='$destination'; core.modules.release.service::stamp_version 1.2.0"
  assert_success
  assert_equal "$(json_value "$(cat "$destination/dist/hey.json")" .state.version)" "1.2.0"
  assert_equal "$(json_value "$(cat "$destination/dist/hey.json")" .state.commit)" ""
}

test_release_stops_when_a_version_file_isnt_in_the_release() {
  local destination="$SANDBOX/export"
  mkdir -p "$destination"
  sandbox::settings '"release": {"versionFiles": {"dist/hey.json": "state.version"}}'
  core "hey::use core.modules.release.service; RELEASE_DESTINATION='$destination'; core.modules.release.service::stamp_version 1.2.0"
  assert_failure
  assert_equal "$STATUS" 1
}

test_release_never_writes_a_version_outside_the_release() {
  local destination="$SANDBOX/export"
  mkdir -p "$destination"
  printf '{"state": {}}\n' > "$SANDBOX/outside.json"
  sandbox::settings '"release": {"versionFiles": {"../outside.json": "state.version"}}'
  core "hey::use core.modules.release.service; RELEASE_DESTINATION='$destination'; core.modules.release.service::stamp_version 1.2.0"
  assert_failure
  assert_equal "$(cat "$SANDBOX/outside.json")" '{"state": {}}'
}
