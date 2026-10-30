# shellcheck shell=bash

dot::use framework.ui.screen

# <line>... in a box on stdout, under <title> when it isn't empty; in plain
# output, the title and the lines as they are.
framework.ui.box::show() {
  local title="$1" text
  shift
  text=$(printf '%s\n' "$@")
  if framework.ui.screen::is_rich 1; then
    framework.console.output::render 1 "$(framework.ui.screen::boxed "$title" "$text")"
    printf '\n'
    return
  fi
  [ -z "$title" ] || framework.console.output::title "$title"
  framework.console.output::line "$text"
}

# <component> [argument...] (an input: select, checkbox, confirm) drawn in a
# box under <title>, as in
#   choice=$(framework.ui.box::wrap "PICK ONE" framework.ui.select::ask "Which?" a b)
framework.ui.box::wrap() {
  local UI_BOX_TITLE="$1" UI_BOX_ACTIVE=true
  shift
  "$@"
}
