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


# Leaves 0001-kernel-bootstrap pending, with an AGENTS.md from before the
# kernel: an intro, two sections, and Onboarding.
old_agents() {
  sandbox::settings "\"state\": {\"migrations\": [$(sandbox::migrations | sed 's/"0001-kernel-bootstrap",\{0,1\} *//; s/, *$//')]}"
  printf '# AGENTS.md\n\nIntro.\n\n## Principles\n\n%s\n\n## Onboarding\n\nOnboard line.\n' "$1" > "$DOTHEY/AGENTS.md"
}

test_the_kernel_migration_moves_the_guidelines_out_of_agents() {
  rm "$DOTHEY/GUIDELINES.md"
  old_agents "rule-$RANDOM"
  local line
  line=$(sed -n 7p "$DOTHEY/AGENTS.md")
  hey migrate -y
  assert_success
  grep -qF ".core/KERNEL.md" "$DOTHEY/AGENTS.md" || fail "AGENTS.md doesn't point to the kernel"
  ! grep -qF "$line" "$DOTHEY/AGENTS.md" || fail "the guidelines stayed in AGENTS.md"
  grep -qxF "$line" "$DOTHEY/GUIDELINES.md" || fail "the guidelines didn't reach GUIDELINES.md"
  ! grep -q "^## Onboarding" "$DOTHEY/GUIDELINES.md" || fail "Onboarding moved into GUIDELINES.md"
  core "hey::use framework.helpers.frontmatter; framework.helpers.frontmatter::field '$DOTHEY/GUIDELINES.md' name"
  assert_equal "$OUTPUT" "GUIDELINES.md"
}

test_the_kernel_migration_keeps_the_guidelines_when_guidelines_md_exists() {
  local before
  before=$(cat "$DOTHEY/GUIDELINES.md")
  old_agents "rule-$RANDOM"
  local line
  line=$(sed -n 7p "$DOTHEY/AGENTS.md")
  hey migrate -y
  assert_success
  grep -qF ".core/KERNEL.md" "$DOTHEY/AGENTS.md" || fail "AGENTS.md doesn't point to the kernel"
  grep -qxF "$line" "$DOTHEY/AGENTS.md" || fail "the guidelines were lost"
  assert_equal "$(cat "$DOTHEY/GUIDELINES.md")" "$before"
}

test_the_kernel_migration_leaves_a_bootstrapped_agents_md_alone() {
  local before
  sandbox::settings "\"state\": {\"migrations\": [$(sandbox::migrations | sed 's/"0001-kernel-bootstrap",\{0,1\} *//; s/, *$//')]}"
  printf '\n## Mine\n\nkept-%s\n' "$RANDOM" >> "$DOTHEY/AGENTS.md"
  before=$(cat "$DOTHEY/AGENTS.md")
  hey migrate -y
  assert_success
  assert_equal "$(cat "$DOTHEY/AGENTS.md")" "$before"
}
