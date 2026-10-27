#!/usr/bin/env bash

create_decision() {
  dot decisions:create "$1" --statement "We $1." --elaboration "Because." "${@:2}"
  assert_success "create decision $1"
}

test_decision_links_are_resolved() {
  create_decision "keep it simple" --status accepted
  create_decision "use bash" --influenced-by 1
  assert_contains "$(cat "$DOTDOT/Decisions/d002--use-bash.md")" "[d001](d001--keep-it-simple.md)"
  dot decisions:create dangling --statement x --elaboration y --influenced-by 42
  assert_failure
  assert_contains "$ERRORS" "No decision matches"
}

test_decision_refuses_two_statuses() {
  dot decisions:create a --statement b --elaboration c --status accepted --status rejected
  assert_failure
  assert_contains "$ERRORS" "one status at a time"
}

test_decision_update_sets_status_and_timestamp() {
  local file="$DOTDOT/Decisions/d001--first.md"
  create_decision first
  create_decision second
  sed -i.bak 's/^modified: .*/modified: earlier/' "$file" && rm -f "$file.bak"
  dot decisions:update 1 superseded --by 2
  assert_success
  assert_contains "$(cat "$file")" "status: superseded by [d002](d002--second.md)"
  assert_not_contains "$(cat "$file")" "modified: earlier"
  dot decisions:update 1 superseded --by 1
  assert_failure
  assert_contains "$ERRORS" "can't supersede itself"
}

test_decision_impact_reports_links_and_terms() {
  create_decision "first rule"
  create_decision "second rule" --influenced-by 1
  dot features:create login --description "Session cookies." --related-project-decisions "- [d001](../Decisions/d001--first-rule.md)"
  assert_success
  dot decisions:check
  assert_success
  assert_contains "$OUTPUT" "resolve."
  dot decisions:impact 1 --cited-by
  assert_contains "$OUTPUT" "d002--second-rule.md"
  dot decisions:impact 1
  assert_contains "$OUTPUT" "f001--login.md"
  dot decisions:impact --term "cookies,nothing-like-this"
  assert_contains "$OUTPUT" "matched 1 of 2 terms"
  rm "$DOTDOT/Decisions/d001--first-rule.md"
  dot decisions:check
  assert_failure
  assert_contains "$OUTPUT" "no such decision"
}

test_decision_impact_needs_something_to_do() {
  dot decisions:impact --term=","
  assert_failure
  assert_contains "$ERRORS" "What should it look for?"
}
