# shellcheck shell=bash

dot::use framework.ui.screen

# A message of one line, with up to two more under it: indented for info,
# success, and warning; as next steps for an error.

framework.ui.message::info() {
  framework.console.output::info "$1"
  framework.ui.message::details 1 "${@:2}"
}

framework.ui.message::success() {
  framework.console.output::success "$1"
  framework.ui.message::details 1 "${@:2}"
}

framework.ui.message::warning() {
  framework.console.output::warn "$1"
  framework.ui.message::details 2 "${@:2}"
}

framework.ui.message::error() {
  framework.console.output::error "$@"
}

# Each <line> indented, on <descriptor>.
framework.ui.message::details() {
  local descriptor="$1" line
  shift
  for line in "$@"; do
    framework.console.output::emit "$descriptor" "$UI_INDENT$line"
  done
}
