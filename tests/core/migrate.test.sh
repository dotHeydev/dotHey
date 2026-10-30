# shellcheck shell=bash

# Adds a pending migration to the sandbox: <name> runs <body> as migrate().
add_migration() {
  printf '#!/usr/bin/env bash\n\nDESCRIPTION="Sample."\n\nmigrate() {\n  %s\n}\n' "$2" > "$DOTHEY/.core/system/migrations/$1.sh"
}

test_migrations_run_once_and_are_recorded() {
  add_migration 0001-sample ': > "$DOTHEY_ROOT/migrated"'
  hey link -y
  assert_failure
  assert_equal "$STATUS" 5
  assert_contains "$ERRORS" "bash hey migrate"
  hey migrate -y
  assert_success
  assert_file "$DOTHEY/migrated"
  core "hey::state migrations"
  assert_contains "$OUTPUT" '"0001-sample"'
  rm "$DOTHEY/migrated"
  hey migrate
  assert_success
  assert_no_file "$DOTHEY/migrated"
  hey link -y
  assert_success
}

test_migrate_needs_a_terminal_or_dothey_itself() {
  local HEY_INTERNAL_CALL=""
  add_migration 0001-sample ': > "$DOTHEY_ROOT/migrated"'
  hey migrate -y
  assert_failure
  assert_equal "$STATUS" 5
  assert_no_file "$DOTHEY/migrated"
  hey migrate
  assert_failure
  assert_equal "$STATUS" 5
}

test_a_failing_migration_stops_the_rest_unrecorded() {
  add_migration 0001-broken 'hey::raise "Could not convert."; return 1'
  add_migration 0002-after ': > "$DOTHEY_ROOT/migrated"'
  hey migrate -y
  assert_failure
  assert_equal "$STATUS" 1
  assert_contains "$ERRORS" "0001-broken.sh"
  assert_no_file "$DOTHEY/migrated"
  core "hey::state migrations"
  assert_not_contains "$OUTPUT" '"0001-broken"'
  assert_not_contains "$OUTPUT" '"0002-after"'
}

test_when_pending_is_silent_with_nothing_to_migrate() {
  hey migrate --if-pending
  assert_success
  assert_equal "$OUTPUT" ""
}

