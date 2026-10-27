#!/usr/bin/env bash

dot::use framework.console.args core.modules.tasks.service framework.console.output framework.console.prompt framework.helpers.template framework.console.terminal

core.modules.tasks.console::section_flags_help() {
  local section
  while IFS= read -r section; do
    printf '  --%-26s %s\n' "$(framework.helpers.template::key "$section")" "$section"
  done < <(core.modules.tasks.service::sections)
}

core.modules.tasks.console::ensure_service() {
  local service
  core.modules.tasks.service::require_template
  if ! service=$(core.modules.tasks.service::selected_service); then
    framework.console.prompt::is_interactive || framework.console.output::fail "Tasks aren't set up yet." "$OUTPUT_MANUAL_RUN bash dot tasks:initialize"
    framework.console.output::warn "Tasks aren't set up yet."
    dot::call tasks:initialize || exit 1
    service=$(core.modules.tasks.service::selected_service) || framework.console.output::fail "No task service chosen, so nothing changed."
  fi
  core.modules.tasks.service::load_service "$service"
}

core.modules.tasks.console::call() {
  local verb="$1"
  shift
  framework.console.output::spin "" "$(core.modules.tasks.service::driver "$verb")" "$@"
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
bash dot tasks:$status — move a task to $status, in whichever service keeps the tasks.
The same as bash dot tasks:update <id> --status $status.

Usage:
  bash dot tasks:$status <id>
  bash dot tasks:$status --help

<id> is what bash dot tasks:list shows (t004, #12).
USAGE
}

core.modules.tasks.console::move() {
  local status="$1"
  shift
  [ $# -eq 1 ] || framework.console.args::invalid "Which task? Please give one task id, e.g. t004."
  dot::call tasks:update "$1" --status "$status"
}
