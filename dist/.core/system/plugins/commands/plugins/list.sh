# shellcheck shell=bash

DESCRIPTION="List the installed plugins."
DOCS="configuration/plugins"
JSON=true

hey::use framework.console.args framework.console.output core.system.plugins.manifest framework.helpers.json

usage() {
  cat <<USAGE
Lists each installed plugin with its source, version and commit.

Usage:
  bash hey plugins:list [--json]

Options:
  --json       [{"name", "origin", "ref", "commit"}].
  -h, --help   Show this help.
USAGE
}

handle() {
  local plugin origin ref commit found=false rows=""
  [ $# -eq 0 ] || framework.console.args::unexpected "$1"
  while IFS= read -r plugin; do
    found=true
    read -r origin ref commit _ <<< "$(core.system.plugins.manifest::lock_entry "$plugin")"
    if $HEY_JSON; then
      rows="$rows${rows:+,}{\"name\":$(framework.helpers.json::string "$plugin"),\"origin\":$(framework.helpers.json::string "$origin"),\"ref\":$(framework.helpers.json::string "$ref"),\"commit\":$(framework.helpers.json::string "$commit")}"
    else
      framework.console.output::line "  $plugin  $origin  $ref@${commit:0:7}"
    fi
  done < <(core.system.plugins.manifest::installed)
  if $HEY_JSON; then
    printf '[%s]\n' "$rows"
  else
    $found || framework.console.output::line "No plugins installed yet."
  fi
}
