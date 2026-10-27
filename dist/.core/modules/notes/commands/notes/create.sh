#!/usr/bin/env bash

DESCRIPTION="Create a new, empty note in Notes/ with the next number."

dot::use framework.console.args core.modules.notes.service framework.console.output framework.helpers.text

usage() {
  cat <<EOF
bash dot notes:create — create a new, empty note file in Notes/, numbering
and naming it automatically.

It scans Notes/ for the highest existing number and takes the next one —
which is why the filename and number are never to be constructed by hand.
The file is created empty; write the note into it afterwards.

Usage:
  bash dot notes:create [<name>]
  bash dot notes:create --help

Arguments:
  <name>   Short name for the file, turned into a slug ("Cache idea"
           becomes "cache-idea"). Without one, a random one is picked
           ("swift-otter").

Examples:
  bash dot notes:create
    → Notes/${NOTE_PREFIX}004${RECORD_SEPARATOR}swift-otter.md
  bash dot notes:create "Cache idea"
    → Notes/${NOTE_PREFIX}004${RECORD_SEPARATOR}cache-idea.md
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
  framework.console.output::success "Created note $(framework.helpers.record::number "$(basename -- "$path")")."
  framework.console.output::detail "$(dot::relative "$path")"
}
