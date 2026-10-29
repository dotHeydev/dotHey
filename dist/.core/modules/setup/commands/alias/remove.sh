#!/usr/bin/env bash

DESCRIPTION="Take the dot alias back out of your shell."
DOCS="setting-up"

dot::use framework.console.args framework.console.output framework.console.prompt core.modules.setup.alias

usage() {
  cat <<EOF
Removes the line bash dot alias:add put in your shell's rc file, and nothing
else of it, after asking.

Usage:
  bash dot alias:remove [-y, --yes]

Options:
  -y, --yes    Remove it without asking. Only at a terminal, or when dotdot
               itself runs it.
  -h, --help   Show this help.

Examples:
  bash dot alias:remove
EOF
}

handle() {
  local confirmed=false shell file
  while [ $# -gt 0 ]; do
    case "$1" in
      -y | --yes) confirmed=true ;;
      *) framework.console.args::unexpected "$1" ;;
    esac
    shift
  done
  ! $confirmed || guards::skip_confirmation \
    || framework.console.output::fail_as "$EXIT_PRECONDITION" "-y only works in a terminal, so nothing changed unseen." "$OUTPUT_MANUAL_RUN bash dot alias:remove"
  shell=$(core.modules.setup.alias::shell)
  [ -n "$shell" ] || framework.console.output::fail_as "$EXIT_PRECONDITION" "Couldn't tell which shell you use (\$SHELL is ${SHELL:-unset})."
  file=$(core.modules.setup.alias::file "$shell")
  core.modules.setup.alias::current "$file" >/dev/null || { framework.console.output::success "There's no dot alias in $file."; return 0; }
  $confirmed || framework.console.prompt::confirm_or_exit "Do you want to remove the dot alias from $file?" y "bash dot alias:remove"
  core.modules.setup.alias::remove "$file" || framework.console.output::fail "Couldn't remove the alias."
  framework.console.output::success "Removed the dot alias from $file."
}
