# shellcheck shell=bash
. "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"

# Golden

test_deleting_a_row_unlinks_what_it_linked() {
  hey setup --harness claude --yes
  delete_link '["@dotheySkills"]'
  hey link -y
  assert_success
  assert_no_file "$SANDBOX/.claude/skills/hey-onboard"
  assert_link_to "$SANDBOX/AGENTS.md" "$DOTHEY/AGENTS.md"
}

test_deleting_an_append_row_takes_its_section_out() {
  own_instructions CLAUDE.md
  hey setup --harness claude --yes
  delete_link '.append["@harness:claude:imports/CLAUDE.md"]'
  hey link -y
  assert_success
  assert_not_contains "$(cat "$SANDBOX/CLAUDE.md")" "@AGENTS.md"
  assert_contains "$(cat "$SANDBOX/CLAUDE.md")" "Keep this line."
}

# Edge

test_a_link_a_row_wants_is_made_again_after_deleting_it_by_hand() {
  hey setup --harness claude --yes
  rm -- "$SANDBOX/.claude/skills/hey-onboard"
  hey link -y
  assert_success
  assert_link_to "$SANDBOX/.claude/skills/hey-onboard" "$DOTHEY/.core/modules/onboarding/skills/hey-onboard"
}

test_a_hand_made_link_into_dothey_with_no_row_is_previewed_and_removed() {
  hey setup --harness claude --yes
  ln -s ../../.hey/RULES.md "$SANDBOX/.claude/skills/stray"
  hey link --preview --json
  assert_success
  assert_contains "$(json_value "$OUTPUT" '.changes[] | select(.action == "prune") | .destination')" ".claude/skills/stray"
  hey link -y
  assert_success
  assert_no_file "$SANDBOX/.claude/skills/stray"
}

test_a_link_out_of_dothey_is_left_alone() {
  hey setup --harness claude --yes
  printf 'mine\n' > "$SANDBOX/mine.md"
  ln -s ../../mine.md "$SANDBOX/.claude/skills/mine"
  hey link -y
  assert_success
  assert_link_to "$SANDBOX/.claude/skills/mine" "$SANDBOX/mine.md"
}

test_a_folder_two_rows_share_keeps_the_other_rows_link() {
  links "link:@hey:RULES.md->docs/rules.md" "link:@hey:SECURITY.md->docs/security.md"
  hey link -y
  delete_link '["@hey:RULES.md"]'
  hey link -y
  assert_success
  assert_no_file "$SANDBOX/docs/rules.md"
  assert_link_to "$SANDBOX/docs/security.md" "$DOTHEY/SECURITY.md"
}

# Adversarial

test_a_row_aimed_into_git_is_refused() {
  mkdir -p "$SANDBOX/.git"
  links "link:@hey:RULES.md->.git/hooks/pre-commit"
  hey link -y
  assert_failure
  assert_no_file "$SANDBOX/.git/hooks/pre-commit"
}

test_pruning_never_removes_the_projects_own_files_in_a_known_folder() {
  hey setup --harness claude --yes
  own_skill .claude/skills/mine
  hey link -y
  assert_success
  assert_file "$SANDBOX/.claude/skills/mine/SKILL.md"
}
