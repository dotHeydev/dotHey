# shellcheck shell=bash

command_names() {
  local directory
  for directory in "$DOTHEY"/.core/system/*/commands "$DOTHEY"/.core/modules/*/commands; do
    (cd "$directory" && find . -name '*.sh' ! -exec grep -q '^HIDDEN=true$' {} \; -print | sed 's|^\./||; s|\.sh$||; s|/|:|g')
  done | sort
}

test_every_command_not_hidden_is_listed_and_every_one_answers_help() {
  local name
  hey
  while IFS= read -r name; do
    assert_contains "$OUTPUT" "$name"
  done < <(command_names)
  core 'while IFS="|" read -r name file; do
      ( HEY_COMMAND="$name"; . "$file"; usage ) >/dev/null || { printf "%s --help failed\n" "$name" >&2; exit 1; }
    done < <(kernel::core_commands)'
  assert_success
  [ -z "$ERRORS" ] || fail "a command's --help wrote to stderr: $ERRORS"
}

test_unknown_command_fails_with_hint() {
  hey nothing:here
  assert_failure
  assert_equal "$STATUS" 2
}

test_invalid_command_name_is_refused() {
  hey '../escape'
  assert_failure
  assert_equal "$STATUS" 2
}

test_runs_through_a_symlinked_entry_point() {
  ln -s "$SANDBOX/hey" "$SANDBOX/second"
  run bash ./second scan:frontmatter AGENTS.md
  assert_success
  assert_contains "$OUTPUT" "AGENTS.md"
}

test_refuses_to_run_under_sh() {
  run sh ./hey
  assert_failure
  assert_equal "$STATUS" 1
}

test_modules_load_by_dotted_path() {
  mkdir -p "$DOTHEY/.plugins/acme/tools"
  printf '#!/usr/bin/env bash\nplugins.acme.tools.greet::greet() { printf "hi %%s" "$1"; }\n' > "$DOTHEY/.plugins/acme/tools/greet.sh"
  core "hey::use framework.helpers.text plugins.acme.tools.greet; plugins.acme.tools.greet::greet \"\$(framework.helpers.text::slug 'Dotted Path')\""
  assert_success
  assert_equal "$OUTPUT" "hi dotted-path"
}

test_unknown_or_undotted_modules_fail() {
  local module
  for module in text tools.missing tools..fs acme.tools.greet core.nothing.here; do
    core "hey::use $module"
    assert_failure "$module"
    assert_equal "$STATUS" 1
  done
}

test_record_folders_ship_with_dothey() {
  local folder
  core 'for folder in "$FEATURES_DIR" "$DECISIONS_DIR" "$NOTES_DIR" "$TASKS_DIR"; do printf "%s\n" "${folder#"$DOTHEY_ROOT"/}"; done'
  assert_success
  while IFS= read -r folder; do
    assert_file "$DOTHEY/$folder/.gitkeep"
    ! git -C "$REPOSITORY_DIR" check-ignore -q "dist/$folder/.gitkeep" || fail "dist/$folder/.gitkeep is git-ignored, so installs would not get it"
  done <<< "$OUTPUT"
}

test_a_typo_suggests_the_closest_command() {
  hey notes:creat
  assert_failure
  assert_equal "$STATUS" 2
  assert_contains "$ERRORS" "notes:create"
  hey zzzzzz
  assert_failure
  assert_equal "$STATUS" 2
}

test_agents_get_plain_output_and_hand_over_what_needs_a_person() {
  sandbox::settings '"release": {"remotes": {"github": "https://github.com/acme/repo.git"}}'
  hey release:token github
  local person="$ERRORS"; assert_contains "$ERRORS" "bash hey release:token github"
  hey --agent release:token github
  assert_contains "$ERRORS" "bash hey release:token github"; [ "$ERRORS" != "$person" ] || fail "an agent got the hand-over a person gets"
  run env AI_AGENT=some-agent bash ./hey release:token github
  assert_contains "$ERRORS" "bash hey release:token github"; [ "$ERRORS" != "$person" ] || fail "AI_AGENT got the hand-over a person gets"
}

test_flag_values_may_follow_an_equals_sign() {
  hey tasks:list --order=sideways
  assert_failure
  assert_equal "$STATUS" 2
}

test_a_missing_plugin_never_means_every_plugin() {
  hey plugins:update
  assert_failure
  assert_equal "$STATUS" 2
  hey plugins:update --all
  assert_success
}

test_every_help_page_has_usage_and_fits_80_columns() {
  local name long
  while read -r name; do
    hey "$name" --help
    assert_success "$name --help"
    assert_contains "$OUTPUT" "Usage:"
    long=$(printf '%s\n' "$OUTPUT" | awk 'length($0) > 80')
    [ -z "$long" ] || fail "$name --help has lines over 80 columns: $long"
  done < <(hey; printf '%s\n' "$OUTPUT" | awk '/^  [a-z]+(:[a-z]+)?  / { print $1 }')
}

test_exit_statuses_tell_usage_from_failure() {
  hey zzzzzz
  assert_equal "$STATUS" 2
  hey notes:create a b
  assert_equal "$STATUS" 2
  hey tasks:get t001 --nope
  assert_equal "$STATUS" 2
  sandbox::settings '"tasks": {"service": "file"}'
  hey tasks:get t999
  assert_equal "$STATUS" 4
  hey decisions:update 9 --status accepted
  assert_equal "$STATUS" 4
}

test_json_errors_go_to_stderr_with_their_status_and_next_step() {
  hey tasks:list --bogus --json
  assert_equal "$STATUS" 2
  assert_equal "$OUTPUT" ""
  assert_equal "$(json_value "$ERRORS" .error.code)" USAGE
  assert_equal "$(json_value "$ERRORS" .error.exitCode)" 2
  assert_equal "$(json_value "$ERRORS" .error.run)" "bash hey tasks:list --help"
  hey notes:create a --json
  assert_success
  hey plugins:new acme/x --json
  assert_equal "$STATUS" 2
  assert_contains "$(json_value "$ERRORS" .error.message)" "Unknown argument: --json"
}

test_version_and_help_are_machine_readable() {
  hey -v
  assert_success
  assert_contains "$OUTPUT" "dotHey"
  hey version --json
  assert_success
  assert_contains "$OUTPUT" '"commit":null'
  hey --json
  assert_success
  assert_contains "$(json_value "$OUTPUT" '.commands[].name')" "tasks:list"
  assert_not_contains "$(json_value "$OUTPUT" '.commands[].name')" "scan:frontmatter"
  hey help tasks:list --json
  assert_success
  assert_equal "$(json_value "$OUTPUT" .name)" tasks:list
  assert_contains "$(json_value "$OUTPUT" '.options[].name')" "-l, --limit <n>"
  assert_contains "$(json_value "$OUTPUT" .docs)" "/docs/usage.md#tasks"
  hey tasks:list --help
  assert_contains "$OUTPUT" "Docs:"
  assert_contains "$OUTPUT" "blob/main/docs/usage.md#tasks"
}

test_old_names_still_run_but_are_never_listed() {
  hey notes:create listed
  hey scan:frontmatter Notes
  assert_success
  assert_contains "$OUTPUT" "Notes/n001--listed.md"
  hey
  assert_not_contains "$OUTPUT" "scan:frontmatter"
  assert_contains "$OUTPUT" "frontmatter:show"
}

test_colors_follow_force_color_and_no_color() {
  run env -u NO_COLOR FORCE_COLOR=1 bash ./hey --help
  assert_contains "$OUTPUT" $'\033['
  run env NO_COLOR=1 FORCE_COLOR=1 bash ./hey --help
  assert_not_contains "$OUTPUT" $'\033['
  run env -u NO_COLOR CLICOLOR_FORCE=1 bash ./hey --help
  assert_contains "$OUTPUT" $'\033['
}

test_no_input_and_ci_never_let_yes_skip_a_person() {
  core "guards::skip_confirmation"
  assert_success "dotHey's own calls may"
  run env HEY_INTERNAL_CALL="" CI=true bash ./hey link -y
  assert_equal "$STATUS" 5
  run env HEY_INTERNAL_CALL="" bash ./hey --no-input link -y
  assert_equal "$STATUS" 5
}

test_a_module_behind_a_feature_flag_is_off_until_turned_on() {
  sandbox::settings '"featureFlags": {}'
  hey
  assert_success
  assert_not_contains "$OUTPUT" "release:create"
  hey release:create 1.0.0
  assert_failure
  assert_equal "$STATUS" 5
#  assert_contains "$ERRORS" "#feature-flags"
  core 'kernel::reserved_names'
  assert_contains "$OUTPUT" "release"
  sandbox::settings '"featureFlags": {"release": true}'
  hey
  assert_contains "$OUTPUT" "release:create"
}

test_feature_reads_a_flag_as_on_only_when_true() {
  sandbox::settings '"featureFlags": {"release": true, "other": "yes"}'
  core 'hey::feature release && ! hey::feature other && ! hey::feature missing'
  assert_success
}

test_help_links_the_docs_on_main_whatever_the_installed_version() {
  sandbox::settings "\"state\": {\"commit\": \"4d342b097ba4acf1850d6caab9d63a52cea45457\", \"migrations\": [$(sandbox::migrations)]}"
  hey link --help
  assert_success
  assert_contains "$OUTPUT" "https://github.com/dotHeydev/dotHey/blob/main/docs/usage.md#linking"
  assert_not_contains "$OUTPUT" "4d342b0"
}

test_json_help_says_what_the_help_page_says() {
  local name page json
  hey --json
  assert_equal "$(json_value "$OUTPUT" '.usage[]' | grep -c . || true)" 2
  assert_contains "$(json_value "$OUTPUT" '.options[].name')" "--agent"
  assert_equal "$(json_value "$OUTPUT" '.sections[].title')" "Exit statuses"
  for name in link setup tasks:update plugins:add; do
    hey "$name" --help
    page="$OUTPUT"
    hey help "$name" --json
    json="$OUTPUT"
    assert_equal "$(json_value "$json" '.notes[]' | grep -c . || true)" "$(printf '%s\n' "$page" | awk '/^Notes:$/ { on = 1; next } /^[A-Z][^:]*:$/ { on = 0 } on && /^  - / { n++ } END { print n + 0 }')"
    assert_equal "$(json_value "$json" '.options[].name' | grep -c . || true)" "$(printf '%s\n' "$page" | awk '/^Options:$/ { on = 1; next } /^[A-Z][^:]*:$/ { on = 0 } on && /^  [^ ]/ { n++ } END { print n + 0 }')"
    [ -n "$(json_value "$json" .about)" ] || fail "$name's JSON help has no about"
  done
  hey help link --json
  assert_equal "$(json_value "$OUTPUT" '.sections[].title')" "Links"
}

test_json_runs_keep_stdout_for_the_result_and_say_the_rest_as_json_on_stderr() {
  local line
  HEY_INTERNAL_CALL="" hey notes:create idea --json
  assert_success
  assert_equal "$(json_value "$OUTPUT" .id)" "n001--idea"
  assert_contains "$(json_value "$ERRORS" .notice.run)" "bash hey setup"
  printf '{not json' > "$DOTHEY/.core/harnesses/claude/harness.json"
  hey adopt --scan --json
  assert_success
  [ -n "$(json_value "$OUTPUT" .harnesses)" ] || fail "stdout lost its result"
  assert_contains "$ERRORS" '{"warning":'
  while IFS= read -r line; do
    [ -n "$(json_value "$line" .)" ] || fail "stderr holds a line that isn't JSON: $line"
  done <<< "$ERRORS"
}
