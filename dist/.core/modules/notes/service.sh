#!/usr/bin/env bash

dot::use framework.helpers.record framework.helpers.text

# A note given no name gets a random <adjective>-<noun> one.
NOTE_ADJECTIVES=(amber bold brisk calm clever cosmic crisp curious daring eager gentle golden happy hidden humble jolly keen lively lucky mellow merry nimble noble plucky quiet rapid rustic shiny silent snappy steady sunny swift tidy vivid witty)
NOTE_NOUNS=(acorn anchor badger beacon breeze canyon comet compass falcon fern harbor heron island lantern maple meadow meteor otter pebble pine quartz raven ripple river sparrow spark summit thistle tide walnut willow zephyr)

core.modules.notes.service::random_name() {
  printf '%s-%s\n' "${NOTE_ADJECTIVES[RANDOM % ${#NOTE_ADJECTIVES[@]}]}" "${NOTE_NOUNS[RANDOM % ${#NOTE_NOUNS[@]}]}"
}

core.modules.notes.service::create() {
  local slug="$1" path
  path=$(framework.helpers.record::next_path "$NOTES_DIR" "$NOTE_PREFIX" "$slug") || return 1
  : > "$path" || return 1
  printf '%s\n' "$path"
}
