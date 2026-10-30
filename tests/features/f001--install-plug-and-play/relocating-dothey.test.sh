# shellcheck shell=bash
. "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"

# Golden

test_relocate_moves_dothey_into_agents_and_keeps_it_working() {
  hey setup --harness claude --yes
  hey relocate .agents/.hey --yes
  assert_success
  assert_file "$SANDBOX/.agents/.hey/.core/system/boot.sh"
  assert_no_file "$SANDBOX/.hey"
  assert_link_to "$SANDBOX/hey" "$SANDBOX/.agents/.hey/.core/system/bin/hey"
  assert_link_to "$SANDBOX/.claude/skills/hey-onboard" "$SANDBOX/.agents/.hey/.core/modules/onboarding/skills/hey-onboard"
  assert_link_to "$SANDBOX/AGENTS.md" "$SANDBOX/.agents/.hey/AGENTS.md"
  assert_contains "$(cat "$SANDBOX/.agents/.hey/AGENTS.md")" ".agents/.hey/"
  assert_not_contains "$(cat "$SANDBOX/.agents/.hey/AGENTS.md")" ".agents/.agents/"
  hey
  assert_success
}

test_commands_run_from_the_new_location() {
  hey relocate .agents/.hey --yes
  hey notes:create relocated
  assert_success
  assert_file "$(ls "$SANDBOX"/.agents/.hey/Notes/n*--relocated.md)"
}

test_setup_relocates_when_asked() {
  mkdir -p "$SANDBOX/.agents"
  hey setup --harness claude --dir .agents/.hey --yes
  assert_success
  assert_file "$SANDBOX/.agents/.hey/.core/system/boot.sh"
  assert_link_to "$SANDBOX/.claude/skills/hey-onboard" "$SANDBOX/.agents/.hey/.core/modules/onboarding/skills/hey-onboard"
}

# Edge

test_relocate_refuses_a_taken_place() {
  mkdir -p "$SANDBOX/.agents/.hey"
  : > "$SANDBOX/.agents/.hey/keep"
  hey relocate .agents/.hey --yes
  assert_failure
  assert_equal "$STATUS" 2
  assert_file "$DOTHEY/.core/system/boot.sh"
  assert_file "$SANDBOX/.agents/.hey/keep"
}

# Adversarial

test_relocate_refuses_places_outside_the_project() {
  local target
  for target in ../outside .git/hey .hey/inner /tmp/dothey-elsewhere; do
    hey relocate "$target" --yes
    assert_failure "relocate to $target"
    assert_equal "$STATUS" 2
    assert_file "$DOTHEY/.core/system/boot.sh"
  done
  assert_no_file "$SANDBOX/../outside"
  assert_no_file /tmp/dothey-elsewhere
}
