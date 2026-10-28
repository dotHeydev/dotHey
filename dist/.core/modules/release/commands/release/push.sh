#!/usr/bin/env bash

DESCRIPTION="Push the release to its remotes."
DOCS="releases"

dot::use framework.console.args core.modules.release.console core.modules.release.service framework.console.output framework.console.prompt

usage() {
  cat <<EOF
Pushes the release repo's branch and tags, asking remote by remote; use it to
retry or finish a release's push. Each remote uses its own token.

Usage:
  bash dot release:push [<remote>...] [--all] [options]

Arguments:
  <remote>                  Push to that remote without asking; repeatable or
                            comma-separated. Names are release.remotes' keys.

Options:
  --all                     Push to every remote without asking.
  --keep-tokens <minutes>   Keep the unlocked tokens that many minutes (0
                            forgets them).
  --force                   Force-push, replacing the remotes' history; each
                            remote's name must be typed to confirm, at a
                            terminal.
  -h, --help                Show this help.

Examples:
  bash dot release:push
  bash dot release:push github
  bash dot release:push --all --keep-tokens 15

Notes:
  - Without a terminal it pushes only to the remotes given, or all with --all.
EOF
}

handle() {
  local branch tag
  while [ $# -gt 0 ]; do
    if core.modules.release.console::parse_push_option "$@"; then
      shift "$RELEASE_TAKEN"
      continue
    fi
    case "$1" in
      --all) RELEASE_PUSH_ALL=true ;;
      -*) framework.console.args::unexpected "$1" ;;
      *) core.modules.release.console::add_remotes "$1" ;;
    esac
    shift
  done
  cd "$RELEASE_PROJECT" || framework.console.output::fail "Can't open the project at $RELEASE_PROJECT."
  RELEASE_DESTINATION=$(dot::setting release.destination)
  branch=$(dot::setting release.branch)
  core.modules.release.service::load_remotes
  core.modules.release.service::check_push_targets
  core.modules.release.service::open_repository "$branch"
  core.modules.release.service::repo rev-parse -q --verify HEAD >/dev/null || framework.console.output::fail_as "$EXIT_PRECONDITION" "There's no release to push yet." "Please create one first: bash dot release:create <version>"
  tag=$(core.modules.release.service::repo describe --tags --exact-match HEAD 2>/dev/null || core.modules.release.service::repo rev-parse --short HEAD)
  core.modules.release.console::push "$branch" "$tag"
}
