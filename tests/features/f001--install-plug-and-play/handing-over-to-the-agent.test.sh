# shellcheck shell=bash
. "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"

# Golden

test_the_default_setup_leaves_only_the_context_to_the_agent() {
  dot setup --harness claude --yes
  assert_success
  assert_equal "$(setting_value '.state.setup.pending[]')" "context"
}

test_centralizing_leaves_the_split_the_unsure_docs_and_a_check_to_the_agent() {
  own_instructions CLAUDE.md
  own_skill .claude/skills/mine
  printf '# Ideas\n' > "$SANDBOX/IDEAS.md"
  dot setup --harness claude --type centralize --yes
  assert_success
  assert_equal "$(setting_value '.state.setup.pending[]' | tr '\n' ' ')" "context split:CLAUDE.md unsure:IDEAS.md verify"
}

test_combining_leaves_the_project_s_files_to_it_but_raises_unsure_docs() {
  own_instructions CLAUDE.md
  printf '# Ideas\n' > "$SANDBOX/IDEAS.md"
  dot setup --harness claude --yes
  assert_success
  assert_equal "$(setting_value '.state.setup.pending[]' | tr '\n' ' ')" "context unsure:IDEAS.md"
}

test_a_ready_context_is_not_left_to_the_agent() {
  sandbox::settings '"state": {"isReady": true}'
  dot setup --harness claude --yes
  assert_success
  assert_equal "$(setting_value '.state.setup.pending[]')" ""
}

test_the_scan_hands_the_agent_the_choices_and_what_is_left() {
  dot setup --harness claude --type centralize --yes
  dot adopt --scan --json
  assert_success
  assert_equal "$(json_value "$OUTPUT" '.setup.harnesses[]')" "claude"
  assert_equal "$(json_value "$OUTPUT" '.setup.type')" "centralize"
  assert_equal "$(json_value "$OUTPUT" '.setup.location')" ".dot"
  assert_equal "$(json_value "$OUTPUT" '.setup.pending[]' | tr '\n' ' ')" "context verify"
}

test_the_agent_marks_what_it_finished() {
  own_instructions CLAUDE.md
  dot setup --harness claude --type centralize --yes
  dot setup:done split:CLAUDE.md
  assert_success
  assert_equal "$(setting_value '.state.setup.pending[]' | tr '\n' ' ')" "context verify"
}

# Edge

test_marking_what_isnt_left_fails_and_changes_nothing() {
  dot setup --harness claude --yes
  dot setup:done split:NOPE.md
  assert_failure
  assert_equal "$STATUS" 4
  assert_equal "$(setting_value '.state.setup.pending[]')" "context"
}

test_a_rerun_keeps_what_the_agent_already_finished() {
  printf '# Ideas\n' > "$SANDBOX/IDEAS.md"
  dot setup --harness claude --yes
  dot setup:done unsure:IDEAS.md
  dot setup --harness claude --yes
  assert_success
  assert_equal "$(setting_value '.state.setup.pending[]')" "context"
}

# Adversarial

