#!/usr/bin/env bash

# What every UI component draws with: how this run can draw (detect), and
# the frame a component redraws in place as the person answers.

dot::use framework.ui.theme framework.console.output

UI_FRAME_LINES=0
UI_BOX_ACTIVE=false
UI_BOX_TITLE=""
UI_CANCEL_STEPS=()
UI_KEY=""
UI_TTY=""
UI_TRAPS=""

# How this run draws, decided once as it loads, into:
#   UI_MODE    rich for a person at a terminal: frames redrawn in place,
#              boxes, bars, colors where they're on; plain for everyone else
#              (agents, CI, --no-input, dumb terminals): the same content as
#              plain lines, and inputs typed, or left to flags.
#   UI_KEYS    whether answers come as keys (arrows, Space, Enter).
#   UI_GLYPHS  unicode, or ascii where the terminal can't draw it, which
#              swaps in each UI_GLYPH_*_ASCII and UI_HINT_*_ASCII.
# DOT_UI=plain or DOT_UI=rich overrides the guess.
framework.ui.screen::detect() {
  local name locale="${LC_ALL:-${LC_CTYPE:-${LANG-}}}"
  UI_MODE=plain
  UI_KEYS=false
  case "${DOT_UI-}" in
    rich) UI_MODE=rich UI_KEYS=true ;;
    plain) ;;
    *)
      if [ "${TERM:-dumb}" != dumb ] && ! framework.console.output::is_unattended; then
        UI_MODE=rich
        [ ! -t 0 ] || UI_KEYS=true
      fi
      ;;
  esac
  UI_GLYPHS=unicode
  case "$locale" in
    *[Uu][Tt][Ff]-8* | *[Uu][Tt][Ff]8*) ;;
    *) UI_GLYPHS=ascii ;;
  esac
  case "${OSTYPE-}" in
    msys* | cygwin*) [ -n "${WT_SESSION-}" ] || [ "${TERM_PROGRAM-}" = mintty ] || UI_GLYPHS=ascii ;;
  esac
  [ "$UI_GLYPHS" = ascii ] || return 0
  for name in ${!UI_GLYPH_*} ${!UI_HINT_*}; do
    case "$name" in
      *_ASCII) printf -v "${name%_ASCII}" '%s' "${!name}" ;;
    esac
  done
  UI_SPINNER_FRAMES=("${UI_SPINNER_FRAMES_ASCII[@]}")
  UI_STEPS_LOADER_FRAMES=("${UI_STEPS_LOADER_FRAMES_ASCII[@]}")
}

# Whether what goes to <descriptor> (stderr by default) is drawn for a person.
framework.ui.screen::is_rich() {
  [ "$UI_MODE" = rich ] && [ "${DOT_JSON-}" != true ] && { [ "${DOT_UI-}" = rich ] || [ -t "${1:-2}" ]; }
}

# Whether the person answers with keys.
framework.ui.screen::reads_keys() {
  $UI_KEYS && framework.ui.screen::is_rich 2
}

framework.ui.screen::width() {
  local size=""
  framework.ui.screen::is_rich && size=$({ stty size; } 2>/dev/null </dev/tty)
  case "${size##* }" in
    '' | 0 | *[!0-9]*) framework.console.output::width ;;
    *) printf '%s\n' "${size##* }" ;;
  esac
}

framework.ui.screen::question() {
  framework.console.output::paint "$UI_STYLE_HEADING" "$1"
}

# A hint under an input, dimmed.
framework.ui.screen::hint() {
  framework.console.output::paint "$UI_STYLE_HINT" "$1"
}

# <text> (marked up, one line or more) on stderr as the current frame, in
# place of the one before it; boxed inside box::wrap.
framework.ui.screen::draw() {
  local text="$1" newlines
  ! $UI_BOX_ACTIVE || text=$(framework.ui.screen::boxed "$UI_BOX_TITLE" "$text")
  framework.ui.screen::erase
  framework.console.output::render 2 "$text" >&2
  printf '\n' >&2
  newlines="${text//[!$'\n']/}"
  UI_FRAME_LINES=$((${#newlines} + 1))
}

# draw, kept: the next frame goes under it.
framework.ui.screen::settle() {
  framework.ui.screen::draw "$1"
  UI_FRAME_LINES=0
}

framework.ui.screen::erase() {
  [ "$UI_FRAME_LINES" -eq 0 ] || printf '\033[%dA\r\033[J' "$UI_FRAME_LINES" >&2
  UI_FRAME_LINES=0
}

# The <answer> to <question> as one line, in <style>, in place of the frame
# that asked it.
framework.ui.screen::answer() {
  framework.ui.screen::settle "$(framework.ui.screen::question "$1") $(framework.console.output::paint "$UI_STYLE_POINTER" "$UI_GLYPH_POINTER") $(framework.console.output::paint "${3:-$UI_STYLE_ANSWER}" "$2")"
}

# <glyph> <count> times over.
framework.ui.screen::repeat() {
  local glyph="$1" count="$2" spaces
  [ "$count" -gt 0 ] || return 0
  printf -v spaces '%*s' "$count" ''
  printf '%s' "${spaces// /$glyph}"
}

# One option of an input: the pointer when <hovered>, <mark> in the on or off
# style by <on>, and <label>, bold when hovered.
framework.ui.screen::option() {
  local hovered="$1" mark="$2" on="$3" label="$4" pointer=" " mark_style="$UI_STYLE_OFF"
  ! $on || mark_style="$UI_STYLE_ON"
  if $hovered; then
    pointer=$(framework.console.output::paint "$UI_STYLE_POINTER" "$UI_GLYPH_POINTER")
    label=$(framework.console.output::paint "$UI_STYLE_HOVERED" "$label")
  fi
  printf '%s %s %s' "$pointer" "$(framework.console.output::paint "$mark_style" "$mark")" "$label"
}

# <text>'s lines in a box drawn in <style>, under <title> when there is one.
framework.ui.screen::boxed() {
  local title="$1" text="$2" style="${3:-$UI_STYLE_BOX}" line plain width=0 index pad padding edge vertical
  local rows=() lengths=()
  [ -z "$title" ] || rows+=("$(framework.console.output::paint "$UI_STYLE_BOX_TITLE" "$title")" "")
  while IFS= read -r line || [ -n "$line" ]; do
    rows+=("$line")
  done <<< "$text"
  for line in "${rows[@]}"; do
    plain=$(framework.console.output::plain "$line")
    lengths+=("${#plain}")
    [ "${#plain}" -le "$width" ] || width=${#plain}
  done
  printf -v padding '%*s' "$UI_BOX_PADDING" ''
  edge=$(framework.ui.screen::repeat "$UI_GLYPH_BOX_HORIZONTAL" $((width + 2 * UI_BOX_PADDING)))
  vertical=$(framework.console.output::paint "$style" "$UI_GLYPH_BOX_VERTICAL")
  framework.console.output::paint "$style" "$UI_GLYPH_BOX_TOP_LEFT$edge$UI_GLYPH_BOX_TOP_RIGHT"
  for index in "${!rows[@]}"; do
    printf -v pad '%*s' $((width - lengths[index])) ''
    printf '\n%s%s%s%s%s%s' "$vertical" "$padding" "${rows[index]}" "$pad" "$padding" "$vertical"
  done
  printf '\n'
  framework.console.output::paint "$style" "$UI_GLYPH_BOX_BOTTOM_LEFT$edge$UI_GLYPH_BOX_BOTTOM_RIGHT"
}

# Starts asking: a blank line, the cursor hidden, typed keys not echoed, and
# Ctrl-C cancelling.
framework.ui.screen::begin() {
  UI_TTY=$(stty -g 2>/dev/null) || UI_TTY=""
  [ -z "$UI_TTY" ] || stty -echo 2>/dev/null || true
  UI_TRAPS=$(trap -p INT TERM)
  trap 'framework.ui.screen::cancel' INT TERM
  printf '\n\033[?25l' >&2
}

# The terminal as it was before begin.
framework.ui.screen::end() {
  trap - INT TERM
  [ -z "$UI_TRAPS" ] || eval "$UI_TRAPS"
  [ -z "$UI_TTY" ] || stty "$UI_TTY" 2>/dev/null || true
  printf '\033[?25h' >&2
}

# The next steps to show when the person cancels.
framework.ui.screen::on_cancel() {
  UI_CANCEL_STEPS=("$@")
}

# Cancelled mid-answer (Ctrl-C, Esc, q): the terminal as it was, the frame
# gone, the word it's cancelled with the steps from on_cancel, and the whole
# run stopped as Ctrl-C stops it (status 130), even from inside $(...).
framework.ui.screen::cancel() {
  local IFS=$' \t\n'
  framework.ui.screen::end
  framework.ui.screen::erase
  framework.console.output::cancelled "$UI_LABEL_CANCELLED" ${UI_CANCEL_STEPS[@]+"${UI_CANCEL_STEPS[@]}"}
  kill -INT "$$" 2>/dev/null || true
  exit 130
}

# The next key pressed, into UI_KEY: up, down, left, right, enter, space,
# tab, escape, eof (nothing left to read), or the character typed; k and j
# read as up and down, h and l as left and right.
framework.ui.screen::read_key() {
  local key="" rest=""
  if ! IFS= read -rsn1 key; then
    UI_KEY=eof
    return
  fi
  case "$key" in
    $'\033')
      IFS= read -rsn2 -t 1 rest || true
      case "$rest" in
        '[A' | OA) UI_KEY=up ;;
        '[B' | OB) UI_KEY=down ;;
        '[C' | OC) UI_KEY=right ;;
        '[D' | OD) UI_KEY=left ;;
        '') UI_KEY=escape ;;
        *) UI_KEY=other ;;
      esac
      ;;
    '' | $'\n' | $'\r') UI_KEY=enter ;;
    ' ') UI_KEY=space ;;
    $'\t') UI_KEY=tab ;;
    k) UI_KEY=up ;;
    j) UI_KEY=down ;;
    h) UI_KEY=left ;;
    l) UI_KEY=right ;;
    *) UI_KEY="$key" ;;
  esac
}

framework.ui.screen::detect
