#!/usr/bin/env bash

DESCRIPTION="Remove the token a release remote pushes with."
DOCS="releases"

dot::use framework.console.args core.modules.release.service framework.console.output

usage() {
  cat <<EOF
Removes the token saved for a remote's url by bash dot release:token.

Usage:
  bash dot release:token:delete <remote>

Arguments:
  <remote>     The remote, a key of release.remotes in $(dot::relative "$SETTINGS_FILE").

Options:
  -h, --help   Show this help.

Examples:
  bash dot release:token:delete github
EOF
}

handle() {
  local name="" url
  while [ $# -gt 0 ]; do
    case "$1" in
      -*) framework.console.args::unexpected "$1" ;;
      *) [ -z "$name" ] || framework.console.args::unexpected "$1"; name="$1"; shift ;;
    esac
  done
  [ -n "$name" ] || framework.console.args::invalid "Which remote? Please give its name from release.remotes."
  cd "$RELEASE_PROJECT" || framework.console.output::fail "Can't open the project at $RELEASE_PROJECT."
  core.modules.release.service::load_remotes
  url=$(core.modules.release.service::remote_url "$name")
  core.modules.release.service::remove_token "$url" || framework.console.output::fail_as "$EXIT_NOT_FOUND" "There's no saved token for $name."
  framework.console.output::success "Removed the $name token."
}
