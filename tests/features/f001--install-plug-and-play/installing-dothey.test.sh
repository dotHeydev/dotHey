# shellcheck shell=bash
. "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"

# A local archive shaped like GitHub's, and an empty project to install into.
installer() {
  if [ ! -f "$SANDBOX/dothey.tar.gz" ]; then
    mkdir -p "$SANDBOX/archive/dothey-main"
    cp -R "$SOURCE_DIR" "$SANDBOX/archive/dothey-main/$SOURCE_NAME"
    tar -czf "$SANDBOX/dothey.tar.gz" -C "$SANDBOX/archive" dothey-main
  fi
  mkdir -p "$SANDBOX/project"
  run bash -c "cd '$SANDBOX/project' && HEY_INSTALL_ARCHIVE='$SANDBOX/dothey.tar.gz' HEY_NO_INPUT=1 bash '$REPOSITORY_DIR/install.sh' $*"
}

# Golden

test_install_without_a_person_links_only_agents_md() {
  installer
  assert_success
  assert_file "$SANDBOX/project/.hey/.core/system/boot.sh"
  assert_link_to "$SANDBOX/project/hey" "$SANDBOX/project/.hey/.core/system/bin/hey"
  assert_link_to "$SANDBOX/project/AGENTS.md" "$SANDBOX/project/.hey/AGENTS.md"
  assert_no_file "$SANDBOX/project/.claude"
  assert_equal "$(setting_value '.state.setup.harnesses[]' "$SANDBOX/project/.hey/hey.json")" ""
  [ -z "$(find "$SANDBOX/project" -maxdepth 1 -name '.hey-install.*')" ] || fail "the download was left in the project"
}

test_install_with_setup_flags_runs_setup() {
  installer --harness agents --type parallel --yes
  assert_success
  assert_equal "$(setting_value '.state.setup.harnesses[]' "$SANDBOX/project/.hey/hey.json")" "agents"
  assert_link_to "$SANDBOX/project/.agents/skills/hey-onboard" "$SANDBOX/project/.hey/.core/modules/onboarding/skills/hey-onboard"
}

test_install_into_agents() {
  installer --dir .agents/.hey
  assert_success
  assert_file "$SANDBOX/project/.agents/.hey/.core/system/boot.sh"
  assert_no_file "$SANDBOX/project/.hey"
  assert_link_to "$SANDBOX/project/AGENTS.md" "$SANDBOX/project/.agents/.hey/AGENTS.md"
  assert_contains "$(cat "$SANDBOX/project/.agents/.hey/AGENTS.md")" ".agents/.hey/"
  run bash -c "cd '$SANDBOX/project' && bash ./hey"
  assert_success
}

# Edge

test_install_over_an_existing_dothey_stops_without_a_terminal() {
  installer
  : > "$SANDBOX/project/.hey/marker"
  installer
  assert_failure
  assert_equal "$STATUS" 1
  assert_file "$SANDBOX/project/.hey/marker"
}

test_a_broken_download_leaves_nothing_behind() {
  mkdir -p "$SANDBOX/project"
  printf 'not an archive' > "$SANDBOX/dothey.tar.gz"
  installer
  assert_failure
  assert_equal "$STATUS" 1
  assert_no_file "$SANDBOX/project/.hey"
  assert_no_file "$SANDBOX/project/hey"
  assert_equal "$(ls -A "$SANDBOX/project")" ""
}

# Adversarial

test_install_refuses_a_dir_outside_the_project() {
  local dir
  for dir in ../outside /tmp/dothey-elsewhere .git/hey; do
    installer --dir "$dir"
    assert_failure "install into $dir"
    assert_equal "$STATUS" 1
    assert_equal "$(ls -A "$SANDBOX/project")" ""
  done
  assert_no_file "$SANDBOX/outside"
}

