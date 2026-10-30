# shellcheck shell=bash
. "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"

# Golden

test_setup_keeps_rows_it_did_not_add() {
  links "link:@hey:AGENTS.md->AGENTS.md" "link:@hey:RULES.md->rules.md"
  hey setup --harness claude --yes
  hey setup --harness agents --yes
  assert_success
  assert_equal "$(map_value '["@hey:RULES.md"][]')" "rules.md"
  assert_link_to "$SANDBOX/rules.md" "$DOTHEY/RULES.md"
}

test_setup_keeps_no_copy_of_the_links() {
  hey setup --harness claude --yes
  assert_success
  assert_equal "$(setting_value '.state.setup.links')$(setting_value '.setup.links')" ""
}

test_unchoosing_a_harness_keeps_a_folder_a_chosen_one_reads() {
  hey setup --harness agents,codex --yes
  hey setup --harness agents --yes
  assert_success
  assert_link_to "$SANDBOX/.agents/skills/hey-onboard" "$DOTHEY/.core/modules/onboarding/skills/hey-onboard"
}

# Edge

test_rerunning_the_same_choice_leaves_the_links_as_they_were() {
  own_instructions CLAUDE.md
  hey setup --harness claude --type centralize --yes
  cp "$DOTHEY/hey.json" "$SANDBOX/before.json"
  hey setup --harness claude --type centralize --yes
  assert_success
  assert_equal "$(map_value .)" "$(setting_value .links "$SANDBOX/before.json")"
}

test_a_centralize_rerun_with_a_claude_md_writes_each_key_once() {
  own_instructions CLAUDE.md
  own_skill .claude/skills/mine
  hey setup --harness claude --type centralize --yes
  hey setup --harness claude --type centralize --yes
  assert_success
  assert_equal "$(grep -o '"@hey:Skills/\*"' "$DOTHEY/hey.json" | wc -l | tr -d ' ')" 1
}

test_a_harness_row_edited_by_hand_is_kept_and_the_harness_row_added_again() {
  hey setup --harness claude --yes
  delete_link '["@dotheySkills"]'
  add_entry link @dotheySkills .claude/mine/
  hey setup --harness claude --yes
  assert_success
  assert_equal "$(map_value '["@dotheySkills"][]' | sort | tr '\n' ' ')" ".claude/mine/ .claude/skills/ "
}

# Adversarial

test_a_harness_never_chosen_never_has_its_rows_added() {
  hey setup --harness claude --yes
  assert_success
  assert_not_contains "$(map_value .)" ".cursor/"
}
