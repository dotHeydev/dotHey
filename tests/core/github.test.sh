#!/usr/bin/env bash

# Fake gh and curl in the sandbox: each logs its call to $SANDBOX/calls and
# acts as $SANDBOX/gh.mode (ok, fail, nologin) and $SANDBOX/curl.mode
# (archive, api, fail) say.
fake_github() {
  mkdir -p "$SANDBOX/bin"
  printf '%s\n' "${1:-ok}" > "$SANDBOX/gh.mode"
  printf '%s\n' "${2:-fail}" > "$SANDBOX/curl.mode"
  : > "$SANDBOX/calls"
  cat > "$SANDBOX/bin/gh" <<GH
#!/bin/sh
printf 'gh token=%s %s\n' "\${GH_TOKEN-none}" "\$1 \$2" >> "$SANDBOX/calls"
mode=\$(cat "$SANDBOX/gh.mode")
if [ "\$1 \$2" = "auth status" ]; then [ "\$mode" != nologin ]; exit; fi
[ "\$mode" = ok ] || { echo "HTTP 404: Not Found (https://api.github.com/repos/acme/repo)" >&2; exit 1; }
case "\$1 \$2" in
  "issue view") printf '7\tOPEN\ttask,task:todo\t2026-01-01T00:00:00Z\t2026-01-02T00:00:00Z\tA task\n' ;;
  "repo view") echo '{}' ;;
  api*) echo TARBALL ;;
esac
GH
  cat > "$SANDBOX/bin/curl" <<CURL
#!/bin/sh
headers=\$(cat)
out="" url="" write=""
while [ \$# -gt 0 ]; do
  case "\$1" in
    -o) out="\$2"; shift ;;
    -w) write="\$2"; shift ;;
    -X | --data-binary | --max-time | --max-filesize | --proto | --proto-redir | --config) shift ;;
    -*) ;;
    *) url="\$1" ;;
  esac
  shift
done
printf 'curl %s %s\n' "\$(printf '%s' "\$headers" | grep -o 'Bearer [^"]*' || echo anonymous)" "\$url" >> "$SANDBOX/calls"
mode=\$(cat "$SANDBOX/curl.mode")
case "\$url" in
  https://github.com/*) [ "\$mode" = archive ] || exit 22; echo TARBALL > "\$out" ;;
  *)
    if [ "\$mode" = api ]; then
      printf '{"number": 7, "state": "open", "title": "A task", "labels": [{"name": "task"}], "created_at": "2026-01-01T00:00:00Z", "updated_at": "2026-01-02T00:00:00Z"}' > "\$out"
      [ -z "\$write" ] || printf 200
    else
      printf '{"message": "Not Found"}' > "\$out"
      [ -n "\$write" ] || exit 22
      printf 404
    fi
    ;;
esac
CURL
  chmod +x "$SANDBOX/bin/gh" "$SANDBOX/bin/curl"
}

github() {
  core "PATH='$SANDBOX/bin':\$PATH; dot::use framework.integrations.github.service; ${2:-}
    framework.integrations.github.service::$1"
}

test_gh_runs_as_the_login_and_the_token_only_for_its_own_call() {
  fake_github ok
  github "issue acme/repo 7"
  assert_success
  assert_equal "$OUTPUT" "7	OPEN	task,task:todo	2026-01-01T00:00:00Z	2026-01-02T00:00:00Z	A task"
  assert_equal "$(grep -c 'gh token=none issue view' "$SANDBOX/calls")" "1"
  printf 'DOT_GH_TOKEN=secret-token\n' > "$SANDBOX/.env"
  : > "$SANDBOX/calls"
  core "PATH='$SANDBOX/bin':\$PATH; dot::use framework.integrations.github.service
    printf 'before:%s\n' \"\${GH_TOKEN-none}\"
    framework.integrations.github.service::can_reach acme/repo
    printf 'after:%s\n' \"\${GH_TOKEN-none}\""
  assert_success
  assert_equal "$OUTPUT" "before:none
after:none"
  assert_contains "$(cat "$SANDBOX/calls")" "gh token=secret-token repo view"
  assert_not_contains "$(cat "$SANDBOX/calls")" "auth status"
}

test_a_failing_gh_falls_back_to_the_api_with_the_same_token_only() {
  fake_github fail api
  printf 'DOT_GH_TOKEN=secret-token\n' > "$SANDBOX/.env"
  github "issue acme/repo 7"
  assert_success
  assert_equal "$OUTPUT" "7	OPEN	task	2026-01-01T00:00:00Z	2026-01-02T00:00:00Z	A task"
  assert_contains "$(cat "$SANDBOX/calls")" "curl Bearer secret-token https://api.github.com/repos/acme/repo/issues/7"
  assert_not_contains "$(cat "$SANDBOX/calls")" "gh token=none"
}

test_without_a_token_a_failing_gh_has_no_fallback() {
  fake_github fail api
  github "issue acme/repo 7"
  assert_failure
  assert_contains "$ERRORS" "Couldn't read issue #7 in acme/repo.
   Tried gh as your gh login: not found, or no access to it
   Tried API: no DOT_GH_TOKEN set
   → Please check that the repo exists and that the account can read it (a token needs that scope)."
  assert_not_contains "$(cat "$SANDBOX/calls")" "curl"
}

test_every_route_failing_names_each_attempt() {
  fake_github fail fail
  printf 'DOT_GH_TOKEN=secret-token\n' > "$SANDBOX/.env"
  github "issue acme/repo 7"
  assert_failure
  assert_contains "$ERRORS" "Tried gh as DOT_GH_TOKEN's owner: not found, or no access to it"
  assert_not_contains "$OUTPUT$ERRORS" "secret-token"
}

test_without_gh_or_a_login_the_error_says_what_to_set_up() {
  fake_github nologin fail
  github "issue acme/repo 7"
  assert_failure
  assert_contains "$ERRORS" "Tried gh: not logged in
   Tried API: no DOT_GH_TOKEN set
   → Please run gh auth login, or set DOT_GH_TOKEN in .env."
  github "issue acme/repo 7" "GITHUB_CLI=gh-missing"
  assert_failure
  assert_contains "$ERRORS" "Tried gh: not installed
   Tried API: no DOT_GH_TOKEN set
   → Please install gh (https://cli.github.com) and run gh auth login, or set DOT_GH_TOKEN in .env."
  printf 'DOT_GH_TOKEN=secret-token\n' > "$SANDBOX/.env"
  printf 'api\n' > "$SANDBOX/curl.mode"
  github "issue acme/repo 7" "GITHUB_CLI=gh-missing"
  assert_success "without gh, the token goes to the API"
}

test_downloads_try_the_public_archive_first() {
  fake_github ok archive
  github "download acme/repo main '$SANDBOX/plugin.tar.gz'"
  assert_success
  assert_equal "$(cat "$SANDBOX/plugin.tar.gz")" "TARBALL"
  assert_contains "$(cat "$SANDBOX/calls")" "curl anonymous https://github.com/acme/repo/archive/main.tar.gz"
  assert_not_contains "$(cat "$SANDBOX/calls")" "gh token"
  fake_github ok fail
  github "download acme/repo main '$SANDBOX/plugin.tar.gz'"
  assert_success
  assert_contains "$(cat "$SANDBOX/calls")" "gh token=none api"
}

test_the_repository_comes_from_the_origin_remote() {
  local url
  git -C "$SANDBOX" init -q
  for url in https://github.com/acme/repo.git git@github.com:acme/repo.git ssh://git@github.com/acme/repo; do
    git -C "$SANDBOX" remote remove origin 2>/dev/null || true
    git -C "$SANDBOX" remote add origin "$url"
    github "repository_of '$SANDBOX'"
    assert_equal "$OUTPUT" "acme/repo" "$url"
  done
}
