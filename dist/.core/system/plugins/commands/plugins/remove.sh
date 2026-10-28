#!/usr/bin/env bash

DESCRIPTION="Remove a plugin and everything it linked."
DOCS="using-plugins"

dot::use framework.console.args framework.console.output framework.console.prompt core.system.plugins.console core.system.plugins.manifest core.system.plugins.service

usage() {
  cat <<USAGE
Removes the plugin's files and lock entry, its links in $(dot::relative "$SETTINGS_FILE"),
everything it linked, and the sections it appended. Its settings, secrets and
records are listed for you to review.

Usage:
  bash dot plugins:remove <owner>/<name> [-y, --yes]

Arguments:
  <owner>/<name>   The plugin.

Options:
  -y, --yes        Remove without asking. It still needs a terminal.
  -h, --help       Show this help.

Examples:
  bash dot plugins:remove acme/widgets
USAGE
}

handle() {
  local plugin="" directory left confirmed=false
  while [ $# -gt 0 ]; do
    case "$1" in
      -y | --yes) confirmed=true ;;
      -*) framework.console.args::unexpected "$1" ;;
      *) [ -z "$plugin" ] || framework.console.args::unexpected "$1"; plugin="$1" ;;
    esac
    shift
  done
  [ -n "$plugin" ] || framework.console.args::invalid "Which plugin? Please give it as <owner>/<name>."
  plugin=$(core.system.plugins.console::plugin "$plugin")
  core.system.plugins.manifest::lock_entry "$plugin" >/dev/null || framework.console.output::fail_as "$EXIT_NOT_FOUND" "$plugin isn't installed." "See what is: bash dot plugins:list"
  core.system.plugins.console::confirm "Do you want to remove $plugin and everything it linked?" "$confirmed" "bash dot plugins:remove $plugin" || exit 1
  directory=$(dot::relative "$(core.system.plugins.manifest::directory "$plugin")")
  left=$(core.system.plugins.service::uninstall "$plugin")
  core.system.plugins.manifest::unlock "$plugin"
  framework.console.output::success "Removed $plugin."
  framework.console.output::entry red "-" "$directory/"
  dot::call link --remove-uninstalled -y || framework.console.output::fail "Some of $plugin's links or appended sections couldn't be removed (see above)." "Please finish with: bash dot link"
  framework.console.output::newline
  if [ -n "$left" ]; then
    framework.console.output::warn "Left for you to review:"
    core.system.plugins.console::report <<< "$left"
  fi
  framework.console.output::detail "Please also review anything else it created (its records, say) and remove what is unused."
}
