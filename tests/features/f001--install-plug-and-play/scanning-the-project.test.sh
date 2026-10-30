# shellcheck shell=bash
. "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"

# Golden

test_scan_reports_each_detected_harness_and_its_items() {
  own_instructions CLAUDE.md
  own_skill .claude/skills/mine
  hey adopt --scan --json
  assert_success
  assert_equal "$(json_value "$OUTPUT" '.detected[]')" "claude"
  assert_contains "$(json_value "$OUTPUT" '.items[].path')" ".claude/skills/mine"
  assert_contains "$(json_value "$OUTPUT" '.items[].path')" "CLAUDE.md"
  assert_contains "$(json_value "$OUTPUT" '.items[].kind')" "skill"
  assert_contains "$(json_value "$OUTPUT" '.items[].kind')" "instructions"
}

test_scan_reports_no_type_until_one_is_chosen() {
  hey adopt --scan --json
  assert_success
  assert_contains "$OUTPUT" '"type":null'
}

test_scan_lists_other_top_level_docs_as_unsure() {
  printf '# Ideas\n' > "$SANDBOX/IDEAS.md"
  printf '# Quality\n' > "$SANDBOX/QUALITY.md"
  hey adopt --scan --json
  assert_success
  assert_contains "$(json_value "$OUTPUT" '.items[].path')" "IDEAS.md"
  assert_contains "$(json_value "$OUTPUT" '.items[].path')" "QUALITY.md"
  assert_contains "$(json_value "$OUTPUT" '.items[].kind')" "unsure"
}

test_scan_lists_an_unsure_doc_once_and_never_a_harness_s_one() {
  own_instructions CLAUDE.md
  hey adopt --scan --json
  assert_success
  assert_equal "$(json_value "$OUTPUT" '.items[].path' | grep -c '^CLAUDE.md$')" 1
  assert_not_contains "$(json_value "$OUTPUT" '.items[].kind')" "unsure"
}

# Edge

test_scan_leaves_out_the_readme_and_dothey_s_centralize_links() {
  printf '# Readme\n' > "$SANDBOX/README.md"
  hey link -y
  hey adopt --scan --json
  assert_success
  assert_not_contains "$(json_value "$OUTPUT" '.items[].path')" "README.md"
  assert_not_contains "$(json_value "$OUTPUT" '.items[].path')" "AGENTS.md"
}

test_scan_of_a_blank_project_is_empty() {
  hey adopt --scan --json
  assert_success
  assert_equal "$(json_value "$OUTPUT" '.items[]')" ""
  assert_equal "$(json_value "$OUTPUT" '.detected[]')" ""
}

# Adversarial

test_scan_never_reads_the_env() {
  own_skill .claude/skills/mine
  printf 'SECRET_KEY=%s\n' "$(fake_secret 4)" > "$SANDBOX/.env"
  hey adopt --scan --json
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
  hey adopt --scan --json
  rm -rf -- "$outside"
  assert_success
  assert_not_contains "$(json_value "$OUTPUT" '.items[].path')" "spy.md"
}

test_the_scan_reports_mcp_and_settings_files_and_centralize_never_moves_them() {
  printf '{}\n' > "$SANDBOX/.mcp.json"
  mkdir -p "$SANDBOX/.claude"
  printf '{}\n' > "$SANDBOX/.claude/settings.json"
  hey adopt --scan --json
  assert_success
  assert_contains "$OUTPUT" '"kind":"mcp","path":".mcp.json"'
  assert_contains "$OUTPUT" '"kind":"setting","path":".claude/settings.json"'
  hey setup --harness claude --type centralize --yes
  assert_success
  assert_file "$SANDBOX/.mcp.json"
  [ ! -L "$SANDBOX/.claude/settings.json" ] || fail "a settings file was moved"
}

test_only_harness_specific_places_detect_a_harness() {
  own_skill .agents/skills/mine
  hey adopt --scan --json
  assert_success
  assert_equal "$(json_value "$OUTPUT" '.detected[]')" "agents"
  mkdir -p "$SANDBOX/.zed"
  printf '{}\n' > "$SANDBOX/.zed/settings.json"
  : > "$SANDBOX/CLAUDE.local.md"
  hey adopt --scan --json
  assert_equal "$(json_value "$OUTPUT" '.detected[]' | paste -sd ' ' -)" "agents claude zed"
}

test_folders_holding_only_dotheys_links_detect_nothing() {
  hey setup --harness cursor --yes
  assert_success
  hey adopt --scan --json
  assert_equal "$(json_value "$OUTPUT" '.detected[]')" ""
}
