# shellcheck shell=bash

DESCRIPTION="Save the token a release remote pushes with."
DOCS="releases"

hey::use framework.console.args core.modules.release.console core.modules.release.service framework.console.output framework.console.prompt

usage() {
  cat <<EOF
Asks for a remote's personal access token (never as an argument) and saves it
encrypted for that remote's url: in the macOS keychain, the desktop keyring,
or, without either, gpg-encrypted in $(hey::relative "$HOST_ENV_FILE") with a passphrase you choose.

Usage:
  bash hey release:token <remote>

Arguments:
  <remote>     The remote, a key of release.remotes in $(hey::relative "$SETTINGS_FILE").

Options:
  -h, --help   Show this help.

Examples:
  bash hey release:token github

Notes:
  - Give the token write access to the release repo, and nothing else.
  - Saving again replaces it; a changed remote url needs a new one.
  - bash hey release:token:delete <remote> removes it.
EOF
}

handle() {
  local name="" url token=""
  while [ $# -gt 0 ]; do
    case "$1" in
      -*) framework.console.args::invalid "Unknown argument: $1" ;;
      *) [ -z "$name" ] || framework.console.args::unexpected "$1"; name="$1"; shift ;;
    esac
  done
  [ -n "$name" ] || framework.console.args::invalid "Which remote? Please give its name from release.remotes."
  cd "$RELEASE_PROJECT" || framework.console.output::fail "Can't open the project at $RELEASE_PROJECT."
  core.modules.release.service::load_remotes
  url=$(core.modules.release.service::remote_url "$name")
  framework.console.prompt::can_ask || framework.console.output::fail_as "$EXIT_PRECONDITION" "Tokens are only entered in a terminal." "$OUTPUT_MANUAL_RUN bash hey release:token $name"
  if [ "$(core.modules.release.service::token_store)" = gpg ]; then
    # gpg takes no secret itself, so pinentry asks for the token; gpg then
    # asks for the passphrase on the terminal.
    token=$(framework.console.prompt::pinentry "The token for $name ($url)." "Token:") || framework.console.output::fail "No token entered, so nothing was saved."
    framework.console.output::info "gpg will now ask you to choose a passphrase for the $name token; pushes will ask for it."
  else
    framework.console.output::info "Your system will now ask for the token for $name ($url)."
  fi
  core.modules.release.service::save_token "$url" "$token" || { token=""; framework.console.output::fail "Couldn't save the token for $name."; }
  token=""
  framework.console.output::success "Saved the $name token in $(core.modules.release.service::token_store)."
}
