# shellcheck shell=bash

# Keys as a terminal sends them, piped into a component drawn as at a terminal.
rich() {
  core "export DOT_UI=rich; dot::use framework.ui.select framework.ui.checkbox framework.ui.confirm; $1"
}

test_select_picks_with_arrows_and_enter() {
  rich "printf '\033[B\033[B\033[A\n' | framework.ui.select::ask 'Which?' one two three"
  assert_success
  assert_equal "$OUTPUT" "two"
}

test_select_wraps_around_and_jumps_by_number() {
  rich "printf '\033[A\n' | framework.ui.select::ask 'Which?' one two three"
  assert_equal "$OUTPUT" "three"
  rich "printf '2\n' | framework.ui.select::ask 'Which?' one two three"
  assert_equal "$OUTPUT" "two"
}

test_checkbox_prints_each_option_toggled() {
  rich "printf ' \033[B\033[B \033[A  \n' | framework.ui.checkbox::ask 'Which?' one two three"
  assert_success
  assert_equal "$OUTPUT" $'one\nthree'
}

test_confirm_answers_with_keys_or_the_default() {
  rich "printf 'y' | framework.ui.confirm::ask 'Sure?'"
  assert_success
  rich "printf '\n' | framework.ui.confirm::ask 'Sure?'"
  assert_failure
  rich "printf '\033[D\n' | framework.ui.confirm::ask 'Sure?'"
  assert_success
  rich "printf '\n' | framework.ui.confirm::ask 'Sure?' y"
  assert_success
}

test_escape_cancels_with_the_steps_given() {
  rich "framework.ui.screen::on_cancel 'Run bash dot setup'; printf '\033' | framework.ui.select::ask 'Which?' one two"
  assert_equal "$STATUS" 130
  assert_contains "$ERRORS" "bash dot setup"
  assert_equal "$OUTPUT" ""
}

test_inputs_ask_no_one_without_a_person() {
  core "AI_AGENT=1; dot::use framework.ui.select; printf '\n' | framework.ui.select::ask 'Which?' one two"
  assert_failure
  assert_equal "$OUTPUT" ""
  core "dot::use framework.ui.checkbox framework.ui.confirm; framework.ui.checkbox::ask 'Which?' one two || framework.ui.confirm::ask 'Sure?' y"
  assert_failure
}

test_plain_output_keeps_the_content_without_drawing() {
  core "dot::use framework.ui.box framework.ui.banner framework.ui.progress framework.ui.steps framework.ui.rule
    framework.ui.banner::show Title Subtitle
    framework.ui.box::show Header one two
    framework.ui.rule::show 5
    framework.ui.progress::show 1 3 Linking
    framework.ui.progress::show 3 3 Linking
    for step in 1 2 3; do framework.ui.steps::show \$step Linking foo bar; done"
  assert_success
  assert_equal "$OUTPUT" $'Title\nSubtitle\nHeader\none\ntwo\n-----'
  assert_not_contains "$ERRORS" $'\033'
  assert_not_contains "$ERRORS" "1/3"
  assert_contains "$ERRORS" "3/3"
  assert_contains "$ERRORS" "✓ foo"
  assert_contains "$ERRORS" "✓ bar"
}

test_rich_output_draws_boxes_and_bars() {
  core "export DOT_UI=rich; dot::use framework.ui.box framework.ui.progress
    printf '%s\n' \"\$UI_GLYPH_BOX_TOP_LEFT\"
    framework.ui.box::show Header one
    UI_PROGRESS_STYLE=count framework.ui.progress::show 2 4"
  assert_success
  assert_contains "$(tail -n +2 <<< "$OUTPUT")" "$(head -1 <<< "$OUTPUT")"
  assert_contains "$ERRORS" "2/4"
}

test_terminals_without_unicode_get_ascii_glyphs() {
  run env LC_ALL=C LANG=C bash -c ". '$DOTDOT/.core/system/boot.sh'; dot::use framework.ui.screen; printf '%s %s %s' \"\$UI_GLYPHS\" \"\$UI_GLYPH_POINTER\" \"\$UI_GLYPH_POINTER_ASCII\""
  read -r glyphs pointer ascii <<< "$OUTPUT"
  assert_equal "$glyphs" ascii
  assert_equal "$pointer" "$ascii"
}

test_icons_and_glyphs_are_defined_only_in_the_theme() {
  local found
  found=$(find "$DOTDOT/.core" -name '*.sh' ! -path '*/framework/ui/theme.sh' -exec grep -nE '^[[:space:]]*(local )?[A-Z_]*(ICON|GLYPH|SPINNER_FRAMES)[A-Z_]*=\(?["'"'"'][^$]' {} + || true)
  [ -z "$found" ] || fail "icons and glyphs belong in framework/ui/theme.sh:
$found"
}

test_tui_view_runs_but_is_never_listed() {
  dot
  assert_not_contains "$OUTPUT" "tui:view"
  dot --json
  assert_not_contains "$OUTPUT" "tui:view"
  dot tui:view --help
  assert_success
}

test_tui_view_shows_every_component_without_a_person() {
  local component
  dot tui:view
  assert_success
  for component in banner box message list rule select checkbox confirm progress steps spinner; do
    assert_contains "$OUTPUT" "$component"
  done
  assert_not_contains "$OUTPUT$ERRORS" $'\033'
}

test_tui_view_runs_the_components_named_or_all() {
  dot tui:view select,progress
  assert_success
  assert_contains "$OUTPUT" "select"
  assert_not_contains "$OUTPUT" "banner"
  dot tui:view all
  assert_success
  dot tui:view select,nope
  assert_equal "$STATUS" 2
}

test_steps_run_each_item_and_stop_at_the_first_failure() {
  core "dot::use framework.ui.steps
    work() { printf 'did %s\n' \"\$1\"; [ \"\$1\" != bad ]; }
    framework.ui.steps::run Working work one bad three"
  assert_failure
  assert_contains "$ERRORS" "did one"
  assert_contains "$ERRORS" "did bad"
  assert_not_contains "$ERRORS" "did three"
  core "export DOT_UI=rich; dot::use framework.ui.steps
    work() { sleep 0.2; }
    printf '%s' \"\${UI_STEPS_LOADER_FRAMES[0]}\"
    UI_STEPS_CURRENT=loader framework.ui.steps::run Working work one two"
  assert_success
  assert_contains "$ERRORS" "$OUTPUT one"
}

test_checkbox_starts_with_the_options_checked() {
  rich "printf '\033[B \n' | framework.ui.checkbox::ask --checked 1,3 'Which?' one two three"
  assert_success
  assert_equal "$OUTPUT" $'one\ntwo\nthree'
}
