#!/usr/bin/env bash

DESCRIPTION="Deactivate a plugin's links: move its group back under inactive, so bash dot link no longer applies them."

dot::use framework.console.args framework.console.output core.system.link.service

usage() {
  cat <<USAGE
bash dot link:deactivate — the opposite of link:activate: move a plugin's
group from "links" back to the end of "inactive" in $(dot::relative "$SETTINGS_FILE"), where
bash dot link no longer applies it. Nothing is unlinked here: what it linked
stays until you remove it ("remove") or it breaks and the next run prunes it.

Inactive links already there are kept unless --replace is given, which
replaces them with the active group.

Usage:
  bash dot link:deactivate <owner>/<name> [--replace]
  bash dot link:deactivate --help
USAGE
}

handle() {
  local plugin="" replace=false
  while [ $# -gt 0 ]; do
    case "$1" in
      --replace) replace=true ;;
      -*) framework.console.args::unexpected "$1" ;;
      *) [ -z "$plugin" ] || framework.console.args::unexpected "$1"; plugin="$1" ;;
    esac
    shift
  done
  [ -n "$plugin" ] || framework.console.args::invalid "A plugin is required, as <owner>/<name>."
  guards::plugin_id "$plugin" || framework.console.args::invalid "A plugin is <owner>/<name>: $plugin"
  core.system.link.service::move_group "$plugin" inactive "$replace"
  [ "$LINK_FAILURES" -eq 0 ] || framework.console.output::fail "${LINK_ERRORS[0]}"
  framework.console.output::success "Deactivated $plugin's links in $(dot::relative "$SETTINGS_FILE")."
}
