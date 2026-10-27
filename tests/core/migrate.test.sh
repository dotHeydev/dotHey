#!/usr/bin/env bash

# Adds a pending migration to the sandbox: <name> runs <body> as migrate().
add_migration() {
  printf '#!/usr/bin/env bash\n\nDESCRIPTION="Sample."\n\nmigrate() {\n  %s\n}\n' "$2" > "$DOTDOT/.core/system/migrations/$1.sh"
}

test_nothing_to_migrate_on_a_fresh_install() {
  dot migrate
  assert_success
  assert_contains "$OUTPUT" "nothing to migrate."
}

test_migrations_run_once_and_are_recorded() {
  add_migration 0001-sample ': > "$DOTDOT_ROOT/migrated"'
  dot link -y
  assert_failure
  assert_contains "$ERRORS" "Please run: bash dot migrate"
  dot migrate -y
  assert_success
  assert_file "$DOTDOT/migrated"
  core "dot::setting state.migrations"
  assert_equal "$OUTPUT" '["0001-sample"]'
  rm "$DOTDOT/migrated"
  dot migrate
  assert_contains "$OUTPUT" "nothing to migrate."
  assert_no_file "$DOTDOT/migrated"
  dot link -y
  assert_success
}

test_migrate_needs_a_terminal_or_dotdot_itself() {
  local DOT_INTERNAL_CALL=""
  add_migration 0001-sample ': > "$DOTDOT_ROOT/migrated"'
  dot migrate -y
  assert_failure
  assert_no_file "$DOTDOT/migrated"
  dot migrate
  assert_failure
  assert_contains "$ERRORS" "This needs your confirmation in a terminal"
}

test_a_failing_migration_stops_the_rest_unrecorded() {
  add_migration 0001-broken 'dot::raise "Could not convert."; return 1'
  add_migration 0002-after ': > "$DOTDOT_ROOT/migrated"'
  dot migrate -y
  assert_failure
  assert_contains "$ERRORS" "0001-broken.sh didn't finish"
  assert_no_file "$DOTDOT/migrated"
  core "dot::setting state.migrations"
  assert_equal "$OUTPUT" "[]"
}

test_when_pending_is_silent_with_nothing_to_migrate() {
  dot migrate --if-pending
  assert_success
  assert_equal "$OUTPUT" ""
}
