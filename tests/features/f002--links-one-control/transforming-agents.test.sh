#!/usr/bin/env bash
. "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"

# Golden

test_a_harness_reading_another_format_gets_plain_rows() {
  owned_agent reviewer
  dot setup --harness codex --yes
  assert_success
  assert_equal "$(map_value '["@dot:Agents/*"][]')" ".codex/agents/"
  assert_not_contains "$(map_value .)" ".harnesses"
}

test_agents_linked_into_a_folder_with_a_format_are_built_in_it() {
  owned_agent reviewer "Reviews changes." "You review code."
  links "link:@dot:Agents/*->.codex/agents/"
  dot link -y
  assert_success
  assert_contains "$(cat "$SANDBOX/.codex/agents/reviewer.toml")" 'name = "reviewer"'
  assert_no_file "$SANDBOX/.codex/agents/reviewer.md"
}

# Edge

test_a_harness_never_chosen_in_setup_still_gets_its_format() {
  owned_agent reviewer
  links "link:@dot:Agents/*->.github/agents/"
  dot link -y
  assert_success
  assert_equal "$(cat "$SANDBOX/.github/agents/reviewer.agent.md")" "$(cat "$DOTDOT/Agents/reviewer.md")"
}

test_a_shared_folder_gets_agents_as_they_are() {
  owned_agent reviewer
  links "link:@dot:Agents/*->.agents/agents/"
  dot link -y
  assert_success
  assert_link_to "$SANDBOX/.agents/agents/reviewer.md" "$DOTDOT/Agents/reviewer.md"
}

test_a_failed_build_leaves_its_rows_as_they_were_and_links_the_rest() {
  owned_agent reviewer
  links "link:@dot:Agents/*->.codex/agents/" "link:@dot:RULES.md->rules.md"
  dot link -y
  failing_codex_render
  owned_agent tester
  links "link:@dot:Agents/*->.codex/agents/" "link:@dot:RULES.md->rules.md" "link:@dot:SECURITY.md->security.md"
  dot link -y
  assert_failure
  assert_equal "$STATUS" 1
  assert_file "$SANDBOX/.codex/agents/reviewer.toml"
  assert_no_file "$SANDBOX/.codex/agents/tester.toml"
  assert_link_to "$SANDBOX/security.md" "$DOTDOT/SECURITY.md"
}

test_a_build_no_row_uses_is_deleted() {
  owned_agent reviewer
  dot setup --harness codex --yes
  links "link:@dot:AGENTS.md->AGENTS.md"
  dot link -y
  assert_success
  assert_no_file "$DOTDOT/.harnesses/codex"
  assert_no_file "$SANDBOX/.codex/agents/reviewer.toml"
}

# Adversarial

test_two_harnesses_giving_one_folder_different_formats_fail_only_its_rows() {
  owned_agent reviewer
  copy_harness copilot rival
  harness_data rival agents '{"dir": ".codex/agents/", "file": "{name}.agent.md"}'
  links "link:@dot:Agents/*->.codex/agents/" "link:@dot:RULES.md->rules.md"
  dot link -y
  assert_failure
  assert_equal "$STATUS" 1
  assert_no_file "$SANDBOX/.codex/agents/reviewer.toml"
  assert_no_file "$SANDBOX/.codex/agents/reviewer.agent.md"
  assert_link_to "$SANDBOX/rules.md" "$DOTDOT/RULES.md"
}
