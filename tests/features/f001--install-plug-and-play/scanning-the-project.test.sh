#!/usr/bin/env bash
. "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"

# Golden

test_scan_reports_each_detected_harness_and_its_items() {
  own_instructions CLAUDE.md
  own_skill .claude/skills/mine
  dot adopt --scan --json
  assert_success
  assert_equal "$(json_value "$OUTPUT" '.detected[]')" "claude"
  assert_contains "$(json_value "$OUTPUT" '.items[].path')" ".claude/skills/mine"
  assert_contains "$(json_value "$OUTPUT" '.items[].path')" "CLAUDE.md"
  assert_contains "$(json_value "$OUTPUT" '.items[].kind')" "skill"
  assert_contains "$(json_value "$OUTPUT" '.items[].kind')" "instructions"
}

test_scan_reports_no_strategy_until_one_is_chosen() {
  dot adopt --scan --json
  assert_success
  assert_contains "$OUTPUT" '"strategy":null'
}

test_scan_lists_other_top_level_docs_as_unsure() {
  printf '# Ideas\n' > "$SANDBOX/IDEAS.md"
  printf '# Quality\n' > "$SANDBOX/QUALITY.md"
  dot adopt --scan --json
  assert_success
  assert_contains "$(json_value "$OUTPUT" '.items[].path')" "IDEAS.md"
  assert_contains "$(json_value "$OUTPUT" '.items[].path')" "QUALITY.md"
  assert_contains "$(json_value "$OUTPUT" '.items[].kind')" "unsure"
}

test_scan_lists_an_unsure_doc_once_and_never_a_harness_s_one() {
  own_instructions CLAUDE.md
  dot adopt --scan --json
  assert_success
  assert_equal "$(json_value "$OUTPUT" '.items[].path' | grep -c '^CLAUDE.md$')" 1
  assert_not_contains "$(json_value "$OUTPUT" '.items[].kind')" "unsure"
}

# Edge

test_scan_leaves_out_the_readme_and_dotdot_s_own_links() {
  printf '# Readme\n' > "$SANDBOX/README.md"
  dot link -y
  dot adopt --scan --json
  assert_success
  assert_not_contains "$(json_value "$OUTPUT" '.items[].path')" "README.md"
  assert_not_contains "$(json_value "$OUTPUT" '.items[].path')" "AGENTS.md"
}

test_scan_of_a_blank_project_is_empty() {
  dot adopt --scan --json
  assert_success
  assert_equal "$(json_value "$OUTPUT" '.items[]')" ""
  assert_equal "$(json_value "$OUTPUT" '.detected[]')" ""
}

# Adversarial

test_scan_never_reads_the_env() {
  own_skill .claude/skills/mine
  printf 'SECRET_KEY=%s\n' "$(fake_secret 4)" > "$SANDBOX/.env"
  dot adopt --scan --json
  assert_success
  assert_not_contains "$OUTPUT$ERRORS" "$(fake_secret 4)"
  assert_not_contains "$(json_value "$OUTPUT" '.items[].path')" ".env"
}

test_scan_never_follows_a_link_out_of_the_project() {
  local outside
  outside=$(mktemp -d)
  printf -- '---\nname: spy\n---\n' > "$outside/spy.md"
  mkdir -p "$SANDBOX/.claude"
  ln -s "$outside" "$SANDBOX/.claude/agents"
  dot adopt --scan --json
  rm -rf -- "$outside"
  assert_success
  assert_not_contains "$(json_value "$OUTPUT" '.items[].path')" "spy.md"
}
