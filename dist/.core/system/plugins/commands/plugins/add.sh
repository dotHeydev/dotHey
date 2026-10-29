#!/usr/bin/env bash

DESCRIPTION="Add a plugin from a GitHub repo you trust."
DOCS="using-plugins"

dot::use framework.console.args framework.console.output core.system.plugins.console core.system.plugins.manifest

usage() {
  cat <<USAGE
Installs the repo's $PLUGIN_ROOT/ directory into $(dot::relative "$PLUGINS_DIR")/<owner>/<name>/,
after previewing every file and asking. Nothing gets linked: its links wait
in $(dot::relative "$SETTINGS_FILE") under "inactive" until you take them.

Usage:
  bash dot plugins:add <owner>/<name>[@<version>] [options]
  bash dot plugins:add <GitHub URL> [options]

Arguments:
  <owner>/<name>       The plugin's GitHub repo, as GitHub names it; dotdot
                       knows it by that name in lowercase, . and _ as -.
  @<version>           A branch, tag or commit (default: $PLUGIN_DEFAULT_REF).
  <GitHub URL>         The repo's address: https://github.com/<owner>/<name>,
                       .../tree/<version>, .../commit/<sha>, or its git@ form.

Options:
  --from <directory>   Install from a local copy inside the project, to develop
                       a plugin: as committed when it's a git repo, else as is.
  --preview            Show what it would add, and stop; anyone may run it,
                       agents included. Also --dry-run.
  -y, --yes            Add without asking. It still needs a terminal.
  -h, --help           Show this help.

Examples:
  bash dot plugins:add acme/laravel
  bash dot plugins:add https://github.com/acme/laravel/tree/v2
  bash dot plugins:add acme/svelte@v1.0.0 --preview
  bash dot plugins:add acme/widgets --from ./widgets

Notes:
  - Plugins aren't vetted by anyone: only add one whose source you trust.
  - Its commands run as bash dot <owner>:<command>. A plugin whose owner is a
    dotdot command name, or whose commands are taken, is refused.
  - Private repos need gh signed in, or DOT_GH_TOKEN in $(dot::relative "$HOST_ENV_FILE").
  - Adding links nothing: its links wait under "inactive" in the links.
    Only the user takes them (bash dot plugins:link <owner>/<name>, which
    --preview shows first); never take them on their behalf.
  - Next: bash dot plugins:link <owner>/<name>.
USAGE
}

handle() {
  local source="" path="" confirmed=false preview=false plugin ref=""
  while [ $# -gt 0 ]; do
    case "$1" in
      -y | --yes) confirmed=true; shift ;;
      --preview | --dry-run) preview=true; shift ;;
      --from) framework.console.args::require_value "$@"; path="$2"; shift 2 ;;
      -*) framework.console.args::unexpected "$1" ;;
      *) [ -z "$source" ] || framework.console.args::unexpected "$1"; source="$1"; shift ;;
    esac
  done
  [ -n "$source" ] || framework.console.args::invalid "Which plugin? Please give it as <owner>/<name>."
  plugin=$(core.system.plugins.console::plugin "$source")
  core.system.plugins.manifest::parse "$source"
  ref="$PLUGIN_SPEC_REF"
  core.system.plugins.manifest::choose_place "$plugin"
  ! core.system.plugins.manifest::lock_entry "$plugin" >/dev/null \
    || framework.console.output::fail "$plugin is already installed." "To get its latest version: bash dot plugins:update $plugin"
  core.system.plugins.console::fetch "$plugin" "$ref" "$path" "$PLUGIN_REPOSITORY"
  core.system.plugins.manifest::validate "$PLUGIN_SOURCE" "$plugin" || exit 1
  core.system.plugins.console::warn "$plugin"
  core.system.plugins.console::header "$plugin" "$PLUGIN_ORIGIN${PLUGIN_COMMIT:+ @ ${PLUGIN_COMMIT:0:7}}"
  core.system.plugins.console::preview "$plugin" "$PLUGIN_SOURCE"
  ! $preview || core.system.plugins.console::previewed "bash dot plugins:add $source${path:+ --from $path}"
  core.system.plugins.console::confirm "Do you want to add $plugin?" "$confirmed" "bash dot plugins:add $source" || exit 1
  core.system.plugins.console::install "$plugin" "$PLUGIN_SOURCE"
  core.system.plugins.console::suggest --refresh-plugin "$plugin"
  core.system.plugins.console::installed "Added $plugin." "$plugin"
}
