# shellcheck shell=bash

DESCRIPTION="Change a task's title, content or status."
DOCS="tasks"

hey::use framework.console.args framework.helpers.fs framework.console.output core.modules.tasks.console core.modules.tasks.service

usage() {
  core.modules.tasks.service::require_template
  cat <<USAGE
Changes a task's title, content and status, in one step. At a terminal, with
nothing to change given, your editor opens on its current body.

Usage:
  bash hey tasks:update <id> [options]

Arguments:
  <id>                     The task's id (t004, #12).

Options:
  -t, --title <title>      Its new title.
  -s, --status <status>    $(core.modules.tasks.service::statuses | paste -sd ' ' -).
  --body <markdown>        Replace the whole body.
  --body-file <path>|-     Replace the whole body, from a project file or stdin.
$(core.modules.tasks.console::section_flags_help)
  -e, --edit               Open your editor on top of the changes, too.
  --no-edit                Never open the editor.
  -h, --help               Show this help.

Examples:
  bash hey tasks:update t004 --status doing
  bash hey tasks:update t004 --done-when "- [x] lock after 5" --status done
  bash hey tasks:update '#12' --title "Throttle failed logins"

Notes:
  - A section flag replaces that section only; the rest stays as it is.
  - Statuses are todo, doing, paused, done, discarded; bash hey tasks:<status>
    <id> moves one, --status here alongside other changes.
  - Working on a task you were handed: move it to doing when you start, record
    progress and answers in its sections (ticking its Done When items), and
    move it to done once every item is checked.
USAGE
}

handle() {
  local id work body sections title="" status="" has_body=false editor=auto has_changes body_argument=""
  core.modules.tasks.console::ensure_service
  core.modules.tasks.service::check_id "${1-}"
  id="$1"
  shift
  framework.helpers.fs::make_temp_dir work || framework.console.output::fail "Couldn't create a temporary directory; please check free space and \$TMPDIR."
  body="$work/body"
  sections="$work/sections"
  mkdir -p -- "$sections"
  while [ $# -gt 0 ]; do
    case "$1" in
      -s | --status)
        framework.console.args::require_value "$@"
        [ -z "$status" ] || framework.console.args::invalid "Please give one status at a time."
        core.modules.tasks.service::is_status "$2" || framework.console.args::invalid "\"$2\" isn't a task status."
        status="$2"
        shift 2
        ;;
      -t | --title)
        framework.console.args::require_value "$@"
        core.modules.tasks.service::check_title "$2"
        title="$2"
        shift 2
        ;;
      --body) framework.console.args::require_value "$@"; printf '%s\n' "$2" > "$body"; has_body=true; shift 2 ;;
      --body-file) framework.console.args::require_value "$@"; core.modules.tasks.service::read_body_file "$2" "$body"; has_body=true; shift 2 ;;
      -e | --edit) editor=yes; shift ;;
      --no-edit) editor=no; shift ;;
      --*)
        framework.console.args::require_value "$@"
        core.modules.tasks.service::set_section "$sections" "${1#--}" "$2" || framework.console.args::invalid "$1 isn't a task section."
        shift 2
        ;;
      *) framework.console.args::unexpected "$1" ;;
    esac
  done
  has_changes=$has_body
  [ -z "$title$status$(core.modules.tasks.service::given_sections "$sections")" ] || has_changes=true
  editor=$(core.modules.tasks.console::editor_mode "$editor" "$has_changes")
  [ "$editor" = yes ] || $has_changes || framework.console.args::invalid "Nothing to change: please give a title, a section, or a status."
  if $has_body || [ -n "$(core.modules.tasks.service::given_sections "$sections")" ] || [ "$editor" = yes ]; then
    if ! $has_body; then
      core.modules.tasks.console::call show "$id" > "$work/show" || exit
      tail -n +2 "$work/show" > "$body"
    fi
    core.modules.tasks.service::apply_sections "$body" "$sections"
    [ "$editor" = no ] || core.modules.tasks.console::edit_body "$body"
    body_argument="$body"
  fi
  if [ -n "$title" ] || [ -n "$body_argument" ]; then
    core.modules.tasks.console::call update "$id" "$title" "$body_argument" || exit
  fi
  [ -z "$status" ] || core.modules.tasks.console::call status "$id" "$status" || exit
  framework.console.output::success "Updated task $id${status:+ (now $status)}."
  core.modules.tasks.console::print_location "$id"
}
