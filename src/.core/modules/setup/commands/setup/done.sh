# shellcheck shell=bash

DESCRIPTION="Mark what setup left for the agent as finished."
DOCS="getting-started/setup"

hey::use framework.console.args framework.console.output core.modules.setup.service

usage() {
  cat <<EOF
Marks items of what bash hey setup left for the agent (state.setup.pending, also
in bash hey adopt --scan --json) as finished, so they aren't raised again,
even after another setup.

Usage:
  bash hey setup:done <item>...

Arguments:
  <item>       context, split:<path>, unsure:<path>, or verify.

Options:
  -h, --help   Show this help.

Examples:
  bash hey setup:done context
  bash hey setup:done unsure:IDEAS.md split:CLAUDE.md
EOF
}

handle() {
  local item
  [ $# -gt 0 ] || framework.console.args::invalid "Which item is finished?"
  for item in "$@"; do
    case "$item" in
      -*) framework.console.args::unexpected "$item" ;;
      "$SETUP_APPLY_ITEM") framework.console.output::fail_as "$EXIT_NOT_FOUND" "Only bash hey setup can finish $item." "Please run: bash hey setup" ;;
    esac
    core.modules.setup.service::finish "$item" \
      || framework.console.output::fail_as "$EXIT_NOT_FOUND" "$item isn't left for the agent." "See what is: bash hey adopt --scan --json"
    framework.console.output::success "Marked $item as finished."
  done
}
