#!/usr/bin/env bash

DESCRIPTION="Push the release repo to its remotes, each with its own stored access token."

dot::use framework.console.args core.modules.release.console core.modules.release.service framework.console.output framework.console.prompt

usage() {
  cat <<EOF
bash dot release:push — push the release repo's branch and all its tags to the
configured remotes. bash dot release:create ends with it; run it alone to retry or
finish a push.

Each remote is pushed over https with the personal access token stored for
it (bash dot release:token <remote>); no other credential is used. It asks,
remote by remote, whether to push (default no); without a terminal it pushes
only where a flag says so.

Usage:
  bash dot release:push [--<remote>...] [--push-all] [--cache-pat=N] [--force]
  bash dot release:push --help

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

Settings, from $(dot::relative "$SETTINGS_FILE") (see bash dot release:create --help):
  release.destination  release repo directory, from the project root
  release.branch       branch in the release repo
  release.remotes      {<name>: <https url>}, at least one

Examples:
  bash dot release:push
  bash dot release:push --github
  bash dot release:push --github --cache-pat=15
EOF
}

handle() {
  local branch tag
  while [ $# -gt 0 ]; do
    core.modules.release.console::parse_push_option "$1" || framework.console.args::unexpected "$1"
    shift
  done
  ! $RELEASE_FORCE || framework.console.prompt::confirm_or_exit "Force-pushing replaces the remotes' history. Do you want to force-push?" n "bash dot release:push --force"
  cd "$RELEASE_PROJECT" || framework.console.output::fail "Can't open the project at $RELEASE_PROJECT."
  RELEASE_DESTINATION=$(dot::setting release.destination)
  branch=$(dot::setting release.branch)
  core.modules.release.service::load_remotes
  core.modules.release.service::check_push_targets
  core.modules.release.service::open_repository "$branch"
  core.modules.release.service::repo rev-parse -q --verify HEAD >/dev/null || framework.console.output::fail "There's no release to push yet." "Please create one first: bash dot release:create <version>"
  tag=$(core.modules.release.service::repo describe --tags --exact-match HEAD 2>/dev/null || core.modules.release.service::repo rev-parse --short HEAD)
  core.modules.release.console::push "$branch" "$tag"
}
