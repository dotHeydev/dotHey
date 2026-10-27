#!/usr/bin/env bash

test_note_gets_the_next_number() {
  dot notes:create
  assert_success
  dot notes:create "Cache idea"
  assert_success
  [ -n "$(find "$DOTDOT/Notes" -name 'n001--*-*.md')" ] || fail "an unnamed note gets an adjective-noun name"
  assert_file "$DOTDOT/Notes/n002--cache-idea.md"
  assert_contains "$OUTPUT" "Notes/n002--cache-idea.md"
}

test_note_refuses_an_empty_slug() {
  dot notes:create "!!!"
  assert_failure
  assert_contains "$ERRORS" "The name needs at least one letter or digit."
}
