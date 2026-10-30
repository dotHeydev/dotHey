# shellcheck shell=bash

DESCRIPTION="Create a task."
DOCS="work/records#tasks"
JSON=true

hey::use framework.console.args framework.helpers.fs framework.console.output framework.console.prompt core.modules.tasks.console core.modules.tasks.service framework.helpers.text framework.helpers.json

usage() {
  core.modules.tasks.service::require_template
  cat <<USAGE
Creates a task in the project's task service, its body built from the task
template. At a terminal, a missing title is asked for, and your editor opens
when no content is given.

Usage:
  bash hey tasks:create [<title>] [options]

Arguments:
  <title>                  One line. Required without a terminal.

Options:
  -s, --status <status>    $(core.modules.tasks.service::statuses | paste -sd ' ' -) (default: $(core.modules.tasks.service::default_status)).
  --body <markdown>        The whole body.
  --body-file <path>|-     The whole body, from a project file or stdin.
$(core.modules.tasks.console::section_flags_help)
  -e, --edit               Open your editor on what was given, too.
  --no-edit                Never open the editor.
  --json                   Print {"id", "title", "status"}.
  -h, --help               Show this help.

Examples:
  bash hey tasks:create "Throttle failed logins" \\
    --description "Brute-force attempts aren't throttled." \\
    --done-when "- [ ] 5 failed attempts lock the route for a minute"
  bash hey tasks:create "Rewrite the README" --status doing

Notes:
  - Sections left out read "None"; a section flag goes on top of --body.
USAGE
}

handle() {
  local work body sections title="" has_title=false status has_body=false editor=auto has_content id
  core.modules.tasks.console::ensure_service
  framework.helpers.fs::make_temp_dir work || framework.console.output::fail "Couldn't create a temporary directory; please check free space and \$TMPDIR."
  body="$work/body"
  sections="$work/sections"
  mkdir -p -- "$sections"
  status=$(core.modules.tasks.service::default_status)
  while [ $# -gt 0 ]; do
    case "$1" in
      -s | --status) framework.console.args::require_value "$@"; status="$2"; shift 2 ;;
      --body) framework.console.args::require_value "$@"; printf '%s\n' "$2" > "$body"; has_body=true; shift 2 ;;
      --body-file) framework.console.args::require_value "$@"; core.modules.tasks.service::read_body_file "$2" "$body"; has_body=true; shift 2 ;;
      -e | --edit) editor=yes; shift ;;
      --no-edit) editor=no; shift ;;
      --*)
        framework.console.args::require_value "$@"
        core.modules.tasks.service::set_section "$sections" "${1#--}" "$2" || framework.console.args::invalid "$1 isn't a task section."
        shift 2
        ;;
      -*) framework.console.args::unexpected "$1" ;;
      *)
        ! $has_title || framework.console.args::unexpected "$1"
        title="$1"
        has_title=true
        shift
        ;;
    esac
  done
  core.modules.tasks.service::is_status "$status" || framework.console.args::invalid "\"$status\" isn't a task status."
  if ! $has_title; then
    framework.console.prompt::is_interactive || framework.console.args::invalid "The task needs a title."
    title=$(framework.console.prompt::require "" "Title" "The task needs a title.")
    framework.console.prompt::hint "bash hey tasks:create \"$title\" ..."
  fi
  core.modules.tasks.service::check_title "$title"
  $has_body || core.modules.tasks.service::compose_body "$sections" > "$body"
  core.modules.tasks.service::apply_sections "$body" "$sections"
  has_content=$has_body
  [ -z "$(core.modules.tasks.service::given_sections "$sections")" ] || has_content=true
  [ "$(core.modules.tasks.console::editor_mode "$editor" "$has_content")" = no ] || core.modules.tasks.console::edit_body "$body"
  id=$(core.modules.tasks.console::call create "$title" "$status" "$body") || exit
  if $HEY_JSON; then
    printf '{"id":%s,"title":%s,"status":%s}\n' "$(framework.helpers.json::string "$id")" "$(framework.helpers.json::string "$title")" "$(framework.helpers.json::string "$status")"
    return
  fi
  framework.console.output::success "Created task $id $UI_SEPARATOR $title ($status)"
  core.modules.tasks.console::print_location "$id"
}
