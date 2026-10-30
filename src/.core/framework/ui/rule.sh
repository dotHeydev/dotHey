# shellcheck shell=bash

hey::use framework.ui.screen

# A line across the terminal, or <width> wide, on stdout: drawn at a terminal,
# dashes anywhere else.
framework.ui.rule::show() {
  local width="${1-}"
  if framework.ui.screen::is_rich 1; then
    [ -n "$width" ] || width=$(framework.ui.screen::width)
    framework.console.output::render 1 "$(framework.console.output::paint "$UI_STYLE_RULE" "$(framework.ui.screen::repeat "$UI_GLYPH_RULE" "$width")")"
    printf '\n'
    return
  fi
  [ -n "$width" ] || width=$(framework.console.output::width)
  printf '%s\n' "$(framework.ui.screen::repeat - "$width")"
}
