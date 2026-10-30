# shellcheck shell=bash

hey::use framework.ui.screen

# <done> of <total> after <label>, redrawn in place on each call, in the
# theme's UI_PROGRESS_STYLE: thin or fat (a bar and its percentage), or count
# (12/34). Its line ends once done reaches total; plain output shows only
# that last state.
framework.ui.progress::show() {
  local done="$1" total="$2" label="${3-}" percent=100 filled bar done_glyph="$UI_GLYPH_THIN_DONE" todo_glyph="$UI_GLYPH_THIN_TODO"
  [ "$total" -le 0 ] || percent=$((done * 100 / total))
  [ "$percent" -le 100 ] || percent=100
  if ! framework.ui.screen::is_rich; then
    [ "$done" -lt "$total" ] || framework.console.output::emit 2 "${label:+$label  }$done/$total"
    return 0
  fi
  if [ "$UI_PROGRESS_STYLE" = count ]; then
    bar="$(framework.console.output::paint "$UI_STYLE_PROGRESS_DONE" "$done")$(framework.console.output::paint "$UI_STYLE_PROGRESS_TODO" "/$total")"
  else
    [ "$UI_PROGRESS_STYLE" != fat ] || done_glyph="$UI_GLYPH_FAT_DONE" todo_glyph="$UI_GLYPH_FAT_TODO"
    filled=$((percent * UI_PROGRESS_WIDTH / 100))
    bar="$(framework.console.output::paint "$UI_STYLE_PROGRESS_DONE" "$(framework.ui.screen::repeat "$done_glyph" "$filled")")"
    bar="$bar$(framework.console.output::paint "$UI_STYLE_PROGRESS_TODO" "$(framework.ui.screen::repeat "$todo_glyph" $((UI_PROGRESS_WIDTH - filled)))")"
    bar="$bar  $(framework.console.output::bold "$(printf '%3s%%' "$percent")")"
  fi
  [ -z "$label" ] || bar="$(framework.console.output::paint "$UI_STYLE_PROGRESS_LABEL" "$label")  $bar"
  printf '\r\033[K%s' "$(framework.console.output::render 2 "$bar")" >&2
  [ "$done" -lt "$total" ] || printf '\n' >&2
}
