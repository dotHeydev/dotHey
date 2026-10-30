# shellcheck shell=bash

hey::use framework.console.args core.modules.tasks.service framework.console.output framework.console.prompt framework.helpers.template framework.console.terminal framework.ui.spinner

core.modules.tasks.console::section_flags_help() {
  local section
  while IFS= read -r section; do
    framework.console.output::option "--$(framework.helpers.template::key "$section") <text>" "$section." 25
  done < <(core.modules.tasks.service::sections)
}

core.modules.tasks.console::ensure_service() {
  local service
  core.modules.tasks.service::require_template
  if ! service=$(core.modules.tasks.service::selected_service); then
    framework.console.prompt::is_interactive \
      || framework.console.output::fail_as "$EXIT_PRECONDITION" "Tasks aren't set up yet." "Choose where they're kept: bash hey tasks:initialize --service <$(core.modules.tasks.service::services | paste -sd '|' -)>"
    framework.console.output::warn "Tasks aren't set up yet."
    hey::call tasks:initialize || exit
    service=$(core.modules.tasks.service::selected_service) || framework.console.output::fail "No task service chosen, so nothing changed."
  fi
  core.modules.tasks.service::load_service "$service"
}

core.modules.tasks.console::call() {
  local verb="$1"
  shift
  framework.ui.spinner::run "" "$(core.modules.tasks.service::driver "$verb")" "$@"
}

core.modules.tasks.console::print_location() {
  local location
  location=$(core.modules.tasks.console::call link "$1") && [ -n "$location" ] && framework.console.output::detail "$location"
  return 0
}

core.modules.tasks.console::editor_mode() {
  local mode="$1" has_changes="$2"
  if [ "$mode" != auto ]; then
    printf '%s\n' "$mode"
  elif framework.console.prompt::is_interactive && ! $has_changes; then
    printf 'yes\n'
  else
    printf 'no\n'
  fi
}

core.modules.tasks.console::edit_body() {
  local body="$1" draft
  draft="$body.edit"
  cp -- "$body" "$draft"
  core.modules.tasks.service::add_guidance "$draft"
  framework.console.terminal::edit "$draft" || framework.console.output::fail "The editor exited with an error, so nothing was saved."
  ! core.modules.tasks.service::is_blank "$draft" || framework.console.output::fail "Cancelled — the task was left empty, so nothing was saved."
  core.modules.tasks.service::strip_guidance "$draft"
  mv -f -- "$draft" "$body"
}

core.modules.tasks.console::status_usage() {
  local status="$1"
  cat <<USAGE
Moves a task to $status.

Usage:
  bash hey tasks:$status <id>

Arguments:
  <id>         The task's id (t004, #12).

Options:
  -h, --help   Show this help.

Examples:
  bash hey tasks:$status t004

Notes:
  - The same as bash hey tasks:update <id> --status $status.
USAGE
}

core.modules.tasks.console::move() {
  local status="$1"
  shift
  [ $# -eq 1 ] || framework.console.args::invalid "Which task? Please give one task id, e.g. t004."
  hey::call tasks:update "$1" --status "$status"
}
