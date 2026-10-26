#!/usr/bin/env bash

dot::use framework.console.output framework.helpers.text

framework.console.args::require_value() {
  [ $# -ge 2 ] || framework.console.args::invalid "$1 needs a value."
}

# <message>, then the command's first usage line as an example, and where
# its full help is.
framework.console.args::invalid() {
  local example=""
  framework.console.output::error "$1"
  ! declare -F usage >/dev/null \
    || example=$(usage 2>/dev/null | awk 'found && NF { sub(/^ +/, ""); print; exit } /^Usage:/ { found = 1 }')
  [ -z "$example" ] || framework.console.output::detail "Usage: $example" >&2
  framework.console.output::next "For more, run: bash dot ${DOT_COMMAND:-} --help" >&2
  exit 1
}

framework.console.args::unexpected() {
  framework.console.args::invalid "Unknown argument: $1"
}

framework.console.args::is_number() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

framework.console.args::split() {
  local value="$1" item
  local items=()
  IFS=',' read -r -a items <<< "$value"
  for item in ${items[@]+"${items[@]}"}; do
    item=$(framework.helpers.text::trim "$item")
    [ -z "$item" ] || printf '%s\n' "$item"
  done
}
