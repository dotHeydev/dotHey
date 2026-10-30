# shellcheck shell=bash

test_note_gets_the_next_number() {
  hey notes:create
  assert_success
  hey notes:create "Cache idea"
  assert_success
  [ -n "$(find "$DOTHEY/Notes" -name 'n001--*-*.md')" ] || fail "an unnamed note gets an adjective-noun name"
  assert_file "$DOTHEY/Notes/n002--cache-idea.md"
  assert_contains "$OUTPUT" "Notes/n002--cache-idea.md"
}

test_xray_opens_numbered_from_the_template() {
  hey xrays:create "Adoption plan" --description "How dotHey moves in."
  assert_success
  assert_contains "$OUTPUT" "Xrays/x001--adoption-plan.md"
  assert_contains "$(cat "$DOTHEY/Xrays/x001--adoption-plan.md")" "name: adoption-plan
description: How dotHey moves in.
status: open"
  assert_contains "$(cat "$DOTHEY/Xrays/x001--adoption-plan.md")" "# Adoption plan"
  assert_contains "$(cat "$DOTHEY/Xrays/x001--adoption-plan.md")" "### 1. <Question or decision to make>"
  hey xrays:create "Second"
  assert_failure
  assert_equal "$STATUS" 2
}
