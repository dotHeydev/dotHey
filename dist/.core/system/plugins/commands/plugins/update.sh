#!/usr/bin/env bash

DESCRIPTION="Update a plugin, after a review."
DOCS="using-plugins"

dot::use framework.console.args framework.console.output core.system.plugins.console core.system.plugins.manifest

usage() {
  cat <<USAGE
Updates a plugin from where it was added, after previewing what changes and
asking. Its new links go under "inactive"; the active ones
stay as they are.

Usage:
  bash dot plugins:update <owner>/<name> [-y, --yes]
  bash dot plugins:update --all [-y, --yes]

Arguments:
  <owner>/<name>   The plugin.

Options:
  --all            Update every installed plugin, each reviewed in turn.
  --preview        Show what it would change, and stop; anyone may run it,
                   agents included. Also --dry-run.
  -y, --yes        Update without asking. It still needs a terminal.
  -h, --help       Show this help.

Examples:
  bash dot plugins:update acme/widgets
  bash dot plugins:update --all
  bash dot plugins:update acme/widgets --preview

Notes:
  - Take the new links: bash dot plugins:link <owner>/<name> --overwrite.
USAGE
}

update_plugin() {
  local plugin="$1" confirmed="$2" entry origin ref commit
  entry=$(core.system.plugins.manifest::lock_entry "$plugin") || framework.console.output::fail_as "$EXIT_NOT_FOUND" "$plugin isn't installed." "See what is: bash dot plugins:list"
  read -r origin ref commit <<< "$entry"
  case "$origin" in
    "$PLUGIN_PATH_SOURCE"*)
      [ "$ref" != "$PLUGIN_LOCAL_REF" ] || ref=""
      core.system.plugins.console::fetch "$plugin" "$ref" "${origin#"$PLUGIN_PATH_SOURCE"}"
      ;;
    *) core.system.plugins.console::fetch "$plugin" "$ref" ;;
  esac
  core.system.plugins.manifest::validate "$PLUGIN_SOURCE" "$plugin" || exit 1
  if [ "$PLUGIN_COMMIT" != "$PLUGIN_LOCAL_REF" ] && [ -n "$PLUGIN_COMMIT" ] && [ "$PLUGIN_COMMIT" = "$commit" ]; then
    framework.console.output::success "$plugin is up to date (${commit:0:7})."
    return 0
  fi
  core.system.plugins.console::warn "$plugin"
  core.system.plugins.console::header "$plugin" "${commit:0:7} → ${PLUGIN_COMMIT:0:7}"
  core.system.plugins.console::preview "$plugin" "$PLUGIN_SOURCE"
  if $PLUGINS_PREVIEW; then
    framework.console.output::next "To update it: bash dot plugins:update $plugin"
    return 0
  fi
  core.system.plugins.console::confirm "Do you want to update $plugin?" "$confirmed" "bash dot plugins:update $plugin" || return 0
  core.system.plugins.console::install "$plugin" "$PLUGIN_SOURCE"
  framework.console.output::success "Updated $plugin."
  PLUGINS_UPDATED=true
  PLUGINS_REFRESH+=(--refresh-plugin "$plugin")
}

handle() {
  local plugin confirmed=false all=false selected=()
  PLUGINS_PREVIEW=false
  while [ $# -gt 0 ]; do
    case "$1" in
      -y | --yes) confirmed=true ;;
      --all) all=true ;;
      --preview | --dry-run) PLUGINS_PREVIEW=true ;;
      -*) framework.console.args::unexpected "$1" ;;
      *) selected+=("$(core.system.plugins.console::plugin "$1")") ;;
    esac
    shift
  done
  [ ${#selected[@]} -le 1 ] || framework.console.args::unexpected "${selected[1]}"
  if $all; then
    [ ${#selected[@]} -eq 0 ] || framework.console.args::invalid "Please give one plugin, or --all, not both."
  else
    [ ${#selected[@]} -eq 1 ] || framework.console.args::invalid "Which plugin? Please give it as <owner>/<name>, or --all for every one."
  fi
  PLUGINS_UPDATED=false
  PLUGINS_REFRESH=()
  if $all; then
    while IFS= read -r plugin; do
      selected+=("$plugin")
    done < <(core.system.plugins.manifest::installed)
  fi
  if [ ${#selected[@]} -eq 0 ]; then
    framework.console.output::line "No plugins installed yet."
    return 0
  fi
  for plugin in "${selected[@]}"; do
    update_plugin "$plugin" "$confirmed"
  done
  $PLUGINS_UPDATED || return 0
  core.system.plugins.console::suggest "${PLUGINS_REFRESH[@]}"
  framework.console.output::next "Take the new links: bash dot plugins:link <owner>/<name> --overwrite"
}
