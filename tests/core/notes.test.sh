# shellcheck shell=bash

test_note_gets_the_next_number() {
  dot notes:create
  assert_success
  dot notes:create "Cache idea"
  assert_success
  [ -n "$(find "$DOTDOT/Notes" -name 'n001--*-*.md')" ] || fail "an unnamed note gets an adjective-noun name"
  assert_file "$DOTDOT/Notes/n002--cache-idea.md"
  assert_contains "$OUTPUT" "Notes/n002--cache-idea.md"
}

test_xray_opens_numbered_from_the_template() {
  dot xrays:create "Adoption plan" --description "How dotdot moves in."
  assert_success
  assert_contains "$OUTPUT" "Xrays/x001--adoption-plan.md"
  assert_contains "$(cat "$DOTDOT/Xrays/x001--adoption-plan.md")" "name: adoption-plan
description: How dotdot moves in.
status: open"
  assert_contains "$(cat "$DOTDOT/Xrays/x001--adoption-plan.md")" "# Adoption plan"
  assert_contains "$(cat "$DOTDOT/Xrays/x001--adoption-plan.md")" "### 1. <Question or decision to make>"
  dot xrays:create "Second"
  assert_failure
  assert_equal "$STATUS" 2
}
