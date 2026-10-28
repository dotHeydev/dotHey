#!/usr/bin/env bash

DESCRIPTION="Mark what setup left for the agent as finished."
DOCS="setting-up"

dot::use framework.console.args framework.console.output core.modules.setup.service

usage() {
  cat <<EOF
Marks items of what bash dot setup left for the agent (setup.pending, also
in bash dot adopt --scan --json) as finished, so they aren't raised again,
even after another setup.

Usage:
  bash dot setup:done <item>...

Arguments:
  <item>       context, split:<path>, unsure:<path>, or verify.

Options:
  -h, --help   Show this help.

Examples:
  bash dot setup:done context
  bash dot setup:done unsure:IDEAS.md split:CLAUDE.md
EOF
}

handle() {
  local item
  [ $# -gt 0 ] || framework.console.args::invalid "Which item is finished?"
  for item in "$@"; do
    case "$item" in
      -*) framework.console.args::unexpected "$item" ;;
    esac
    core.modules.setup.service::finish "$item" \
      || framework.console.output::fail_as "$EXIT_NOT_FOUND" "$item isn't left for the agent." "See what is: bash dot adopt --scan --json"
    framework.console.output::success "Marked $item as finished."
  done
}
