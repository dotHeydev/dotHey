#!/usr/bin/env bash

DESCRIPTION="Activate a plugin's links: move them from inactive into its own group, for bash dot link to apply."

dot::use framework.console.args framework.console.output core.system.link.service

usage() {
  cat <<USAGE
bash dot link:activate — take a plugin's links: move its group from "inactive"
into "links" in $(dot::relative "$SETTINGS_FILE"), as "<owner>/<name>": {...} right before
"inactive", where the next bash dot link applies them. Nothing is linked or
appended here; bash dot link:deactivate moves them back.

Adding or updating a plugin writes its links under "inactive" only. A group
already active is kept unless --replace-active is given, which replaces it with the
inactive one (after an update, to take its new links).

Usage:
  bash dot link:activate <owner>/<name> [--replace-active]
  bash dot link:activate --help
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
