# shellcheck shell=bash

dot::use framework.helpers.record framework.helpers.text

# A note given no name gets a random <adjective>-<noun> one.
core.modules.notes.service::random_name() {
  framework.helpers.text::random_name
}

core.modules.notes.service::create() {
  local slug="$1" path
  path=$(framework.helpers.record::next_path "$NOTES_DIR" "$NOTE_PREFIX" "$slug") || return 1
  : > "$path" || return 1
  printf '%s\n' "$path"
}
