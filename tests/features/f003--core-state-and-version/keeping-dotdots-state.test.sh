#!/usr/bin/env bash
. "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"

# Golden

test_setup_records_its_choice_under_state() {
  dot setup --harness claude --yes
  assert_success
  assert_equal "$(setting_value '.state.setup.harnesses[]')" "claude"
  assert_equal "$(setting_value '.state.setup.pending[]')" "context"
  assert_equal "$(setting_value '.setup')" ""
}

test_the_agent_marks_what_it_finished_under_state() {
  dot setup --harness claude --yes
  dot setup:done context
  assert_success
  assert_equal "$(setting_value '.state.setup.done[]')" "context"
}

test_migrations_are_recorded_under_state() {
  printf '#!/usr/bin/env bash\n\nDESCRIPTION="Sample."\n\nmigrate() {\n  :\n}\n' > "$DOTDOT/.core/system/migrations/0001-sample.sh"
  dot migrate -y
  assert_success
  assert_equal "$(setting_value '.state.migrations[]')" "0001-sample"
}

test_dotdots_defaults_hold_no_state() {
  assert_equal "$(setting_value '.setup' "$DOTDOT/.core/dot.defaults.json")" ""
  assert_equal "$(setting_value '.state' "$DOTDOT/.core/dot.defaults.json")" ""
}

test_dotdot_saves_its_state_under_state() {
  core "dot::save_state commit '\"$COMMIT\"'"
  assert_success
  assert_equal "$(setting_value '.state.commit')" "$COMMIT"
}

# Edge

test_an_unrecorded_choice_reads_as_none() {
  dot adopt --scan --json
  assert_success
  assert_contains "$OUTPUT" '"setup":{"harnesses":[],"type":null'
}

test_state_reads_its_default_when_unset() {
  core "dot::state setup.type 'none'"
  assert_success
  assert_equal "$OUTPUT" "none"
}

# Adversarial

test_a_state_value_pointing_at_env_is_refused() {
  printf 'COMMIT=%s\n' "$COMMIT" > "$SANDBOX/.env"
  sandbox::settings '"state": {"commit": "@env:COMMIT", "migrations": []}'
  core "dot::state commit ''"
  assert_failure
  assert_equal "$STATUS" 1
  assert_not_contains "$OUTPUT" "$COMMIT"
}

test_reading_state_as_a_setting_is_refused() {
  core "dot::setting state.commit ''"
  assert_failure
  assert_contains "$ERRORS" "dot::state"
}

test_saving_state_as_a_setting_is_refused() {
  cp "$DOTDOT/dot.json" "$SANDBOX/before.json"
  core "dot::save_setting state.commit '\"$COMMIT\"'"
  assert_failure
  assert_equal "$(cat "$DOTDOT/dot.json")" "$(cat "$SANDBOX/before.json")"
}

test_a_plugin_cannot_save_dotdots_state() {
  mkdir -p "$DOTDOT/.plugins/acme/widgets"
  printf 'dot::save_state commit "\\"%s\\""\n' "$COMMIT" > "$DOTDOT/.plugins/acme/widgets/writes.sh"
  cp "$DOTDOT/dot.json" "$SANDBOX/before.json"
  core ". '$DOTDOT/.plugins/acme/widgets/writes.sh'"
  assert_failure
  assert_equal "$(cat "$DOTDOT/dot.json")" "$(cat "$SANDBOX/before.json")"
}
