#!/usr/bin/env bash

command_names() {
  local directory
  for directory in "$DOTDOT"/.core/system/*/commands "$DOTDOT"/.core/modules/*/commands; do
    (cd "$directory" && find . -name '*.sh' | sed 's|^\./||; s|\.sh$||; s|/|:|g')
  done | sort
}

test_every_command_is_listed_and_answers_help() {
  local name
  dot
  while IFS= read -r name; do
    assert_contains "$OUTPUT" "$name"
  done < <(command_names)
  core 'while IFS="|" read -r name file; do
      ( DOT_COMMAND="$name"; . "$file"; usage ) >/dev/null || { printf "%s --help failed\n" "$name" >&2; exit 1; }
    done < <(kernel::core_commands)'
  assert_success
  [ -z "$ERRORS" ] || fail "a command's --help wrote to stderr: $ERRORS"
}

test_help_command_matches_help_flag() {
  local expected
  dot link --help
  expected="$OUTPUT"
  dot help link
  assert_success
  assert_equal "$OUTPUT" "$expected"
}

test_unknown_command_fails_with_hint() {
  dot nothing:here
  assert_failure
  assert_contains "$ERRORS" "There's no command nothing:here."
}

test_invalid_command_name_is_refused() {
  dot '../escape'
  assert_failure
  assert_contains "$ERRORS" "There's no command"
}

test_runs_through_a_symlinked_entry_point() {
  ln -s "$SANDBOX/dot" "$SANDBOX/second"
  run bash ./second scan:frontmatter AGENTS.md
  assert_success
  assert_contains "$OUTPUT" "AGENTS.md"
}

test_refuses_to_run_under_sh() {
  run sh ./dot
  assert_failure
  assert_contains "$ERRORS" "bash"
}

test_modules_load_by_dotted_path() {
  mkdir -p "$DOTDOT/.plugins/acme/tools"
  printf '#!/usr/bin/env bash\nplugins.acme.tools.greet::greet() { printf "hi %%s" "$1"; }\n' > "$DOTDOT/.plugins/acme/tools/greet.sh"
  core "dot::use framework.helpers.text plugins.acme.tools.greet; plugins.acme.tools.greet::greet \"\$(framework.helpers.text::slug 'Dotted Path')\""
  assert_success
  assert_equal "$OUTPUT" "hi dotted-path"
}

test_unknown_or_undotted_modules_fail() {
  local module
  for module in text tools.missing tools..fs acme.tools.greet core.nothing.here; do
    core "dot::use $module"
    assert_failure "$module"
    assert_contains "$ERRORS" "Unknown dotdot module: $module"
  done
}

test_record_folders_ship_with_dotdot() {
  local folder
  core 'for folder in "$FEATURES_DIR" "$DECISIONS_DIR" "$NOTES_DIR" "$TASKS_DIR"; do printf "%s\n" "${folder#"$DOTDOT_ROOT"/}"; done'
  assert_success
  while IFS= read -r folder; do
    assert_file "$DOTDOT/$folder/.gitkeep"
    ! git -C "$REPOSITORY_DIR" check-ignore -q "dist/$folder/.gitkeep" || fail "dist/$folder/.gitkeep is git-ignored, so installs would not get it"
  done <<< "$OUTPUT"
}

test_a_typo_suggests_the_closest_command() {
  dot notes:creat
  assert_failure
  assert_contains "$ERRORS" "There's no command notes:creat. Did you mean notes:create?"
  dot zzzzzz
  assert_failure
  assert_not_contains "$ERRORS" "Did you mean"
}

test_agents_get_plain_output_and_hand_over_what_needs_a_person() {
  dot upgrade
  assert_contains "$ERRORS" "Please run the command manually: bash dot upgrade"
  dot --agent upgrade
  assert_contains "$ERRORS" "Please ask the user to run it in a terminal: bash dot upgrade"
  run env AI_AGENT=some-agent bash ./dot upgrade
  assert_contains "$ERRORS" "Please ask the user to run it in a terminal: bash dot upgrade"
}

test_flag_values_may_follow_an_equals_sign() {
  dot tasks:list --order=sideways
  assert_failure
  assert_contains "$ERRORS" "--order takes asc or desc."
}

test_a_missing_plugin_never_means_every_plugin() {
  dot plugins:update
  assert_failure
  assert_contains "$ERRORS" "or --all for every one"
  dot plugins:update --all
  assert_success
  assert_contains "$OUTPUT" "No plugins installed yet."
}

test_every_help_page_has_usage_and_fits_80_columns() {
  local name long
  while read -r name; do
    dot "$name" --help
    assert_success "$name --help"
    assert_contains "$OUTPUT" "Usage:"
    long=$(printf '%s\n' "$OUTPUT" | awk 'length($0) > 80')
    [ -z "$long" ] || fail "$name --help has lines over 80 columns: $long"
  done < <(dot; printf '%s\n' "$OUTPUT" | awk '/^  [a-z]+(:[a-z]+)?  / { print $1 }')
}

test_exit_statuses_tell_usage_from_failure() {
  dot zzzzzz
  assert_equal "$STATUS" 2
  dot notes:create a b
  assert_equal "$STATUS" 2
  dot tasks:get t001 --nope
  assert_equal "$STATUS" 2
  sandbox::settings '"tasks": {"service": "file"}'
  dot tasks:get t999
  assert_equal "$STATUS" 4
  dot decisions:update 9 --status accepted
  assert_equal "$STATUS" 4
}

test_json_errors_go_to_stderr_with_their_status_and_next_step() {
  dot tasks:list --bogus --json
  assert_equal "$STATUS" 2
  assert_equal "$OUTPUT" ""
  assert_equal "$(json_value "$ERRORS" .error.code)" USAGE
  assert_equal "$(json_value "$ERRORS" .error.exitCode)" 2
  assert_equal "$(json_value "$ERRORS" .error.run)" "bash dot tasks:list --help"
  dot notes:create a --json
  assert_success
  dot plugins:new acme/x --json
  assert_equal "$STATUS" 2
  assert_contains "$(json_value "$ERRORS" .error.message)" "Unknown argument: --json"
}

test_version_and_help_are_machine_readable() {
  dot -v
  assert_success
  assert_contains "$OUTPUT" "dotdot"
  dot version --json
  assert_success
  assert_equal "$OUTPUT" '{"version":null}'
  dot --json
  assert_success
  assert_contains "$(json_value "$OUTPUT" '.commands[].name')" "tasks:list"
  assert_not_contains "$(json_value "$OUTPUT" '.commands[].name')" "scan:frontmatter"
  dot help tasks:list --json
  assert_success
  assert_equal "$(json_value "$OUTPUT" .name)" tasks:list
  assert_contains "$(json_value "$OUTPUT" '.options[].name')" "-l, --limit <n>"
  assert_contains "$(json_value "$OUTPUT" .docs)" "/docs/usage.md#tasks"
  dot tasks:list --help
  assert_contains "$OUTPUT" "Docs:"
  assert_contains "$OUTPUT" "blob/main/docs/usage.md#tasks"
}

test_old_names_still_run_but_are_never_listed() {
  dot notes:create listed
  dot scan:frontmatter Notes
  assert_success
  assert_contains "$OUTPUT" "Notes/n001--listed.md"
  dot
  assert_not_contains "$OUTPUT" "scan:frontmatter"
  assert_contains "$OUTPUT" "frontmatter:show"
}

test_colors_follow_force_color_and_no_color() {
  run env -u NO_COLOR FORCE_COLOR=1 bash ./dot --help
  assert_contains "$OUTPUT" $'\033['
  run env NO_COLOR=1 FORCE_COLOR=1 bash ./dot --help
  assert_not_contains "$OUTPUT" $'\033['
  run env -u NO_COLOR CLICOLOR_FORCE=1 bash ./dot --help
  assert_contains "$OUTPUT" $'\033['
}

test_no_input_and_ci_never_let_yes_skip_a_person() {
  core "guards::skip_confirmation"
  assert_success "dotdot's own calls may"
  run env DOT_INTERNAL_CALL="" CI=true bash ./dot link -y
  assert_equal "$STATUS" 5
  run env DOT_INTERNAL_CALL="" bash ./dot --no-input link -y
  assert_equal "$STATUS" 5
}
