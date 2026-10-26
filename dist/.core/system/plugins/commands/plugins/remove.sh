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
  local plugin
  [ $# -ge 1 ] || framework.console.args::invalid "A plugin is required, as <owner>/<name>."
  [ $# -eq 1 ] || framework.console.args::unexpected "$2"
  plugin=$(core.system.plugins.console::plugin "$1")
  core.system.plugins.manifest::lock_entry "$plugin" >/dev/null || framework.console.output::fail "$plugin is not installed."
  framework.console.prompt::confirm_or_exit "Remove $plugin?" n "bash dot plugins:remove $plugin"
  core.system.plugins.service::uninstall "$plugin" | core.system.plugins.console::report
  core.system.plugins.manifest::unlock "$plugin"
  dot::call link --sweep -y || framework.console.output::fail "Could not take back all of $plugin's links and appends; run bash dot link."
  framework.console.output::success "Removed $plugin."
  framework.console.output::detail "Review what is left of it yourself, and remove what is unused."
}
