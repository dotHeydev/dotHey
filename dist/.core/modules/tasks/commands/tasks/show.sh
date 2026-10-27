#!/usr/bin/env bash

DESCRIPTION="Show a task."

dot::use framework.console.args framework.helpers.fs framework.console.output core.modules.tasks.console core.modules.tasks.service framework.console.terminal

usage() {
  cat <<USAGE
Shows a task as Markdown: its fields as frontmatter, then its body. At a
terminal it opens in less; anywhere else it's printed.

Usage:
  bash dot tasks:show <id> [--no-pager]

Arguments:
  <id>                     The task, as tasks:list shows it (t004, #12).

Options:
  --no-pager               Print it, even at a terminal.
  -h, --help               Show this help.

Examples:
  bash dot tasks:show t004
USAGE
}

handle() {
  local id print=false work task_id status created updated title
  core.modules.tasks.console::ensure_service
  core.modules.tasks.service::check_id "${1-}"
  id="$1"
  shift
  while [ $# -gt 0 ]; do
    case "$1" in
      --no-pager) print=true; shift ;;
      *) framework.console.args::unexpected "$1" ;;
    esac
  done
  framework.helpers.fs::make_temp_dir work || framework.console.output::fail "Couldn't create a temporary directory; please check free space and \$TMPDIR."
  core.modules.tasks.console::call show "$id" > "$work/show" || exit 1
  IFS=$'\t' read -r task_id status created updated title < "$work/show"
  case "$task_id" in
    "#"*) task_id="\"$task_id\"" ;;
  esac
  {
    printf -- '---\nid: %s\ntitle: %s\nstatus: %s\ncreated: %s\nupdated: %s\n---\n\n' "$task_id" "$title" "$status" "$created" "$updated"
    tail -n +2 "$work/show"
  } > "$work/task.md"
  framework.console.terminal::page "$work/task.md" "$print"
}
