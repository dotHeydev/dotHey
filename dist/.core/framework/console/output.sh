#!/usr/bin/env bash

dot::use framework.helpers.secrets

OUTPUT_SUCCESS_ICON="✓"
OUTPUT_ERROR_ICON="✗"
OUTPUT_WARNING_ICON="!"
OUTPUT_INFO_ICON="i"
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

# Whether stdout and stderr take styles, fixed as this loads: styles are mostly
# built inside $(...), where stdout is the capturing pipe, not the terminal.
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

# Styles are markup, \001<name>\002<text>\003, turned into escape codes only as
# a line is printed (render.awk), so they nest: an inner style ends without
# ending the one around it. Three levels build on each other: primitives
# (bold, red, ...), what a piece of text is (a path, a command, ...), and the
# messages themselves (success, error, ...).
OUTPUT_RENDERER="${BASH_SOURCE[0]%/*}/render.awk"

# <text> in one primitive style: bold, dim, italic, underline, red, green,
# yellow, blue, magenta, cyan, gray, light-blue, or bright (the bright variant
# of the colors inside it).
framework.console.output::style() {
  [ -z "$2" ] || printf '\001%s\002%s\003' "$1" "$2"
}

framework.console.output::bold() { framework.console.output::style bold "$*"; }
framework.console.output::italic() { framework.console.output::style italic "$*"; }
framework.console.output::dim() { framework.console.output::style dim "$*"; }
framework.console.output::red() { framework.console.output::style red "$*"; }
framework.console.output::green() { framework.console.output::style green "$*"; }
framework.console.output::yellow() { framework.console.output::style yellow "$*"; }
framework.console.output::blue() { framework.console.output::style blue "$*"; }
framework.console.output::cyan() { framework.console.output::style cyan "$*"; }
framework.console.output::gray() { framework.console.output::style gray "$*"; }
framework.console.output::light_blue() { framework.console.output::style light-blue "$*"; }
framework.console.output::bright() { framework.console.output::style bright "$*"; }

# What a piece of text is, each one a composition of primitives.
framework.console.output::path() { framework.console.output::gray "$*"; }
framework.console.output::command() { framework.console.output::bold "$(framework.console.output::bright "$*")"; }
framework.console.output::value() { framework.console.output::italic "$*"; }
framework.console.output::setting() { framework.console.output::italic "$(framework.console.output::bright "$*")"; }
framework.console.output::code() { framework.console.output::cyan "$*"; }
framework.console.output::heading() { framework.console.output::bold "$(framework.console.output::blue "$*")"; }
framework.console.output::note() { framework.console.output::light_blue "$(framework.console.output::italic "$*")"; }

# Marked-up <text> as it prints on <descriptor>: escape codes at a terminal,
# plain text anywhere else, with no newline added.
framework.console.output::render() {
  local descriptor="$1" text="$2" rest
  if framework.console.output::paints "$descriptor"; then
    printf '%s' "$(printf '%s\n' "$text" | awk -v styled=1 -f "$OUTPUT_RENDERER")"
    return
  fi
  while [[ "$text" == *$'\001'* ]]; do
    rest="${text#*$'\001'}"
    text="${text%%$'\001'*}${rest#*$'\002'}"
  done
  printf '%s' "${text//$'\003'/}"
}

# Every line printed passes here, onto <descriptor>: anything that looks like
# a secret masked (framework.helpers.secrets::mask), then, at a terminal, its
# commands, paths, and values marked up (highlight.awk) unless OUTPUT_HIGHLIGHT
# is false, and its markup rendered.
framework.console.output::emit() {
  local descriptor="$1" text
  shift
  text=$(framework.helpers.secrets::mask "$*")
  if framework.console.output::paints "$descriptor"; then
    if $OUTPUT_HIGHLIGHT; then
      printf '%s\n' "$text" | awk -f "$OUTPUT_HIGHLIGHTER" | awk -v styled=1 -f "$OUTPUT_RENDERER" >&"$descriptor"
    else
      printf '%s\n' "$text" | awk -v styled=1 -f "$OUTPUT_RENDERER" >&"$descriptor"
    fi
  else
    printf '%s\n' "$(framework.console.output::render "$descriptor" "$text")" >&"$descriptor"
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

# A help page on stdin, its optional options marked (optional.awk), then a
# blank line. At a terminal only these are
# styled, the rest left plain: section headings bold blue; bash dot, command
# names, [options], and --flags bold; in a command line (a usage line, an
# example), the values it gives and everything optional ([...]) in italics
# too; settings, paths, and link shortcuts italic bright, a shortcut's
# @<name>: bold.
framework.console.output::help() {
  awk -f "${BASH_SOURCE[0]%/*}/optional.awk" | framework.console.output::style_help
  printf '\n'
}

# The styling of a help page on stdin (see help), at a terminal only.
framework.console.output::style_help() {
  if framework.console.output::paints 1; then
    awk -v OPEN="$(printf '\001')" -v NAME_END="$(printf '\002')" -v CLOSE="$(printf '\003')" '
      function styled(text, a, b, c) { return OPEN a NAME_END (b == "" ? "" : OPEN b NAME_END) (c == "" ? "" : OPEN c NAME_END) text CLOSE (b == "" ? "" : CLOSE) (c == "" ? "" : CLOSE) }
      function is_path(word,   last) {
        if (word ~ /^\.[A-Za-z][A-Za-z0-9_.-]*\/?$/) return 1
        if (word ~ /^[A-Za-z0-9_-]+\.(md|json|sh|conf|txt|yml|yaml|toml|stub)$/) return 1
        if (word !~ /^[~.]?[A-Za-z0-9_@.*-]*(\/[A-Za-z0-9_.@*-]*)+$/) return 0
        last = word
        sub(/^.*\//, "", last)
        return word ~ /^[~.]/ || word ~ /\/$/ || last ~ /\./
      }
      { line($0) }
      # Each <name> in <text>, in italics when <optional>.
      function placeholders(text, optional,   out, name) {
        out = ""
        while (match(text, /<[^>]+>/)) {
          name = substr(text, RSTART, RLENGTH)
          out = out substr(text, 1, RSTART - 1) (optional ? styled(name, "italic") : name)
          text = substr(text, RSTART + RLENGTH)
        }
        return out text
      }
      # How many times <character> is in <text>.
      function times(text, character) { return gsub("\\" character, "", text) }
      function line(text,   count, words, out, command, i, word, head, core, tail, prefix, depth, optional) {
        if (text ~ /^[A-Z][^ ].*:$/) { print styled(text, "bold", "blue"); continued = 0; return }
        count = split(text, words, / /)
        out = ""
        command = continued
        depth = 0
        for (i = 1; i <= count; i++) {
          word = words[i]
          head = word; sub(/[^[("`].*$/, "", head)
          core = substr(word, length(head) + 1)
          tail = core; sub(/^.*[^])"`.,;:]/, "", tail)
          core = substr(core, 1, length(core) - length(tail))
          if (command) depth += times(head, "[")
          optional = command && depth > 0
          if ((core == "bash" && words[i + 1] == "dot") || (core == "dot" && words[i - 1] ~ /bash$/)) core = styled(core, "bold")
          else if (core ~ /^--?[A-Za-z][A-Za-z0-9-]*$/ || core ~ /^--<[^>]+>$/) core = optional ? styled(core, "bold", "italic") : styled(core, "bold")
          else if (core == "options" && head ~ /\[$/) core = styled(core, "bold", "italic")
          else if (core ~ /^[a-z]+:[a-z][a-z:-]*$/ || (i > 2 && words[i - 1] == "dot" && words[i - 2] ~ /bash$/ && core ~ /^[a-z][a-z:-]*$/)) { core = styled(core, "bold"); command = 1 }
          else if (core ~ /^@[A-Za-z]+:/) { prefix = core; sub(/:.*$/, ":", prefix); core = styled(prefix, "bold") styled(substr(core, length(prefix) + 1), "italic", "bright") }
          else if (core ~ /^@[A-Za-z]+$/) core = styled(core, "italic", "bright")
          else if (core ~ /</) core = placeholders(core, optional)
          else if (!command && (is_path(core) || core ~ /^[a-z]+(\.[a-zA-Z]+)+$/ && core !~ /^(e\.g|i\.e)$/)) core = styled(core, "italic", "bright")
          else if (command && core != "" && core != "\\" && core != "..." && core != "|") core = styled(core, "italic")
          if (command) depth -= times(tail, "]")
          out = out (i > 1 ? " " : "") head core tail
        }
        continued = command && text ~ / \\$/
        print out
      }
    ' | awk -v styled=1 -f "$OUTPUT_RENDERER"
  else
    awk -v styled=0 -f "$OUTPUT_RENDERER"
  fi
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
  framework.console.output::emit 1 "$(framework.console.output::bold "$*")"
}

framework.console.output::success() {
  framework.console.output::emit 1 "$(framework.console.output::bold "$(framework.console.output::green "$OUTPUT_SUCCESS_ICON")") $*"
}

# A side note: light blue, its text in italics.
framework.console.output::info() {
  framework.console.output::emit 1 "$(framework.console.output::light_blue "$(framework.console.output::bold "$OUTPUT_INFO_ICON") $(framework.console.output::italic "$*")")"
}

framework.console.output::tip() {
  framework.console.output::emit 1 "$OUTPUT_TIP_LABEL $*"
}

framework.console.output::detail() {
  framework.console.output::emit 1 "$OUTPUT_INDENT$*"
}

# The next step to take, under the message it follows.
framework.console.output::next() {
  framework.console.output::emit 1 "$OUTPUT_INDENT$(framework.console.output::bold "$(framework.console.output::blue "$OUTPUT_NEXT_ICON")") $*"
}

# A listed change: <symbol> in <color> (+ new, - removed, * changed, ~ linked,
# > appended, ! taken, · unchanged), what it is, and a note.
framework.console.output::entry() {
  local color="$1" symbol="$2" text="$3" note="${4-}"
  framework.console.output::emit 1 "$OUTPUT_INDENT$(framework.console.output::bold "$(framework.console.output::style "$color" "$symbol")") $text${note:+ $(framework.console.output::note "$note")}"
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
  framework.console.output::emit 1 "  $label $(framework.console.output::style "$style" "($note)")"
}

# A warning, all of it yellow.
framework.console.output::warn() {
  framework.console.output::emit 2 "$(framework.console.output::bold "$(framework.console.output::yellow "$OUTPUT_WARNING_ICON $*")")"
}

# <message>, then each further argument as a next step under it.
framework.console.output::error() {
  local step
  framework.console.output::emit 2 "$(framework.console.output::bold "$(framework.console.output::red "$OUTPUT_ERROR_ICON")") $1"
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
