# shellcheck shell=bash

DESCRIPTION="Link a plugin's waiting links, and make them active."
DOCS="using-plugins"

hey::use core.system.link.console

usage() {
  cat <<EOF
Applies a plugin's links waiting under "inactive" in $(hey::relative "$SETTINGS_FILE") — only
those — after previewing them and asking, then moves them to active.
With no one at a terminal to ask, it only previews.

Usage:
  bash hey plugins:link <owner>/<name> [--overwrite] [--preview] [-y, --yes]

Arguments:
  <owner>/<name>       The plugin.

Options:
  --overwrite          Take new links over active ones (after a plugin update),
                       and replace destinations that already exist. Also
                       --force.
  --preview            Show the changes, and stop. Also --dry-run.
  -y, --yes            Apply without asking. Only at a terminal.
  -h, --help           Show this help.

Examples:
  bash hey plugins:link acme/widgets
  bash hey plugins:link acme/widgets --overwrite
EOF
}

handle() {
  core.system.link.console::plugin_links link "$@"
}
