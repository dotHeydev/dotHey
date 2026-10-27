#!/usr/bin/env bash

DESCRIPTION="Make a signed release commit in the release repo."

dot::use framework.console.args core.modules.release.console core.modules.release.service framework.console.output framework.console.prompt

usage() {
  cat <<EOF
Exports every file committed in HEAD, minus release.exclude, into the release
repo as one signed commit tagged v<version>; then asks, remote by remote,
whether to push. It runs no build or tests: do those first.

Usage:
  bash dot release:create <version> [--push <remote>]... [--push-all] [options]

Arguments:
  <version>                 A semantic version, like 1.2.0 or 1.2.0-rc.1.

Options:
  --push <remote>           Push to that remote without asking; repeatable or
                            comma-separated. Names are release.remotes' keys.
  --push-all                Push to every remote without asking.
  --keep-tokens <minutes>   Keep the unlocked tokens that many minutes, so
                            pushes until then don't ask for the passphrase
                            (0 forgets them).
  -f, --force               Force-push, replacing the remotes' history. Asks
                            first, and only at a terminal.
  -h, --help                Show this help.

Examples:
  bash dot release:create 1.2.0
  bash dot release:create 1.2.0 --push github
  bash dot release:create 1.2.0 --push-all --keep-tokens 15

Settings (in $(dot::relative "$SETTINGS_FILE"); any may be "@env:<KEY>"):
  release.destination   The release repo's directory, from the project root.
  release.exclude       Paths left out; "!<path>" ships a git-ignored one.
  release.branch        The release repo's branch.
  release.remotes       {"<name>": "<https url>"}, at least one.
  release.signingKey    The private SSH key's file name in ~/.ssh/.
  release.authorName    The name on release commits.
  release.authorEmail   The email on release commits; GitHub only shows
                        "Verified" when the signing key's account owns it.

Notes:
  - It stops on uncommitted changes in what it ships, a key that doesn't match,
    anything that looks like a secret, or a --push remote with no token.
  - The project's .env never ships. Tokens: bash dot release:token <remote>.
EOF
}

handle() {
  local version="" tag branch
  while [ $# -gt 0 ]; do
    if core.modules.release.console::parse_push_option "$@"; then
      shift "$RELEASE_TAKEN"
      continue
    fi
    case "$1" in
      --push) framework.console.args::require_value "$@"; core.modules.release.console::add_remotes "$2"; shift 2 ;;
      --push-all) RELEASE_PUSH_ALL=true; shift ;;
      -*) framework.console.args::unexpected "$1" ;;
      *) [ -z "$version" ] || framework.console.args::unexpected "$1"; version="$1"; shift ;;
    esac
  done
  [ -n "$version" ] || framework.console.args::invalid "Which version? Please give one like 1.2.0."
  [[ "$version" =~ $RELEASE_VERSION_PATTERN ]] || framework.console.args::invalid "\"$version\" isn't a version like 1.2.0."
  tag="v$version"
  ! $RELEASE_FORCE || framework.console.prompt::confirm_or_exit "Force-pushing replaces the remotes' history. Do you want to force-push $tag?" n "bash dot release:create $version --force"
  cd "$RELEASE_PROJECT" || framework.console.output::fail "Can't open the project at $RELEASE_PROJECT."
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || framework.console.output::fail "$RELEASE_PROJECT isn't a git repository."
  RELEASE_DESTINATION=$(dot::setting release.destination)
  branch=$(dot::setting release.branch)
  RELEASE_SIGNING_NAME=$(dot::setting release.signingKey)
  RELEASE_AUTHOR_NAME=$(dot::setting release.authorName)
  RELEASE_AUTHOR_EMAIL=$(dot::setting release.authorEmail)
  git check-ref-format --branch "$branch" >/dev/null 2>&1 || framework.console.output::fail "release.branch \"$branch\" isn't a valid branch name."
  core.modules.release.service::check_signing_identity
  core.modules.release.service::load_remotes
  core.modules.release.service::check_push_targets
  core.modules.release.service::check_tokens
  core.modules.release.service::read_exclusions
  core.modules.release.service::ships_clean || framework.console.output::fail "Some files in the release have uncommitted changes." "Please commit or stash them, then try again."
  core.modules.release.console::print_warnings
  core.modules.release.service::prepare_repository "$branch" "$tag"
  core.modules.release.service::configure_signing
  framework.console.output::title "🔏 Signing — please enter your signing key's passphrase"
  core.modules.release.service::start_agent
  framework.console.output::title "📦 Exporting the release…"
  core.modules.release.service::export
  core.modules.release.service::scan_secrets
  core.modules.release.service::commit "$tag"
  core.modules.release.service::stop_agent
  framework.console.output::newline
  framework.console.output::success "Release $tag committed and signed."
  framework.console.output::detail "$(dot::relative "$RELEASE_DESTINATION")"
  core.modules.release.console::push "$branch" "$tag"
}
