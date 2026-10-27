#!/usr/bin/env bash

DESCRIPTION="Take a plugin's suggested links."

dot::use framework.console.args framework.console.output core.system.link.service

usage() {
  cat <<USAGE
Moves a plugin's links from "inactive" into its own active group in
$(dot::relative "$SETTINGS_FILE"), where the next bash dot link applies them. It links nothing
itself.

Usage:
  bash dot link:activate <owner>/<name> [--replace-active]

Arguments:
  <owner>/<name>     The plugin.

Options:
  --replace-active   Replace a group that is already active (after an update,
                     to take its new links).
  -h, --help         Show this help.

Examples:
  bash dot link:activate acme/widgets
  bash dot link:activate acme/widgets --replace-active
USAGE
}

handle() {
  local plugin="" replace=false
  while [ $# -gt 0 ]; do
    case "$1" in
      --replace-active) replace=true ;;
      -*) framework.console.args::unexpected "$1" ;;
      *) [ -z "$plugin" ] || framework.console.args::unexpected "$1"; plugin="$1" ;;
    esac
    shift
  done
  [ -n "$plugin" ] || framework.console.args::invalid "Which plugin? Please give it as <owner>/<name>."
  guards::plugin_id "$plugin" || framework.console.args::invalid "\"$plugin\" isn't a plugin name; please use <owner>/<name>."
  core.system.link.service::move_group "$plugin" active "$replace"
  [ "$LINK_FAILURES" -eq 0 ] || framework.console.output::fail "${LINK_ERRORS[0]}"
  framework.console.output::success "Activated the links of $plugin."
  framework.console.output::next "Apply them: bash dot link"
}
