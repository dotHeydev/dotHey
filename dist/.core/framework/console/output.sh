#!/usr/bin/env bash

dot::use framework.helpers.secrets

OUTPUT_SUCCESS_ICON="✓"
OUTPUT_ERROR_ICON="✗"
OUTPUT_WARNING_ICON="!"
OUTPUT_INFO_ICON="ℹ"
OUTPUT_NEXT_ICON="→"
OUTPUT_SEPARATOR="•"
OUTPUT_TIP_LABEL="💡 Tip:"
OUTPUT_INDENT="   "
OUTPUT_HIGHLIGHTER="${BASH_SOURCE[0]%/*}/highlight.awk"
OUTPUT_HIGHLIGHT=true
OUTPUT_DEFAULT_WIDTH=80
# The spinner shared with install.sh: one frame every SPINNER_INTERVAL seconds.
SPINNER_FRAMES=(' ·●' ' •⏺' ' ⏺•' ' ●·' ' ⏺•' ' •⏺' ' ·●')
SPINNER_INTERVAL=0.07
SPINNER_GRACE_FRAMES=4

# Whether an AI agent runs this (AI_AGENT set, or CLAUDECODE=1): the output
# then stays plain text, without colors, highlighting, or a spinner, and asks
# the agent to hand over what needs a person.
framework.console.output::is_agent() {
  [ -n "${AI_AGENT-}" ] || [ "${CLAUDECODE-}" = 1 ]
}

OUTPUT_MANUAL_RUN="Please run the command manually:"
! framework.console.output::is_agent || OUTPUT_MANUAL_RUN="Please ask the user to run it in a terminal:"

framework.console.output::is_styled() {
  [ -t "${1:-1}" ] && [ -z "${NO_COLOR-}" ] && [ "${TERM-}" != dumb ] && ! framework.console.output::is_agent
}

# Whether stdout and stderr take styles, fixed as this loads: paint mostly
# runs inside $(...), where stdout is the capturing pipe, not the terminal.
OUTPUT_STYLED_OUT=false
OUTPUT_STYLED_ERR=false
! framework.console.output::is_styled 1 || OUTPUT_STYLED_OUT=true
! framework.console.output::is_styled 2 || OUTPUT_STYLED_ERR=true

# Whether text built for <descriptor> takes styles.
framework.console.output::paints() {
  case "${1:-1}" in
    2) $OUTPUT_STYLED_ERR ;;
    *) $OUTPUT_STYLED_OUT ;;
  esac
}

framework.console.output::style_code() {
  case "$1" in
    bold) printf '\033[1m' ;;
    dim) printf '\033[2m' ;;
    italic) printf '\033[3m' ;;
    gray) printf '\033[90m' ;;
    light-blue) printf '\033[94m' ;;
    red) printf '\033[31m' ;;
    green) printf '\033[32m' ;;
    yellow) printf '\033[33m' ;;
    blue) printf '\033[34m' ;;
    cyan) printf '\033[36m' ;;
    reset) printf '\033[0m' ;;
  esac
}

framework.console.output::paint() {
  local style="$1" text="$2" descriptor="${3:-1}"
  if [ -z "$text" ] || ! framework.console.output::paints "$descriptor"; then
    printf '%s' "$text"
    return
  fi
  printf '%s%s%s' "$(framework.console.output::style_code "$style")" "$text" "$(framework.console.output::style_code reset)"
}

# Every line printed passes here, onto <descriptor>, with anything that looks
# like a secret masked (framework.helpers.secrets::mask), and at a terminal its
# commands, paths, and values styled (highlight.awk) unless OUTPUT_HIGHLIGHT
# is false.
framework.console.output::emit() {
  local descriptor="$1" text
  shift
  text=$(framework.helpers.secrets::mask "$*")
  if $OUTPUT_HIGHLIGHT && framework.console.output::is_styled "$descriptor"; then
    printf '%s\n' "$text" | awk -f "$OUTPUT_HIGHLIGHTER" >&"$descriptor"
  else
    printf '%s\n' "$text" >&"$descriptor"
  fi
}

# Each line of <file> through emit, then the file removed.
framework.console.output::emit_file() {
  local line
  while IFS= read -r line || [ -n "$line" ]; do
    framework.console.output::emit "$1" "$line"
  done < "$2"
  rm -f -- "$2"
}

framework.console.output::line() {
  framework.console.output::emit 1 "$*"
}

# A help page on stdin, styled at a terminal: section headings bold, the
# options and arguments column cyan, and commands, paths, and values as every
# line is.
framework.console.output::help() {
  if ! framework.console.output::paints 1; then
    cat
    return
  fi
  awk -f "$OUTPUT_HIGHLIGHTER" | awk -v bold="$(framework.console.output::style_code bold)" -v cyan="$(framework.console.output::style_code cyan)" -v reset="$(framework.console.output::style_code reset)" '
    /^[A-Z][A-Za-z ()".,-]*:$/ { print bold $0 reset; next }
    /^  (-|<|@)/ {
      rest = substr($0, 3)
      split_at = index(rest, "  ")
      if (split_at == 0) { print "  " cyan rest reset; next }
      print "  " cyan substr(rest, 1, split_at - 1) reset substr(rest, split_at)
      next
    }
    { print }
  '
}

# One row of a help page's options: <option> in a column <width> wide, then
# <text>, or on the next line when <option> doesn't fit.
framework.console.output::option() {
  local option="$1" text="$2" width="$3"
  if [ "${#option}" -lt "$width" ]; then
    printf '  %-*s%s\n' "$width" "$option" "$text"
  else
    printf '  %s\n  %-*s%s\n' "$option" "$width" "" "$text"
  fi
}

framework.console.output::newline() {
  printf '\n'
}

framework.console.output::title() {
  framework.console.output::emit 1 "$(framework.console.output::paint bold "$*")"
}

framework.console.output::success() {
  framework.console.output::emit 1 "$(framework.console.output::paint green "$OUTPUT_SUCCESS_ICON") $*"
}

# A side note: light blue, its text in italics.
framework.console.output::info() {
  local OUTPUT_HIGHLIGHT=false
  framework.console.output::emit 1 "$(framework.console.output::paint light-blue "$OUTPUT_INFO_ICON $(framework.console.output::paint italic "$*")")"
}

framework.console.output::tip() {
  framework.console.output::emit 1 "$OUTPUT_TIP_LABEL $*"
}

framework.console.output::detail() {
  framework.console.output::emit 1 "$OUTPUT_INDENT$*"
}

# The next step to take, under the message it follows.
framework.console.output::next() {
  framework.console.output::emit 1 "$OUTPUT_INDENT$(framework.console.output::paint blue "$OUTPUT_NEXT_ICON") $*"
}

# A listed change: <symbol> in <color> (+ new, - removed, * changed, ~ linked,
# > appended, ! taken, · unchanged), what it is, and a note in light-blue
# italics.
framework.console.output::entry() {
  local color="$1" symbol="$2" text="$3" note="${4-}"
  framework.console.output::emit 1 "$OUTPUT_INDENT$(framework.console.output::paint "$color" "$symbol") $text${note:+ $(framework.console.output::paint light-blue "$(framework.console.output::paint italic "$note")")}"
}

# A file's change as git shows it: added, removed, or changed.
framework.console.output::change() {
  case "$1" in
    added) framework.console.output::entry green "+" "$2" "${3-}" ;;
    removed) framework.console.output::entry red "-" "$2" "${3-}" ;;
    *) framework.console.output::entry yellow "*" "$2" "${3-}" ;;
  esac
}

framework.console.output::item() {
  local label="$1" note="${2-}" style="${3:-dim}"
  if [ -z "$note" ]; then
    framework.console.output::emit 1 "  $label"
    return
  fi
  framework.console.output::emit 1 "  $label $(framework.console.output::paint "$style" "($note)")"
}

# A warning, all of it yellow.
framework.console.output::warn() {
  local OUTPUT_HIGHLIGHT=false
  framework.console.output::emit 2 "$(framework.console.output::paint yellow "$OUTPUT_WARNING_ICON $*" 2)"
}

# <message>, then each further argument as a next step under it.
framework.console.output::error() {
  local step
  framework.console.output::emit 2 "$(framework.console.output::paint red "$OUTPUT_ERROR_ICON" 2) $1"
  shift
  for step in "$@"; do
    framework.console.output::next "$step" >&2
  done
}

framework.console.output::fail() {
  framework.console.output::error "$@"
  exit 1
}

framework.console.output::aborted() {
  local hint="${1-}"
  framework.console.output::emit 2 "Cancelled — nothing changed."
  [ -z "$hint" ] || framework.console.output::next "$hint" >&2
}

framework.console.output::width() {
  local width=""
  if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
    width=$(tput cols 2>/dev/null || true)
  fi
  case "$width" in
    '' | *[!0-9]*) width="${COLUMNS-}" ;;
  esac
  case "$width" in
    '' | 0 | *[!0-9]*) width=$OUTPUT_DEFAULT_WIDTH ;;
  esac
  printf '%s\n' "$width"
}

framework.console.output::rule() {
  local width="${1:-$(framework.console.output::width)}" rule
  rule=$(printf '%*s' "$width" '')
  printf '%s\n' "${rule// /-}"
}

framework.console.output::spin() {
  local label="$1" errors status=0 process tick=0 drawn=false frame_count=${#SPINNER_FRAMES[@]}
  shift
  errors=$(mktemp) || return 1
  if [ ! -t 2 ] || framework.console.output::is_agent; then
    [ -z "$label" ] || framework.console.output::emit 2 "$label"
    "$@" 2>"$errors" || status=$?
    framework.console.output::emit_file 2 "$errors"
    return "$status"
  fi
  "$@" 2>"$errors" &
  process=$!
  while kill -0 "$process" 2>/dev/null; do
    if [ "$tick" -ge "$SPINNER_GRACE_FRAMES" ] || [ -n "$label" ]; then
      printf '\r%s%s ' "$label" "${SPINNER_FRAMES[$((tick % frame_count))]}" >&2
      drawn=true
    fi
    tick=$((tick + 1))
    sleep "$SPINNER_INTERVAL"
  done
  wait "$process" || status=$?
  if $drawn; then
    printf '\r\033[K' >&2
  fi
  [ -z "$label" ] || framework.console.output::emit 2 "$label"
  framework.console.output::emit_file 2 "$errors"
  return "$status"
}
