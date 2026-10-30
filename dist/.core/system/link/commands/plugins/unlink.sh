# shellcheck shell=bash

DESCRIPTION="Take back a plugin's links, and set them aside."
DOCS="configuration/plugins"

hey::use core.system.link.console

usage() {
  cat <<EOF
Takes back what a plugin's active links linked and appended — only those —
after previewing it and asking, then moves its links under "inactive" in
$(hey::relative "$SETTINGS_FILE"). With no one at a terminal to ask, it only previews.

Usage:
  bash hey plugins:unlink <owner>/<name> [--overwrite] [--preview] [-y, --yes]

Arguments:
  <owner>/<name>       The plugin.

Options:
  --overwrite          Replace the links already waiting under "inactive". Also
                       --force.
  --preview            Show the changes, and stop. Also --dry-run.
  -y, --yes            Apply without asking. Only at a terminal.
  -h, --help           Show this help.

Examples:
  bash hey plugins:unlink acme/widgets
  bash hey plugins:unlink acme/widgets --preview
EOF
}

handle() {
  core.system.link.console::plugin_links unlink "$@"
}
