# shellcheck shell=bash

dot::use framework.ui.screen

# Each <item> as a bullet on stdout.
framework.ui.list::show() {
  local item
  for item in "$@"; do
    framework.ui.list::item "$item"
  done
}

# <label> as a bullet, and <note>, dimmed, after it.
framework.ui.list::item() {
  local label="$1" note="${2-}"
  framework.console.output::emit 1 "  $UI_GLYPH_BULLET $label${note:+  $(framework.console.output::paint "$UI_STYLE_MUTED" "($note)")}"
}
