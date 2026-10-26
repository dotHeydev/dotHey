#!/usr/bin/env bash

dot::use framework.console.output framework.console.prompt core.system.plugins.manifest core.system.plugins.service

core.system.plugins.console::plugin() {
  core.system.plugins.manifest::id "$1" || framework.console.output::fail "\"$1\" isn't a plugin name; please use <owner>/<name> (letters, digits and -)."
}

core.system.plugins.console::fetch() {
  local plugin="$1" ref="$2" path="${3-}"
  framework.console.output::line "Fetching $plugin${path:+ from $path}${ref:+@$ref}…"
  core.system.plugins.service::fetch "$plugin" "$ref" "$path" || exit 1
}

core.system.plugins.console::warn() {
  framework.console.output::newline
  framework.console.output::warn "Plugins are code from their author, not from dotdot."
  framework.console.output::detail "Once added, $1's commands, hooks and skills can run anything"
  framework.console.output::detail "on this machine and steer your agents. Please only continue"
  framework.console.output::detail "if you trust the source."
  framework.console.output::newline
}

# A plugin as previewed: its id in bold, then where it comes from.
core.system.plugins.console::header() {
  local detail="${2% @ -}"
  framework.console.output::line "$(framework.console.output::paint bold "$1") $OUTPUT_SEPARATOR $detail"
}

core.system.plugins.console::preview() {
  local plugin="$1" source="$2" rows kind first second
  rows=$(core.system.plugins.service::preview "$plugin" "$source") || exit 1
  framework.console.output::detail "Into $(dot::relative "$(core.system.plugins.manifest::directory "$plugin")")/:"
  while IFS=$'\t' read -r kind first second; do
    [ "$kind" = file ] || continue
    case "$first" in
      *.sh) framework.console.output::change "$second" "$first $(framework.console.output::paint yellow "$OUTPUT_WARNING_ICON script, runs on your machine")" ;;
      *) framework.console.output::change "$second" "$first" ;;
    esac
  done <<< "$rows"
  while IFS=$'\t' read -r kind first second; do
    case "$kind" in
      missing) framework.console.output::warn "$plugin needs $first, which isn't installed here; please install it." ;;
    esac
  done <<< "$rows"
  framework.console.output::detail "Nothing gets linked yet; its links wait in $(dot::relative "$SETTINGS_FILE") under \"inactive\"."
}

core.system.plugins.console::confirm() {
  local question="$1" confirmed="$2" command="$3"
  framework.console.prompt::can_ask || framework.console.output::fail "Plugins can only be added or updated by you, in a terminal." "$OUTPUT_MANUAL_RUN $command"
  if $confirmed; then
    framework.console.prompt::answered "$question" "yes (--yes)"
    return 0
  fi
  framework.console.prompt::confirm "$question" || { framework.console.output::aborted; return 1; }
}

# What a removed plugin left behind, under a heading, when it left anything.
core.system.plugins.console::report() {
  local verb path note
  while IFS=$'\t' read -r verb path note; do
    [ -n "$verb" ] || continue
    framework.console.output::entry yellow "$OUTPUT_WARNING_ICON" "$path" "$note"
  done
}

core.system.plugins.console::install() {
  local plugin="$1" source="$2" added
  core.system.plugins.service::install "$plugin" "$source" || exit 1
  core.system.plugins.manifest::lock "$plugin" "$PLUGIN_ORIGIN $PLUGIN_REF ${PLUGIN_COMMIT:-$PLUGIN_UNKNOWN_COMMIT}"
  added=$(core.system.plugins.service::register_settings "$plugin") || exit 1
  [ -z "$added" ] || framework.console.output::detail "Its settings are in $(dot::relative "$SETTINGS_FILE") under plugins[\"$plugin\"], with their defaults."
}

# Writes the plugins' blocks into the links; links and appends nothing.
core.system.plugins.console::suggest() {
  dot::call link --map-only -y "$@" >/dev/null || framework.console.output::fail "Couldn't write the plugin's links to $(dot::relative "$SETTINGS_FILE")." "Please try again with: bash dot link --map-only"
}

core.system.plugins.console::installed() {
  framework.console.output::success "$1"
  framework.console.output::next "Next: bash dot link:activate $2, then bash dot link"
}
