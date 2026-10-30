# shellcheck shell=bash

dot::use framework.console.output framework.helpers.text

framework.console.args::require_value() {
  [ $# -ge 2 ] || framework.console.args::invalid "$1 needs a value."
}

# <message>, then the command's first usage line as an example, and where
# its full help is; exits EXIT_USAGE.
framework.console.args::invalid() {
  local example="" help="For more, run: bash dot ${DOT_COMMAND:-} --help"
  ! declare -F usage >/dev/null \
    || example=$(usage 2>/dev/null | awk 'found && NF { sub(/^ +/, ""); print; exit } /^Usage:/ { found = 1 }')
  if [ "${DOT_JSON-}" = true ]; then
    framework.console.output::json_error "$EXIT_USAGE" "$1" "$help" ${example:+"Usage: $example"}
  else
    framework.console.output::error "$1"
    [ -z "$example" ] || framework.console.output::detail "Usage: $example" >&2
    framework.console.output::next "$help" >&2
  fi
  exit "$EXIT_USAGE"
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
