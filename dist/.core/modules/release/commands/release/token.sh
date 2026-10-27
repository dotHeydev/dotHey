#!/usr/bin/env bash

DESCRIPTION="Save or remove the token a release remote pushes with."

dot::use framework.console.args core.modules.release.console core.modules.release.service framework.console.output framework.console.prompt

usage() {
  cat <<EOF
Asks for a remote's personal access token (never as an argument) and saves it
encrypted for that remote's url: in the macOS keychain, the desktop keyring,
or, without either, gpg-encrypted in $(dot::relative "$HOST_ENV_FILE") with a passphrase you choose.

Usage:
  bash dot release:token <remote> [--remove]

Arguments:
  <remote>     The remote, a key of release.remotes in $(dot::relative "$SETTINGS_FILE").

Options:
  --remove     Remove its saved token instead.
  -h, --help   Show this help.

Examples:
  bash dot release:token github
  bash dot release:token github --remove

Notes:
  - Give the token write access to the release repo, and nothing else.
  - Saving again replaces it; a changed remote url needs a new one.
EOF
}

handle() {
  local name="" remove=false url token
  while [ $# -gt 0 ]; do
    case "$1" in
      --remove) remove=true; shift ;;
      -*) framework.console.args::invalid "Unknown argument: $1" ;;
      *) [ -z "$name" ] || framework.console.args::unexpected "$1"; name="$1"; shift ;;
    esac
  done
  [ -n "$name" ] || framework.console.args::invalid "Which remote? Please give its name from release.remotes."
  cd "$RELEASE_PROJECT" || framework.console.output::fail "Can't open the project at $RELEASE_PROJECT."
  core.modules.release.service::load_remotes
  url=$(core.modules.release.service::remote_url "$name")
  if $remove; then
    core.modules.release.service::remove_token "$url" || framework.console.output::fail "There's no saved token for $name."
    framework.console.output::success "Removed the $name token."
    return 0
  fi
  framework.console.prompt::can_ask || framework.console.output::fail "Tokens are only entered in a terminal." "$OUTPUT_MANUAL_RUN bash dot release:token $name"
  token=$(framework.console.prompt::secret "Token for $name ($url)")
  [ -n "$token" ] || framework.console.output::fail "No token entered, so nothing was saved."
  [ "$(core.modules.release.service::token_store)" != gpg ] \
    || framework.console.output::info "Please choose a passphrase for the $name token, then repeat it; pushes will ask for it."
  core.modules.release.service::save_token "$url" "$token" || framework.console.output::fail "Couldn't save the token for $name."
  token=""
  framework.console.output::success "Saved the $name token in $(core.modules.release.service::token_store)."
}
