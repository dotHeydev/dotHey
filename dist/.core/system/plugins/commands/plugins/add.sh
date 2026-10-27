#!/usr/bin/env bash

DESCRIPTION="Add a plugin from a GitHub repo you trust: its dotdot/ directory, its commands, skills, and context."

dot::use framework.console.args framework.console.output core.system.plugins.console core.system.plugins.manifest

usage() {
  cat <<USAGE
bash dot plugins:add — add a plugin from a GitHub repo, <owner>/<name>.

Only the repo's dotdot/ folder is installed, into
$(dot::relative "$PLUGINS_DIR")/<owner>/<name>/. Its commands run as
bash dot <owner>:<command> (also bare, for an owner the plugins.unprefixedCommandOwners
setting lists). It is refused when its owner is one of dotdot's
own command names or when another plugin has one of its commands; a skill or
agent with the name of dotdot's or another plugin's is only reported, the
first declared linking wherever both go. Its code loads as
plugins.<owner>.<name>.*.

Plugins are not vetted by anyone: you decide whom to trust. Everything the
plugin brings is previewed, scripts flagged, and nothing changes until you
confirm at a terminal. -y, --yes skips the question, but still needs a
terminal, so no agent or script can add a plugin.

Adding creates, links, and appends nothing: dependencies are reported, never
installed, and what it suggests is written into the links of
$(dot::relative "$SETTINGS_FILE") under "inactive", never applied. They are its plugin.json "link" and
"append", plus, for each of its folders no origin there lies in, what
dotdot finds: skills/ and agents/ into .agents/skills/ and .agents/agents/,
context/*.md appended to dotdot's docs, and stubs/*.stub appended to the
project. Take them with bash dot link:activate <owner>/<name>, then run bash dot link.

Private repos need gh logged in, or DOT_GH_TOKEN in $(dot::relative "$HOST_ENV_FILE").

Usage:
  bash dot plugins:add <owner>/<name>[@<version>] [--from <directory>] [-y, --yes]
  bash dot plugins:add --help

The <version> (a branch, tag, or commit) defaults to $PLUGIN_DEFAULT_REF. --from takes a
local copy of the repo inside the project, for developing a plugin: a git
repo of its own is installed as committed at the ref (its current branch by
default), and its commit recorded, as for GitHub; any other folder as it is
on disk.

Examples:
  bash dot plugins:add acme/laravel
  bash dot plugins:add acme/svelte@v1.0.0
USAGE
}

handle() {
  local source="" path="" confirmed=false plugin ref=""
  while [ $# -gt 0 ]; do
    case "$1" in
      -y | --yes) confirmed=true; shift ;;
      --from) framework.console.args::require_value "$@"; path="$2"; shift 2 ;;
      -*) framework.console.args::unexpected "$1" ;;
      *) [ -z "$source" ] || framework.console.args::unexpected "$1"; source="$1"; shift ;;
    esac
  done
  [ -n "$source" ] || framework.console.args::invalid "Which plugin? Please give it as <owner>/<name>."
  [ "${source%@*}" = "$source" ] || ref="${source##*@}"
  plugin=$(core.system.plugins.console::plugin "${source%@*}")
  ! core.system.plugins.manifest::lock_entry "$plugin" >/dev/null \
    || framework.console.output::fail "$plugin is already installed." "To get its latest version: bash dot plugins:update $plugin"
  core.system.plugins.console::fetch "$plugin" "$ref" "$path"
  core.system.plugins.manifest::validate "$PLUGIN_SOURCE" "$plugin" || exit 1
  core.system.plugins.console::warn "$plugin"
  core.system.plugins.console::header "$plugin" "$PLUGIN_ORIGIN${PLUGIN_COMMIT:+ @ ${PLUGIN_COMMIT:0:7}}"
  core.system.plugins.console::preview "$plugin" "$PLUGIN_SOURCE"
  core.system.plugins.console::confirm "Do you want to add $plugin?" "$confirmed" "bash dot plugins:add $source" || exit 1
  core.system.plugins.console::install "$plugin" "$PLUGIN_SOURCE"
  core.system.plugins.console::suggest --refresh-plugin "$plugin"
  core.system.plugins.console::installed "Added $plugin." "$plugin"
}
