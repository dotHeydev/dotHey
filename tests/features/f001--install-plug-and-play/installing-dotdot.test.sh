# shellcheck shell=bash
. "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"

# A local archive shaped like GitHub's, and an empty project to install into.
installer() {
  if [ ! -f "$SANDBOX/dotdot.tar.gz" ]; then
    mkdir -p "$SANDBOX/archive/dotdot-main"
    cp -R "$SOURCE_DIR" "$SANDBOX/archive/dotdot-main/dist"
    tar -czf "$SANDBOX/dotdot.tar.gz" -C "$SANDBOX/archive" dotdot-main
  fi
  mkdir -p "$SANDBOX/project"
  run bash -c "cd '$SANDBOX/project' && DOT_INSTALL_ARCHIVE='$SANDBOX/dotdot.tar.gz' DOT_NO_INPUT=1 bash '$REPOSITORY_DIR/install.sh' $*"
}

# Golden

test_install_without_a_person_links_only_agents_md() {
  installer
  assert_success
  assert_file "$SANDBOX/project/.dot/.core/system/boot.sh"
  assert_link_to "$SANDBOX/project/dot" "$SANDBOX/project/.dot/.core/system/bin/dot"
  assert_link_to "$SANDBOX/project/AGENTS.md" "$SANDBOX/project/.dot/AGENTS.md"
  assert_no_file "$SANDBOX/project/.claude"
  assert_equal "$(setting_value '.state.setup.harnesses[]' "$SANDBOX/project/.dot/dot.json")" ""
  [ -z "$(find "$SANDBOX/project" -maxdepth 1 -name '.dot-install.*')" ] || fail "the download was left in the project"
}

test_install_with_setup_flags_runs_setup() {
  installer --harness agents --type parallel --yes
  assert_success
  assert_equal "$(setting_value '.state.setup.harnesses[]' "$SANDBOX/project/.dot/dot.json")" "agents"
  assert_link_to "$SANDBOX/project/.agents/skills/dot-onboard" "$SANDBOX/project/.dot/.core/modules/onboarding/skills/dot-onboard"
}

test_install_into_agents() {
  installer --dir .agents/.dot
  assert_success
  assert_file "$SANDBOX/project/.agents/.dot/.core/system/boot.sh"
  assert_no_file "$SANDBOX/project/.dot"
  assert_link_to "$SANDBOX/project/AGENTS.md" "$SANDBOX/project/.agents/.dot/AGENTS.md"
  assert_contains "$(cat "$SANDBOX/project/.agents/.dot/AGENTS.md")" ".agents/.dot/"
  run bash -c "cd '$SANDBOX/project' && bash ./dot"
  assert_success
}

# Edge

test_install_over_an_existing_dotdot_stops_without_a_terminal() {
  installer
  : > "$SANDBOX/project/.dot/marker"
  installer
  assert_failure
  assert_equal "$STATUS" 1
  assert_file "$SANDBOX/project/.dot/marker"
}

test_a_broken_download_leaves_nothing_behind() {
  mkdir -p "$SANDBOX/project"
  printf 'not an archive' > "$SANDBOX/dotdot.tar.gz"
  installer
  assert_failure
  assert_equal "$STATUS" 1
  assert_no_file "$SANDBOX/project/.dot"
  assert_no_file "$SANDBOX/project/dot"
  assert_equal "$(ls -A "$SANDBOX/project")" ""
}

# Adversarial

test_install_refuses_a_dir_outside_the_project() {
  local dir
  for dir in ../outside /tmp/dotdot-elsewhere .git/dot; do
    installer --dir "$dir"
    assert_failure "install into $dir"
    assert_equal "$STATUS" 1
    assert_equal "$(ls -A "$SANDBOX/project")" ""
  done
  assert_no_file "$SANDBOX/outside"
}

