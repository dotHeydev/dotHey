#!/usr/bin/env bash

DESCRIPTION="List the installed plugins."

dot::use framework.console.args framework.console.output core.system.plugins.manifest

usage() {
  cat <<USAGE
Lists each installed plugin with its source, version and commit.

Usage:
  bash dot plugins:list

Options:
  -h, --help   Show this help.
USAGE
}

handle() {
  local plugin origin ref commit found=false
  [ $# -eq 0 ] || framework.console.args::unexpected "$1"
  while IFS= read -r plugin; do
    found=true
    read -r origin ref commit <<< "$(core.system.plugins.manifest::lock_entry "$plugin")"
    framework.console.output::line "  $plugin  $origin  $ref@${commit:0:7}"
  done < <(core.system.plugins.manifest::installed)
  $found || framework.console.output::line "No plugins installed yet."
}
