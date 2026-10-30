# shellcheck shell=bash

hey::use framework.helpers.secrets framework.helpers.fs framework.ui.theme

OUTPUT_HIGHLIGHTER="${BASH_SOURCE[0]%/*}/highlight.awk"
OUTPUT_HIGHLIGHT=true

# Exit statuses (set by dotHey's boot; these are the defaults).
: "${EXIT_FAILURE:=1}" "${EXIT_USAGE:=2}" "${EXIT_NOT_FOUND:=4}" "${EXIT_PRECONDITION:=5}"

# Whether an AI agent runs this (AI_AGENT set, or CLAUDECODE=1): the output
# then asks the agent to hand over what needs a person.
framework.console.output::is_agent() {
  [ -n "${AI_AGENT-}" ] || [ "${CLAUDECODE-}" = 1 ]
}

# Whether no person is there to answer: an agent, or HEY_NO_INPUT=1 (--no-input,
# CI). Nothing then prompts, even on a terminal, and the output stays plain text,
# without colors, highlighting, or a spinner.
framework.console.output::is_unattended() {
  framework.console.output::is_agent || [ "${HEY_NO_INPUT-}" = 1 ]
}

# Whether FORCE_COLOR or CLICOLOR_FORCE asks for colors wherever the output goes.
framework.console.output::is_color_forced() {
  case "${FORCE_COLOR-}" in '' | 0 | false) ;; *) return 0 ;; esac
  case "${CLICOLOR_FORCE-}" in '' | 0) return 1 ;; esac
}

OUTPUT_MANUAL_RUN="Please run the command manually:"
! framework.console.output::is_agent || OUTPUT_MANUAL_RUN="Please ask the user to run it in a terminal:"

framework.console.output::is_styled() {
  [ -z "${NO_COLOR-}" ] || return 1
  framework.console.output::is_color_forced \
    || { [ -t "${1:-1}" ] && [ "${TERM-}" != dumb ] && ! framework.console.output::is_unattended; }
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
# yellow, blue, magenta, cyan, gray, light-blue, bright (the bright variant
# of the colors inside it), bg-red, bg-green, or bg-blue.
framework.console.output::style() {
  [ -z "$2" ] || printf '\001%s\002%s\003' "$1" "$2"
}

# <text> in <styles>, a theme's space-separated list of primitive styles,
# the first outermost.
framework.console.output::paint() {
  local styles="$1" text="$2" style opened="" closed="" IFS=' '
  [ -n "$text" ] || return 0
  for style in $styles; do
    opened="$opened"$'\001'"$style"$'\002'
    closed="$closed"$'\003'
  done
  printf '%s%s%s' "$opened" "$text" "$closed"
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
framework.console.output::path() { framework.console.output::paint "$UI_STYLE_PATH" "$*"; }
framework.console.output::command() { framework.console.output::paint "$UI_STYLE_COMMAND" "$*"; }
framework.console.output::value() { framework.console.output::paint "$UI_STYLE_VALUE" "$*"; }
framework.console.output::setting() { framework.console.output::paint "$UI_STYLE_SETTING" "$*"; }
framework.console.output::code() { framework.console.output::paint "$UI_STYLE_CODE" "$*"; }
framework.console.output::heading() { framework.console.output::paint "$UI_STYLE_HEADING" "$*"; }
framework.console.output::note() { framework.console.output::paint "$UI_STYLE_NOTE" "$*"; }

# Marked-up <text> as it prints on <descriptor>: escape codes at a terminal,
# plain text anywhere else, with no newline added.
framework.console.output::render() {
  local descriptor="$1" text="$2"
  if framework.console.output::paints "$descriptor"; then
    printf '%s' "$(printf '%s\n' "$text" | awk -v styled=1 -f "$OUTPUT_RENDERER")"
    return
  fi
  framework.console.output::plain "$text"
}

# Marked-up <text> without its markup, with no newline added.
framework.console.output::plain() {
  local text="$1" rest
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
      printf '%s\n' "$text" | framework.console.output::highlight | awk -v styled=1 -f "$OUTPUT_RENDERER" >&"$descriptor"
    else
      printf '%s\n' "$text" | awk -v styled=1 -f "$OUTPUT_RENDERER" >&"$descriptor"
    fi
  else
    printf '%s\n' "$(framework.console.output::render "$descriptor" "$text")" >&"$descriptor"
  fi
}

# Lines on stdin, their commands, paths, values, and references marked up in
# the theme's styles (highlight.awk).
framework.console.output::highlight() {
  awk -v command_style="$UI_STYLE_COMMAND" -v path_style="$UI_STYLE_PATH" -v value_style="$UI_STYLE_VALUE" \
    -v reference_style="$UI_STYLE_REFERENCE" -f "$OUTPUT_HIGHLIGHTER"
}

# Keeps printing from copies of the files output reads, for a run that moves
# them (dotHey moving itself); the copies go when the run ends.
framework.console.output::detach() {
  local copies
  framework.helpers.fs::make_temp_dir copies || return 1
  cp -- "$OUTPUT_RENDERER" "$OUTPUT_HIGHLIGHTER" "$copies/" || return 1
  OUTPUT_RENDERER="$copies/${OUTPUT_RENDERER##*/}"
  OUTPUT_HIGHLIGHTER="$copies/${OUTPUT_HIGHLIGHTER##*/}"
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
# styled, the rest left plain: section headings bold blue; bash hey, command
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
          if ((core == "bash" && words[i + 1] == "hey") || (core == "hey" && words[i - 1] ~ /bash$/)) core = styled(core, "bold")
          else if (core ~ /^--?[A-Za-z][A-Za-z0-9-]*$/ || core ~ /^--<[^>]+>$/) core = optional ? styled(core, "bold", "italic") : styled(core, "bold")
          else if (core == "options" && head ~ /\[$/) core = styled(core, "bold", "italic")
          else if (core ~ /^[a-z]+:[a-z][a-z:-]*$/ || (i > 2 && words[i - 1] == "hey" && words[i - 2] ~ /bash$/ && core ~ /^[a-z][a-z:-]*$/)) { core = styled(core, "bold"); command = 1 }
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
  framework.console.output::emit 1 "$(framework.console.output::paint "$UI_STYLE_TITLE" "$*")"
}

framework.console.output::success() {
  framework.console.output::emit 1 "$(framework.console.output::paint "$UI_STYLE_SUCCESS" "$UI_ICON_SUCCESS") $*"
}

# A record just made: <message>, its <path> under it; under --json,
# {"id", "path"} instead.
framework.console.output::created() {
  local message="$1" id="$2" path="$3"
  if [ "${HEY_JSON-}" = true ]; then
    hey::use framework.helpers.json
    printf '{"id":%s,"path":%s}\n' "$(framework.helpers.json::string "$id")" "$(framework.helpers.json::string "$path")"
    return
  fi
  framework.console.output::success "$message"
  framework.console.output::detail "$path"
}

# A side note: its icon in the theme's info style.
# A side note: its icon in the theme's info style. Under --json, a notice on
# stderr (json_message), so stdout keeps only the result.
framework.console.output::info() {
  [ "${HEY_JSON-}" != true ] || { framework.console.output::json_message notice "$*"; return; }
  framework.console.output::emit 1 "$(framework.console.output::paint "$UI_STYLE_INFO" "$UI_ICON_INFO") $*"
}

framework.console.output::tip() {
  framework.console.output::emit 1 "$(framework.console.output::bold "$UI_TIP_LABEL") $*"
}

framework.console.output::detail() {
  framework.console.output::emit 1 "$UI_INDENT$*"
}

# The next step to take, under the message it follows.
framework.console.output::next() {
  [ "${HEY_JSON-}" != true ] || { framework.console.output::json_message next "$*"; return; }
  framework.console.output::emit 1 "$UI_INDENT$(framework.console.output::paint "$UI_STYLE_NEXT" "$UI_ICON_NEXT") $*"
}

# A listed change: <symbol> in <color> (one of the theme's UI_MARK_*), what
# it is, and a note.
framework.console.output::entry() {
  local color="$1" symbol="$2" text="$3" note="${4-}"
  framework.console.output::emit 1 "$UI_INDENT$(framework.console.output::bold "$(framework.console.output::style "$color" "$symbol")") $text${note:+ $(framework.console.output::note "$note")}"
}

# A file's change as git shows it: added, removed, or changed.
framework.console.output::change() {
  case "$1" in
    added) framework.console.output::entry green "$UI_MARK_ADDED" "$2" "${3-}" ;;
    removed) framework.console.output::entry red "$UI_MARK_REMOVED" "$2" "${3-}" ;;
    *) framework.console.output::entry yellow "$UI_MARK_CHANGED" "$2" "${3-}" ;;
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
  [ "${HEY_JSON-}" != true ] || { framework.console.output::json_message warning "$*"; return; }
  framework.console.output::emit 2 "$(framework.console.output::paint "$UI_STYLE_WARNING" "$UI_ICON_WARNING $*")"
}

# <message>, then each further argument as a next step under it; under --json
# (HEY_JSON=true), one JSON error on stderr instead, for the exit status in
# OUTPUT_ERROR_STATUS (fail_as sets it).
framework.console.output::error() {
  local step
  if [ "${HEY_JSON-}" = true ]; then
    framework.console.output::json_error "${OUTPUT_ERROR_STATUS:-$EXIT_FAILURE}" "$@"
    return
  fi
  framework.console.output::emit 2 "$(framework.console.output::paint "$UI_STYLE_ERROR" "$UI_ICON_ERROR") $1"
  shift
  for step in "$@"; do
    framework.console.output::next "$step" >&2
  done
}

# {"error": {"code", "exitCode", "message", "run", "next"}} on stderr: "run" is
# the first dotHey command among the next steps, or null.
framework.console.output::json_error() {
  local status="$1" message="$2" code step run=null next=""
  shift 2
  hey::use framework.helpers.json
  case "$status" in
    "$EXIT_USAGE") code=USAGE ;;
    "$EXIT_NOT_FOUND") code=NOT_FOUND ;;
    "$EXIT_PRECONDITION") code=PRECONDITION ;;
    *) code=FAILED ;;
  esac
  for step in "$@"; do
    step=$(framework.helpers.secrets::mask "$(framework.console.output::plain "$step")")
    [ "$run" != null ] || [[ "$step" != *"bash hey "* ]] || run=$(framework.helpers.json::string "bash hey ${step#*bash hey }")
    next="$next${next:+,}$(framework.helpers.json::string "$step")"
  done
  message=$(framework.helpers.secrets::mask "$(framework.console.output::plain "$message")")
  printf '{"error":{"code":"%s","exitCode":%s,"message":%s,"run":%s,"next":[%s]}}\n' \
    "$code" "$status" "$(framework.helpers.json::string "$message")" "$run" "$next" >&2
}

# A diagnostic under --json, one line of JSON on stderr, as an error is:
# {"<kind>": {"message", "run"}} for a warning, notice, or next step; "run" is
# the dotHey command in it, or null.
framework.console.output::json_message() {
  local kind="$1" message run=null
  hey::use framework.helpers.json
  message=$(framework.helpers.secrets::mask "$(framework.console.output::plain "$2")")
  [[ "$message" != *"bash hey "* ]] || run=$(framework.helpers.json::string "bash hey ${message#*bash hey }")
  printf '{"%s":{"message":%s,"run":%s}}\n' "$kind" "$(framework.helpers.json::string "$message")" "$run" >&2
}

# error, then exit <status> (one of EXIT_*).
framework.console.output::fail_as() {
  local OUTPUT_ERROR_STATUS="$1"
  shift
  framework.console.output::error "$@"
  exit "$OUTPUT_ERROR_STATUS"
}

framework.console.output::fail() {
  framework.console.output::fail_as "$EXIT_FAILURE" "$@"
}

# Stopped by the person: <message> in red, then each further argument as a
# next step under it.
framework.console.output::cancelled() {
  local step
  framework.console.output::emit 2 "$(framework.console.output::paint "$UI_STYLE_CANCELLED" "$UI_ICON_CANCELLED $1")"
  shift
  for step in "$@"; do
    framework.console.output::next "$step" >&2
  done
  printf '\n' >&2
}

framework.console.output::aborted() {
  framework.console.output::cancelled "$UI_LABEL_ABORTED" "$@"
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
    '' | 0 | *[!0-9]*) width=$UI_WIDTH ;;
  esac
  printf '%s\n' "$width"
}
