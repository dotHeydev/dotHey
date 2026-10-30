# shellcheck shell=bash

DESCRIPTION="Take the hey alias back out of your shell."
DOCS="getting-started/setup"

hey::use framework.console.args framework.console.output framework.console.prompt core.modules.setup.alias

usage() {
  cat <<EOF
Removes the line bash hey alias:add put in your shells' rc files, from every
one that has it, and nothing else of them, after asking.

Usage:
  bash hey alias:remove [-y, --yes]

Options:
  -y, --yes    Remove it without asking. Only at a terminal, or when dotHey
               itself runs it.
  -h, --help   Show this help.

Examples:
  bash hey alias:remove
EOF
}

handle() {
  local confirmed=false shell file files=()
  while [ $# -gt 0 ]; do
    case "$1" in
      -y | --yes) confirmed=true ;;
      *) framework.console.args::unexpected "$1" ;;
    esac
    shift
  done
  ! $confirmed || guards::skip_confirmation \
    || framework.console.output::fail_as "$EXIT_PRECONDITION" "-y only works in a terminal, so nothing changed unseen." "$OUTPUT_MANUAL_RUN bash hey alias:remove"
  for shell in "${ALIAS_SHELLS[@]}"; do
    file=$(core.modules.setup.alias::file "$shell")
    ! core.modules.setup.alias::current "$file" >/dev/null || files+=("$file")
  done
  [ ${#files[@]} -gt 0 ] || { framework.console.output::success "There's no hey alias to remove."; return 0; }
  framework.console.output::line "This removes the hey alias from:"
  for file in "${files[@]}"; do
    framework.console.output::detail "${file/#"$HOME"/"~"}"
  done
  $confirmed || framework.console.prompt::confirm_or_exit "Do you want to remove it?" y "bash hey alias:remove"
  for file in "${files[@]}"; do
    core.modules.setup.alias::remove "$file" || framework.console.output::fail "Couldn't remove the alias from ${file/#"$HOME"/"~"}."
  done
  framework.console.output::success "Removed the hey alias."
}
