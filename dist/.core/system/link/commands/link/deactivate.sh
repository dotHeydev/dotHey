#!/usr/bin/env bash

DESCRIPTION="Set a plugin's links aside."

dot::use framework.console.args framework.console.output core.system.link.service

usage() {
  cat <<USAGE
Moves a plugin's active links back under "inactive" in $(dot::relative "$SETTINGS_FILE"),
so linking no longer applies them. What they already linked stays until
you remove it.

Usage:
  bash dot link:deactivate <owner>/<name> [--replace-inactive]

Arguments:
  <owner>/<name>       The plugin.

Options:
  --replace-inactive   Replace the inactive links already there.
  -h, --help           Show this help.

Examples:
  bash dot link:deactivate acme/widgets

Notes:
  - Remove what they linked with bash dot link, once a "remove" entry lists it.
USAGE
}

handle() {
  local plugin="" replace=false
  while [ $# -gt 0 ]; do
    case "$1" in
      --replace-inactive) replace=true ;;
      -*) framework.console.args::unexpected "$1" ;;
      *) [ -z "$plugin" ] || framework.console.args::unexpected "$1"; plugin="$1" ;;
    esac
    shift
  done
  [ -n "$plugin" ] || framework.console.args::invalid "Which plugin? Please give it as <owner>/<name>."
  guards::plugin_id "$plugin" || framework.console.args::invalid "\"$plugin\" isn't a plugin name; please use <owner>/<name>."
  core.system.link.service::move_group "$plugin" inactive "$replace"
  if [ "$LINK_FAILURES" -gt 0 ]; then
    if [ "${LINK_ERRORS[0]#*$LINK_TAB}" != "${LINK_ERRORS[0]}" ]; then
      framework.console.output::fail "${LINK_ERRORS[0]%%$LINK_TAB*}" "${LINK_ERRORS[0]#*$LINK_TAB}"
    fi
    framework.console.output::fail "${LINK_ERRORS[0]}"
  fi
  framework.console.output::success "Deactivated the links of $plugin."
  framework.console.output::detail "What it already linked stays until you remove it."
}
