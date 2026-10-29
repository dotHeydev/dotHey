#!/usr/bin/env bash

DESCRIPTION="Add the dot alias to your shell, to type dot instead of bash dot."
DOCS="setting-up"

dot::use framework.console.args framework.console.output framework.console.prompt core.modules.setup.alias

usage() {
  cat <<EOF
Adds one line to your shell's rc file, so dot runs ./dot (or dotdot's own
entry when that link is missing) and you no longer type bash first. It shows
the file and the line, and asks before writing; run it again after moving
dotdot to update the line.

Usage:
  bash dot alias:add [-y, --yes]

Options:
  -y, --yes    Add it without asking. Only at a terminal, or when dotdot
               itself runs it.
  -h, --help   Show this help.

Examples:
  bash dot alias:add

Notes:
  - Shells: bash, zsh, fish, ksh, mksh, tcsh, and csh, told by \$SHELL. For
    any other, it shows the line to add yourself.
  - It works in new terminals, or in this one after: source <file>.
  - bash dot alias:remove takes it back.
EOF
}

handle() {
  local confirmed=false shell file line current
  while [ $# -gt 0 ]; do
    case "$1" in
      -y | --yes) confirmed=true ;;
      *) framework.console.args::unexpected "$1" ;;
    esac
    shift
  done
  ! $confirmed || guards::skip_confirmation \
    || framework.console.output::fail_as "$EXIT_PRECONDITION" "-y only works in a terminal, so nothing changed unseen." "$OUTPUT_MANUAL_RUN bash dot alias:add"
  line=$(core.modules.setup.alias::line "$(core.modules.setup.alias::shell)" "${DOT_BIN#"$BASE"/}")
  shell=$(core.modules.setup.alias::shell)
  [ -n "$shell" ] || framework.console.output::fail_as "$EXIT_PRECONDITION" "Couldn't tell which shell you use (\$SHELL is ${SHELL:-unset})." \
    "Add this line to your shell's rc file: $line"
  file=$(core.modules.setup.alias::file "$shell")
  if current=$(core.modules.setup.alias::current "$file") && [ "$current" = "$line" ]; then
    framework.console.output::success "The dot alias is already in $file."
    return 0
  fi
  framework.console.output::line "This adds to $file:"
  framework.console.output::detail "$(framework.console.output::code "$line")"
  [ -z "$current" ] || framework.console.output::detail "in place of: $current"
  $confirmed || framework.console.prompt::confirm_or_exit "Do you want to add it?" y "bash dot alias:add"
  core.modules.setup.alias::write "$file" "$line" || framework.console.output::fail "Couldn't add the alias."
  framework.console.output::success "Added the dot alias to $file."
  framework.console.output::next "It works in new terminals, or in this one after: source $file"
}
