# shellcheck shell=bash

hey::use framework.ui.screen

# <title>, and <subtitle> under it, in a box on stdout; in plain output, the
# two lines.
framework.ui.banner::show() {
  local title="$1" subtitle="${2-}" text
  text=$(framework.console.output::paint "$UI_STYLE_BANNER_TITLE" "$title")
  [ -z "$subtitle" ] || text="$text"$'\n'"$subtitle"
  if framework.ui.screen::is_rich 1; then
    framework.console.output::render 1 "$(framework.ui.screen::boxed "" "$text" "$UI_STYLE_BANNER")"
    printf '\n'
    return
  fi
  framework.console.output::line "$text"
}
