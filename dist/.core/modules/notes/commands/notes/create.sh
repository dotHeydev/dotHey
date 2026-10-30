# shellcheck shell=bash

DESCRIPTION="Create a new, numbered note."
DOCS="notes"
JSON=true

hey::use framework.console.args core.modules.notes.service framework.console.output framework.helpers.text

usage() {
  cat <<EOF
Creates the next numbered, empty note in Notes/; write the note into it
afterwards.

Usage:
  bash hey notes:create [<name>]

Arguments:
  <name>       A short name for the file ("Cache idea" becomes cache-idea).
               Without one, it gets a random one, like swift-otter.

Options:
  --json       Print {"id", "path"}.
  -h, --help   Show this help.

Examples:
  bash hey notes:create "Cache idea"
  bash hey notes:create
EOF
}

handle() {
  local name slug path
  case "${1-}" in
    -*) framework.console.args::unexpected "$1" ;;
  esac
  [ $# -le 1 ] || framework.console.args::unexpected "$2"
  name="${1:-$(core.modules.notes.service::random_name)}"
  slug=$(framework.helpers.text::slug "$name")
  [ -n "$slug" ] || framework.console.args::invalid "The name needs at least one letter or digit."
  path=$(core.modules.notes.service::create "$slug") || framework.console.output::fail "Couldn't create the note; please try again."
  framework.console.output::created "Created note $(framework.helpers.record::number "$(basename -- "$path")")." "$(basename -- "$path" .md)" "$(hey::relative "$path")"
}
