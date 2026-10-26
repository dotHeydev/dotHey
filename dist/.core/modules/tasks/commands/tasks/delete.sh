#!/usr/bin/env bash

DESCRIPTION="Delete a task for good, after a confirmation at a terminal."

dot::use framework.console.args framework.helpers.fs framework.console.output framework.console.prompt core.modules.tasks.console core.modules.tasks.service

usage() {
  cat <<USAGE
bash dot tasks:delete — delete a task for good. It asks for confirmation at
a terminal (piped input is refused), so only a person can delete; moving a
task to done or discarded (bash dot tasks:update <id> --done) is the usual
way to end it.

Usage:
  bash dot tasks:delete <id>
  bash dot tasks:delete --help
USAGE
}

handle() {
  local id work title
  core.modules.tasks.service::check_id "${1-}"
  [ $# -eq 1 ] || framework.console.args::invalid "Which task? Please give one task id, e.g. t004."
  id="$1"
  framework.console.prompt::can_ask || framework.console.output::fail "This needs your confirmation in a terminal, so nothing changed." "$OUTPUT_MANUAL_RUN bash dot tasks:delete $id"
  core.modules.tasks.console::ensure_service
  framework.helpers.fs::make_temp_dir work || framework.console.output::fail "Couldn't create a temporary directory; please check free space and \$TMPDIR."
  core.modules.tasks.console::call show "$id" > "$work/show" || exit 1
  title=$(head -n 1 "$work/show" | cut -f 5)
  framework.console.prompt::confirm "Do you want to delete task $id \"$title\"? This can't be undone." || { framework.console.output::aborted; exit 1; }
  core.modules.tasks.console::call delete "$id" || exit 1
  framework.console.output::success "Deleted task $id."
}
