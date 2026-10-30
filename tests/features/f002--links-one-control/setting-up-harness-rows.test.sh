# shellcheck shell=bash
. "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"

# Golden

test_setup_keeps_rows_it_did_not_add() {
  links "link:@dot:AGENTS.md->AGENTS.md" "link:@dot:RULES.md->rules.md"
  dot setup --harness claude --yes
  dot setup --harness agents --yes
  assert_success
  assert_equal "$(map_value '["@dot:RULES.md"][]')" "rules.md"
  assert_link_to "$SANDBOX/rules.md" "$DOTDOT/RULES.md"
}

test_setup_keeps_no_copy_of_the_links() {
  dot setup --harness claude --yes
  assert_success
  assert_equal "$(setting_value '.state.setup.links')$(setting_value '.setup.links')" ""
}

test_unchoosing_a_harness_keeps_a_folder_a_chosen_one_reads() {
  dot setup --harness agents,codex --yes
  dot setup --harness agents --yes
  assert_success
  assert_link_to "$SANDBOX/.agents/skills/dot-onboard" "$DOTDOT/.core/modules/onboarding/skills/dot-onboard"
}

# Edge

test_rerunning_the_same_choice_leaves_the_links_as_they_were() {
  own_instructions CLAUDE.md
  dot setup --harness claude --type centralize --yes
  cp "$DOTDOT/dot.json" "$SANDBOX/before.json"
  dot setup --harness claude --type centralize --yes
  assert_success
  assert_equal "$(map_value .)" "$(setting_value .links "$SANDBOX/before.json")"
}

test_a_centralize_rerun_with_a_claude_md_writes_each_key_once() {
  own_instructions CLAUDE.md
  own_skill .claude/skills/mine
  dot setup --harness claude --type centralize --yes
  dot setup --harness claude --type centralize --yes
  assert_success
  assert_equal "$(grep -o '"@dot:Skills/\*"' "$DOTDOT/dot.json" | wc -l | tr -d ' ')" 1
}

test_a_harness_row_edited_by_hand_is_kept_and_the_harness_row_added_again() {
  dot setup --harness claude --yes
  delete_link '["@dotdotSkills"]'
  add_entry link @dotdotSkills .claude/mine/
  dot setup --harness claude --yes
  assert_success
  assert_equal "$(map_value '["@dotdotSkills"][]' | sort | tr '\n' ' ')" ".claude/mine/ .claude/skills/ "
}

# Adversarial

test_a_harness_never_chosen_never_has_its_rows_added() {
  dot setup --harness claude --yes
  assert_success
  assert_not_contains "$(map_value .)" ".cursor/"
}
