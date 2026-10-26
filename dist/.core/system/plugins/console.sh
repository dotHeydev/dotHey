#!/usr/bin/env bash

dot::use framework.console.output framework.console.prompt core.system.plugins.manifest core.system.plugins.service

core.system.plugins.console::plugin() {
  core.system.plugins.manifest::id "$1" || framework.console.output::fail "Give the plugin as <owner>/<name> (letters, digits, and -): $1"
}

core.system.plugins.console::fetch() {
  local plugin="$1" ref="$2" path="${3-}"
  framework.console.output::line "Fetching $plugin${path:+ from $path}${ref:+@$ref}…"
  core.system.plugins.service::fetch "$plugin" "$ref" "$path" || exit 1
}

core.system.plugins.console::warn() {
  framework.console.output::warn "A plugin is code and instructions from $1's author, not from dotdot. It can run anything on this machine and steer your agents."
  framework.console.output::detail "dotdot never runs plugin code while adding it, but its commands, hooks, and skills will run later."
  framework.console.output::detail "Read everything below, and only continue if you trust the source."
}

core.system.plugins.console::preview() {
  local plugin="$1" source="$2" rows kind first second
  rows=$(core.system.plugins.service::preview "$plugin" "$source") || exit 1
  framework.console.output::line "Files → $(dot::relative "$(core.system.plugins.manifest::directory "$plugin")")/:"
  while IFS=$'\t' read -r kind first second; do
    [ "$kind" = file ] || continue
    case "$first" in
      *.sh) framework.console.output::item "$OUTPUT_WARNING_ICON $first" "$second; script: runs on your machine" yellow ;;
      *) framework.console.output::item "$first" "$second" ;;
    esac
  done <<< "$rows"
  while IFS=$'\t' read -r kind first second; do
    case "$kind" in
      missing) framework.console.output::warn "$plugin depends on $first, which is not available here; install it yourself." ;;
    esac
  done <<< "$rows"
  framework.console.output::detail "Nothing is linked or appended: its links go into $(dot::relative "$SETTINGS_FILE") under \"inactive\", for you to activate."
}

core.system.plugins.console::confirm() {
  local question="$1" confirmed="$2" command="$3"
  framework.console.prompt::can_ask || framework.console.output::fail "Plugins are added and updated only by a person at a terminal; ask the user to run $command."
  if $confirmed; then
    framework.console.output::line "$question yes (--yes)"
    return 0
  fi
  framework.console.prompt::confirm "$question" || { framework.console.output::aborted; return 1; }
}

core.system.plugins.console::report() {
  local verb path
  while IFS=$'\t' read -r verb path; do
    case "$verb" in
      left | kept) framework.console.output::item "$path" "$verb; review and remove it yourself if unused" yellow ;;
      *) framework.console.output::item "$path" "$verb" green ;;
    esac
  done
}

core.system.plugins.console::install() {
  local plugin="$1" source="$2" added
  core.system.plugins.service::install "$plugin" "$source" || exit 1
  core.system.plugins.manifest::lock "$plugin" "$PLUGIN_ORIGIN $PLUGIN_REF ${PLUGIN_COMMIT:-$PLUGIN_UNKNOWN_COMMIT}"
  added=$(core.system.plugins.service::register_settings "$plugin") || exit 1
  [ -z "$added" ] || framework.console.output::detail "Its settings were added to $(dot::relative "$SETTINGS_FILE") under plugins[\"$plugin\"], with the defaults from its plugin.json."
}

# Writes the plugins' blocks into the links; links and appends nothing.
core.system.plugins.console::suggest() {
  dot::call link --map-only -y "$@" >/dev/null || framework.console.output::fail "Could not write $(dot::relative "$SETTINGS_FILE"); run bash dot link --map-only."
}

core.system.plugins.console::installed() {
  framework.console.output::success "$1"
  framework.console.output::detail "Review it in $(dot::relative "$(core.system.plugins.manifest::directory "$2")")/, then take its links with bash dot link:activate $2 and run bash dot link."
}
