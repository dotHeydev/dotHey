#!/usr/bin/env bash
. "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"

# Golden

test_nothing_is_built_for_a_chosen_harness_without_rows() {
  owned_agent reviewer
  dot setup --harness codex --yes
  delete_link '["@dot:Agents/*"]'
  delete_link '["@dotdotAgents"]'
  dot link -y
  assert_success
  assert_no_file "$DOTDOT/.harnesses/codex"
}

test_an_interrupted_setup_shows_apply_pending() {
  owned_agent reviewer
  failing_codex_render
  dot setup --harness codex --yes
  assert_failure
  dot adopt --scan --json
  assert_equal "$(json_value "$OUTPUT" '.setup.harnesses[]')" "codex"
  assert_equal "$(json_value "$OUTPUT" '.setup.pending[0]')" "apply"
}

test_rerunning_an_interrupted_setup_clears_apply() {
  owned_agent reviewer
  cp "$DOTDOT/.core/harnesses/codex/harness.sh" "$SANDBOX/harness.sh"
  failing_codex_render
  dot setup --harness codex --yes
  cp "$SANDBOX/harness.sh" "$DOTDOT/.core/harnesses/codex/harness.sh"
  dot setup --harness codex --yes
  assert_success
  assert_not_contains "$(setting_value '.state.setup.pending[]')" "apply"
}

# Edge

test_a_finished_setup_leaves_no_apply() {
  dot setup --harness claude --yes
  assert_success
  assert_not_contains "$(setting_value '.state.setup.pending[]')" "apply"
}

# Adversarial

test_the_agent_cannot_mark_apply_done() {
  owned_agent reviewer
  failing_codex_render
  dot setup --harness codex --yes
  dot setup:done apply
  assert_failure
  assert_equal "$STATUS" 4
  assert_equal "$(setting_value '.state.setup.pending[0]')" "apply"
}
