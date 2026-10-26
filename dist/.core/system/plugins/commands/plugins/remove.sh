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
  bash dot plugins:remove <owner>/<name>
  bash dot plugins:remove --help
USAGE
}

handle() {
  local plugin directory left
  [ $# -ge 1 ] || framework.console.args::invalid "Which plugin? Please give it as <owner>/<name>."
  [ $# -eq 1 ] || framework.console.args::unexpected "$2"
  plugin=$(core.system.plugins.console::plugin "$1")
  core.system.plugins.manifest::lock_entry "$plugin" >/dev/null || framework.console.output::fail "$plugin isn't installed." "See what is: bash dot plugins:list"
  framework.console.prompt::confirm_or_exit "Do you want to remove $plugin and everything it linked?" n "bash dot plugins:remove $plugin"
  directory=$(dot::relative "$(core.system.plugins.manifest::directory "$plugin")")
  left=$(core.system.plugins.service::uninstall "$plugin")
  core.system.plugins.manifest::unlock "$plugin"
  framework.console.output::success "Removed $plugin."
  framework.console.output::entry red "-" "$directory/"
  dot::call link --sweep -y || framework.console.output::fail "Some of $plugin's links or appended sections couldn't be removed (see above)." "Please finish with: bash dot link"
  framework.console.output::newline
  if [ -n "$left" ]; then
    framework.console.output::warn "Left for you to review:"
    core.system.plugins.console::report <<< "$left"
  fi
  framework.console.output::detail "Please also review anything else it created (its records, say) and remove what is unused."
}
