# shellcheck shell=bash

DESCRIPTION="Delete a task for good."
DOCS="work/records#tasks"

hey::use framework.console.args framework.helpers.fs framework.console.output framework.console.prompt core.modules.tasks.console core.modules.tasks.service

usage() {
  cat <<USAGE
Deletes a task for good, after asking at a terminal. Moving it to done or
discarded is the usual way to end one.

Usage:
  bash hey tasks:delete <id> [-y, --yes]

Arguments:
  <id>                     The task's id (t004, #12).

Options:
  -y, --yes                Delete without asking. It still needs a terminal.
  -h, --help               Show this help.

Examples:
  bash hey tasks:delete t004
USAGE
}

handle() {
  local id work title confirmed=false
  core.modules.tasks.service::check_id "${1-}"
  id="$1"
  shift
  case "${1-}" in
    -y | --yes) confirmed=true; shift ;;
  esac
  [ $# -eq 0 ] || framework.console.args::unexpected "$1"
  framework.console.prompt::can_ask || framework.console.output::fail_as "$EXIT_PRECONDITION" "This needs your confirmation in a terminal, so nothing changed." "$OUTPUT_MANUAL_RUN bash hey tasks:delete $id"
  core.modules.tasks.console::ensure_service
  framework.helpers.fs::make_temp_dir work || framework.console.output::fail "Couldn't create a temporary directory; please check free space and \$TMPDIR."
  core.modules.tasks.console::call show "$id" > "$work/show" || exit
  title=$(head -n 1 "$work/show" | cut -f 5)
  if $confirmed; then
    framework.console.prompt::answered "Do you want to delete task $id \"$title\"?" "yes (--yes)"
  else
    framework.console.prompt::confirm "Do you want to delete task $id \"$title\"? This can't be undone." || { framework.console.output::aborted; exit 1; }
  fi
  core.modules.tasks.console::call delete "$id" || exit
  framework.console.output::success "Deleted task $id."
}
