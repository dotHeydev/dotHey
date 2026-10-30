# shellcheck shell=bash
. "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"

# Golden

test_relocate_moves_dotdot_into_agents_and_keeps_it_working() {
  dot setup --harness claude --yes
  dot relocate .agents/.dot --yes
  assert_success
  assert_file "$SANDBOX/.agents/.dot/.core/system/boot.sh"
  assert_no_file "$SANDBOX/.dot"
  assert_link_to "$SANDBOX/dot" "$SANDBOX/.agents/.dot/.core/system/bin/dot"
  assert_link_to "$SANDBOX/.claude/skills/dot-onboard" "$SANDBOX/.agents/.dot/.core/modules/onboarding/skills/dot-onboard"
  assert_link_to "$SANDBOX/AGENTS.md" "$SANDBOX/.agents/.dot/AGENTS.md"
  assert_contains "$(cat "$SANDBOX/.agents/.dot/AGENTS.md")" ".agents/.dot/"
  assert_not_contains "$(cat "$SANDBOX/.agents/.dot/AGENTS.md")" ".agents/.agents/"
  dot
  assert_success
}

test_commands_run_from_the_new_location() {
  dot relocate .agents/.dot --yes
  dot notes:create relocated
  assert_success
  assert_file "$(ls "$SANDBOX"/.agents/.dot/Notes/n*--relocated.md)"
}

test_setup_relocates_when_asked() {
  mkdir -p "$SANDBOX/.agents"
  dot setup --harness claude --dir .agents/.dot --yes
  assert_success
  assert_file "$SANDBOX/.agents/.dot/.core/system/boot.sh"
  assert_link_to "$SANDBOX/.claude/skills/dot-onboard" "$SANDBOX/.agents/.dot/.core/modules/onboarding/skills/dot-onboard"
}

# Edge

test_relocate_refuses_a_taken_place() {
  mkdir -p "$SANDBOX/.agents/.dot"
  : > "$SANDBOX/.agents/.dot/keep"
  dot relocate .agents/.dot --yes
  assert_failure
  assert_equal "$STATUS" 2
  assert_file "$DOTDOT/.core/system/boot.sh"
  assert_file "$SANDBOX/.agents/.dot/keep"
}

# Adversarial

test_relocate_refuses_places_outside_the_project() {
  local target
  for target in ../outside .git/dot .dot/inner /tmp/dotdot-elsewhere; do
    dot relocate "$target" --yes
    assert_failure "relocate to $target"
    assert_equal "$STATUS" 2
    assert_file "$DOTDOT/.core/system/boot.sh"
  done
  assert_no_file "$SANDBOX/../outside"
  assert_no_file /tmp/dotdot-elsewhere
}
