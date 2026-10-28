#!/usr/bin/env bash

dot::use core.modules.setup.service framework.console.output

# A warning for each harness whose data couldn't be read.
core.modules.setup.console::warn_invalid() {
  local id
  for id in ${SETUP_INVALID[@]+"${SETUP_INVALID[@]}"}; do
    framework.console.output::warn "Skipped the harness $id: its harness.json isn't valid JSON naming the harness."
  done
}

# What the scan found, by harness, from its rows.
core.modules.setup.console::found() {
  local rows="$1" id kind path previous=""
  if [ -z "$rows" ]; then
    framework.console.output::line "Found nothing of a harness's in the project."
    return
  fi
  framework.console.output::line "Found:"
  while IFS="$SETUP_TAB" read -r id kind path _; do
    [ "$id" = "$previous" ] || framework.console.output::item "$(framework.console.output::bold "$([ "$id" != "$SETUP_NO_HARNESS" ] && core.harnesses.harness::data "$id" .name || printf 'Not a harness'"'"'s')")"
    previous="$id"
    framework.console.output::entry gray "·" "$path" "$kind"
  done <<< "$rows"
}

# The moves own makes, and what it leaves in place.
core.modules.setup.console::moves() {
  local move skipped to
  for move in ${SETUP_MOVES[@]+"${SETUP_MOVES[@]}"}; do
    to="${move#*"$SETUP_TAB"}"
    framework.console.output::entry yellow "~" "${move%%"$SETUP_TAB"*} → $DOTDOT_NAME/${to%%"$SETUP_TAB"*}" "moved, and linked back"
  done
  for skipped in ${SETUP_SKIPPED[@]+"${SETUP_SKIPPED[@]}"}; do
    framework.console.output::entry yellow "!" "${skipped%%"$SETUP_TAB"*}" "left in place: ${skipped#*"$SETUP_TAB"}"
  done
  [ ${#SETUP_MOVES[@]} -eq 0 ] || framework.console.output::info "Moved files are edited in $DOTDOT_NAME/ from now on; the harnesses read them through the links."
}

# What is left for the agent, and how it picks it up.
core.modules.setup.console::pending() {
  local item
  if [ -z "$1" ]; then
    framework.console.output::info "Nothing is left for your agent: dotdot is set up and ready."
    return
  fi
  framework.console.output::line "Left for your agent:"
  while IFS= read -r item; do
    case "$item" in
      context) framework.console.output::entry blue "→" "write the project's context in $DOTDOT_NAME/" ;;
      split:*) framework.console.output::entry blue "→" "${item#split:}" "propose where each part belongs in dotdot's docs" ;;
      unsure:*) framework.console.output::entry blue "→" "${item#unsure:}" "ask you whether it belongs to the project's context" ;;
      verify) framework.console.output::entry blue "→" "check that every harness reads what moved" ;;
    esac
  done <<< "$1"
  framework.console.output::next "Your agent picks this up at its next session; or tell it now: \"set up dotdot\"."
}
