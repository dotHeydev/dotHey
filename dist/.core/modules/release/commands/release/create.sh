#!/usr/bin/env bash

DESCRIPTION="Export the project minus an exclude list and make a signed release commit in a separate repo."

dot::use framework.console.args core.modules.release.console core.modules.release.service framework.console.output framework.console.prompt

usage() {
  cat <<EOF
bash dot release:create — prepare one signed release commit, tagged v<version>, in
a separate release repo, so the public history holds release commits and
nothing else.

Every file tracked in HEAD is exported except the paths release.exclude
lists. Git-ignored files are left out, unless the list names one with a
leading "!" (a build you made, e.g. !dist): that one is copied from disk.
The project's .env never ships.
It runs no project commands (no build, test, or install), so it works the
same for any project: build and test in your own workflow first. It refuses on
uncommitted changes in what it ships (changes elsewhere don't count), a missing or mismatched signing key, anything that looks like a
secret, or a remote a flag names that has no token stored. Then it asks,
remote by remote, whether to push (default no); without a terminal it pushes
only where a flag says so. bash dot release:push pushes the same way later.
Each remote is pushed over https with its own personal access token, stored
encrypted with bash dot release:token <remote>.

Usage:
  bash dot release:create <version> [--<remote>...] [--push-all] [--cache-pat=N] [--force]
  bash dot release:create --help

Arguments:
  <version>   Semantic version, e.g. 1.2.0 or 1.2.0-rc.1.

Optional:
  --<remote>  Push to that remote without asking, e.g. --github. Repeatable.
              Remote names are the keys of release.remotes.
  --push-all  Push to every configured remote without asking.
  --force     Force push, overwriting the remotes' branch and tags. Asks
              first ([y/N]: only y or yes goes ahead), and only at a terminal.
  --cache-pat=N
              Keep the decrypted tokens in memory for N minutes from now, so
              pushes until then ask no passphrase; given again, the N minutes
              restart. 0 forgets them. By default nothing is kept.

Settings, from $(dot::relative "$SETTINGS_FILE") (over dotdot's defaults); any value may be
"@env:<KEY>" to read it from $(dot::relative "$HOST_ENV_FILE"):
  release.destination  release repo directory, from the project root
  release.exclude      paths left out, from the project root; "!path" includes a
                       git-ignored path (from .env, a JSON list)
  release.branch       branch in the release repo
  release.remotes      {<name>: <https url>}, at least one
  release.signingKey   private SSH key file name in \$HOME/.ssh/; its .pub sits next to it
  release.authorName   name on the release commits
  release.authorEmail  email on the release commits; must belong to the account holding
                       the signing key for GitHub to show "Verified"

Secrets, from $(dot::relative "$HOST_ENV_FILE") alone:
  ${RELEASE_TOKEN_PREFIX}<NAME>  remote <name>'s token, encrypted, where there is no keychain;
                           written by bash dot release:token, never by hand

Every setting is required; a missing or empty one stops the release.

Examples:
  bash dot release:create 1.2.0
  bash dot release:create 1.2.0 --github
  bash dot release:create 1.2.0 --push-all
  bash dot release:create 1.2.0 --github --cache-pat=15
EOF
}

handle() {
  local version="" tag branch
  while [ $# -gt 0 ]; do
    if core.modules.release.console::parse_push_option "$1"; then
      shift
      continue
    fi
    case "$1" in
      -*) framework.console.args::invalid "Unknown argument: $1" ;;
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
