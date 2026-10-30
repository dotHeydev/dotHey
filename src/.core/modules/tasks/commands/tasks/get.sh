# shellcheck shell=bash

DESCRIPTION="Show a task."
DOCS="work/records#tasks"
JSON=true

hey::use framework.console.args framework.helpers.fs framework.console.output core.modules.tasks.console core.modules.tasks.service framework.console.terminal framework.helpers.json

usage() {
  cat <<USAGE
Shows a task as Markdown: its fields as frontmatter, then its body. At a
terminal it opens in less; anywhere else it's printed.

Usage:
  bash hey tasks:get <id> [--no-pager] [--json]

Arguments:
  <id>                     The task's id (t004, #12).

Options:
  --no-pager               Print it, even at a terminal.
  --json                   {"id", "title", "status", "created", "updated", "body"}.
  -h, --help               Show this help.

Examples:
  bash hey tasks:get t004
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
  core.modules.tasks.console::call show "$id" > "$work/show" || exit
  IFS=$'\t' read -r task_id status created updated title < "$work/show"
  if $HEY_JSON; then
    printf '{"id":%s,"title":%s,"status":%s,"created":%s,"updated":%s,"body":%s}\n' "$(framework.helpers.json::string "$task_id")" \
      "$(framework.helpers.json::string "$title")" "$(framework.helpers.json::string "$status")" "$(framework.helpers.json::string "$created")" \
      "$(framework.helpers.json::string "$updated")" "$(framework.helpers.json::string "$(tail -n +2 "$work/show")")"
    return
  fi
  case "$task_id" in
    "#"*) task_id="\"$task_id\"" ;;
  esac
  {
    printf -- '---\nid: %s\ntitle: %s\nstatus: %s\ncreated: %s\nupdated: %s\n---\n\n' "$task_id" "$title" "$status" "$created" "$updated"
    tail -n +2 "$work/show"
  } > "$work/task.md"
  framework.console.terminal::page "$work/task.md" "$print"
}
