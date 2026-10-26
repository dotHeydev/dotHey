#!/usr/bin/env bash

dot::use framework.helpers.secrets

OUTPUT_SUCCESS_ICON="✅"
OUTPUT_ERROR_ICON="❌"
OUTPUT_WARNING_ICON="⚠️ "
OUTPUT_INFO_ICON="ℹ️ "
OUTPUT_INDENT="   "
OUTPUT_DEFAULT_WIDTH=80
# The spinner shared with install.sh: one frame every SPINNER_INTERVAL seconds.
SPINNER_FRAMES=(' ·●' ' •⏺' ' ⏺•' ' ●·' ' ⏺•' ' •⏺' ' ·●')
SPINNER_INTERVAL=0.07
SPINNER_GRACE_FRAMES=4

framework.console.output::is_styled() {
  [ -t "${1:-1}" ] && [ -z "${NO_COLOR-}" ] && [ "${TERM-}" != dumb ]
}

framework.console.output::style_code() {
  case "$1" in
    bold) printf '\033[1m' ;;
    dim) printf '\033[2m' ;;
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
  if [ -z "$text" ] || ! framework.console.output::is_styled "$descriptor"; then
    printf '%s' "$text"
    return
  fi
  printf '%s%s%s' "$(framework.console.output::style_code "$style")" "$text" "$(framework.console.output::style_code reset)"
}

# Every line printed passes here, onto <descriptor>, with anything that looks
# like a secret masked (framework.helpers.secrets::mask).
framework.console.output::emit() {
  local descriptor="$1"
  shift
  printf '%s\n' "$(framework.helpers.secrets::mask "$*")" >&"$descriptor"
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

framework.console.output::newline() {
  printf '\n'
}

framework.console.output::title() {
  framework.console.output::emit 1 "$(framework.console.output::paint bold "$*")"
}

framework.console.output::success() {
  framework.console.output::emit 1 "$OUTPUT_SUCCESS_ICON $(framework.console.output::paint green "$*")"
}

framework.console.output::info() {
  framework.console.output::emit 1 "$OUTPUT_INFO_ICON $*"
}

framework.console.output::detail() {
  framework.console.output::emit 1 "$OUTPUT_INDENT$*"
}

framework.console.output::item() {
  local label="$1" note="${2-}" style="${3:-dim}"
  if [ -z "$note" ]; then
    framework.console.output::emit 1 "  $label"
    return
  fi
  framework.console.output::emit 1 "  $label $(framework.console.output::paint "$style" "($note)")"
}

framework.console.output::warn() {
  framework.console.output::emit 2 "$OUTPUT_WARNING_ICON $(framework.console.output::paint yellow "$*" 2)"
}

framework.console.output::error() {
  framework.console.output::emit 2 "$OUTPUT_ERROR_ICON $(framework.console.output::paint red "$*" 2)"
}

framework.console.output::fail() {
  framework.console.output::error "$@"
  exit 1
}

framework.console.output::aborted() {
  local hint="${1-}"
  framework.console.output::emit 2 "Aborted — nothing changed.${hint:+ $hint}"
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
  if [ ! -t 2 ]; then
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
