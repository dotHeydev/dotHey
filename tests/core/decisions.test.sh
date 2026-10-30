# shellcheck shell=bash

create_decision() {
  hey decisions:create "$1" --statement "We $1." --explanation "Because." "${@:2}"
  assert_success "create decision $1"
}

test_decision_links_are_resolved() {
  create_decision "keep it simple" --status accepted
  create_decision "use bash" --influenced-by 1
  assert_contains "$(cat "$DOTHEY/Decisions/d002--use-bash.md")" "[d001](d001--keep-it-simple.md)"
  hey decisions:create dangling --statement x --explanation y --influenced-by 42
  assert_failure
  assert_equal "$STATUS" 2
}

test_decision_update_sets_status_and_timestamp() {
  local file="$DOTHEY/Decisions/d001--first.md"
  create_decision first
  create_decision second
  sed -i.bak 's/^modified: .*/modified: earlier/' "$file" && rm -f "$file.bak"
  hey decisions:update 1 --status superseded --by 2
  assert_success
  assert_contains "$(cat "$file")" "status: superseded by [d002](d002--second.md)"
  assert_not_contains "$(cat "$file")" "modified: earlier"
  hey decisions:update 1 --status superseded --by 1
  assert_failure
  assert_equal "$STATUS" 1
}

test_decision_impact_reports_links_and_terms() {
  create_decision "first rule"
  create_decision "second rule" --influenced-by 1
  hey features:create login --description "Session cookies." --related-project-decisions "- [d001](../Decisions/d001--first-rule.md)"
  assert_success
  hey decisions:check
  assert_success
  hey decisions:citers 1
  assert_contains "$OUTPUT" "d002--second-rule.md"
  hey decisions:impact 1
  assert_contains "$OUTPUT" "f001--login.md"
  hey decisions:impact --term "cookies,nothing-like-this"
  rm "$DOTHEY/Decisions/d001--first-rule.md"
  hey decisions:check
  assert_failure
  assert_equal "$STATUS" 1
}

test_decision_status_is_a_flag_and_citers_have_their_own_command() {
  create_decision first
  create_decision second --influenced-by 1
  hey decisions:update 1 accepted
  assert_equal "$STATUS" 2
  hey decisions:update 1 --status accepted
  assert_success
  assert_contains "$(cat "$DOTHEY/Decisions/d001--first.md")" "status: accepted"
  hey decisions:citers 1
  assert_success
  assert_contains "$OUTPUT" "d002--second.md"
  hey decisions:impact 1 --cited-by
  assert_equal "$STATUS" 2
  hey decisions:citers 9
  assert_equal "$STATUS" 4
}

test_decision_commands_print_json() {
  hey decisions:create json --statement "We json." --explanation "Because." --json
  assert_success
  assert_equal "$(json_value "$OUTPUT" .id)" d001--json
  assert_equal "$(json_value "$OUTPUT" .path)" .hey/Decisions/d001--json.md
  hey decisions:check --json
  assert_success
  assert_equal "$(json_value "$OUTPUT" '.broken | length')" 0
  hey decisions:impact 1 --term json --json
  assert_success
  assert_contains "$(json_value "$OUTPUT" '.terms[].path')" "d001--json.md"
  assert_equal "$(json_value "$OUTPUT" '.features | length')" 0
  hey decisions:create missing --statement x
  assert_equal "$STATUS" 2
}
