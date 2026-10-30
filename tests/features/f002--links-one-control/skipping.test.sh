#!/usr/bin/env bash
. "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"

# Golden

test_a_skipped_row_is_never_linked() {
  links "link:@dot:RULES.md->rules.md" "skip:@dot:RULES.md->rules.md"
  dot link -y
  assert_success
  assert_no_file "$SANDBOX/rules.md"
}

test_skipping_a_linked_row_removes_its_link() {
  links "link:@dot:RULES.md->rules.md"
  dot link -y
  links "link:@dot:RULES.md->rules.md" "skip:@dot:RULES.md->rules.md"
  dot link -y
  assert_success
  assert_no_file "$SANDBOX/rules.md"
}

# Edge

test_setup_keeps_a_skip_on_a_row_a_chosen_harness_wants() {
  links "link:@dot:AGENTS.md->AGENTS.md" "skip:@dotdotSkills->.claude/skills/"
  dot setup --harness claude --yes
  assert_success
  assert_equal "$(map_value '.skip["@dotdotSkills"][]')" ".claude/skills/"
  assert_no_file "$SANDBOX/.claude/skills/dot-onboard"
}

test_unchoosing_a_harness_writes_no_skip() {
  dot setup --harness claude,agents --yes
  dot setup --harness agents --yes
  assert_success
  assert_equal "$(map_value '.skip')" "{}"
  assert_no_file "$SANDBOX/.claude/skills/dot-onboard"
}

test_a_plugin_s_skipped_suggestion_is_never_linked() {
  mkdir -p "$SANDBOX/widgets/dotdot"
  manifest "$SANDBOX/widgets" "link:plugin.json->widgets.json"
  add_plugin acme/widgets "$SANDBOX/widgets"
  add_entry skip "@plugin:acme.widgets:plugin.json" "widgets.json"
  take_suggestions acme/widgets
  assert_no_file "$SANDBOX/widgets.json"
}
