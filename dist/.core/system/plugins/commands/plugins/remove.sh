#!/usr/bin/env bash

DESCRIPTION="Remove a plugin: its files, lock entry, links, and appends; what is left of it is listed for you to review."

dot::use framework.console.args framework.console.output framework.console.prompt core.system.plugins.console core.system.plugins.manifest core.system.plugins.service

usage() {
  cat <<USAGE
bash dot plugins:remove — remove a plugin: $(dot::relative "$PLUGINS_DIR")/<owner>/<name>/,
its lock entry, its entries in the links of $(dot::relative "$SETTINGS_FILE") (active and
inactive), its links, and what it appended (the regions between its markers, in
the files the links append to). The rest is listed for you to review and remove
yourself: the directories it created that still hold records, its settings
(plugins.<owner>/<name> in $(dot::relative "$SETTINGS_FILE")), and its secrets
(DOT_<OWNER>_<NAME>__* in $(dot::relative "$HOST_ENV_FILE")). Empty directories it created are removed.

Needs a y on a terminal (piped input is refused).

Usage:
  bash dot plugins:remove <owner>/<name> [-y, --yes]
  bash dot plugins:remove --help
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
  core.system.plugins.manifest::lock_entry "$plugin" >/dev/null || framework.console.output::fail "$plugin isn't installed." "See what is: bash dot plugins:list"
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
