#!/usr/bin/env bash

dot::use framework.ui.screen

# <command> run under <label> with a spinner turning beside it, its errors
# printed once it's done; the label alone in plain output.
framework.ui.spinner::run() {
  local label="$1" errors status=0 process tick=0 drawn=false count=${#UI_SPINNER_FRAMES[@]}
  shift
  errors=$(mktemp) || return 1
  if ! framework.ui.screen::is_rich; then
    [ -z "$label" ] || framework.console.output::emit 2 "$label"
    "$@" 2>"$errors" || status=$?
    framework.console.output::emit_file 2 "$errors"
    return "$status"
  fi
  "$@" 2>"$errors" &
  process=$!
  while kill -0 "$process" 2>/dev/null; do
    if [ "$tick" -ge "$UI_SPINNER_GRACE_FRAMES" ] || [ -n "$label" ]; then
      printf '\r%s%s ' "$label" "${UI_SPINNER_FRAMES[$((tick % count))]}" >&2
      drawn=true
    fi
    tick=$((tick + 1))
    sleep "$UI_SPINNER_INTERVAL"
  done
  wait "$process" || status=$?
  ! $drawn || printf '\r\033[K' >&2
  [ -z "$label" ] || framework.console.output::emit 2 "$label"
  framework.console.output::emit_file 2 "$errors"
  return "$status"
}
