#!/usr/bin/env bash

DESCRIPTION="Choose where the project keeps its tasks."

dot::use framework.console.args framework.console.output framework.console.prompt core.modules.tasks.service

usage() {
  local service
  cat <<USAGE
Asks where this project keeps its tasks and sets that service up; the first
tasks:* command runs it for you. Running it again switches services; existing
tasks stay where they are.

Usage:
  bash dot tasks:initialize

Options:
  -h, --help   Show this help.

Services:
USAGE
  while IFS= read -r service; do
    printf '  %-12s %s\n' "$service" "$(core.modules.tasks.service::service_description "$service")"
  done < <(core.modules.tasks.service::services)
  cat <<USAGE

Notes:
  - The choice is saved as $TASK_SERVICE_SETTING in $(dot::relative "$SETTINGS_FILE"), shared by the
    project; set it to "@env:<KEY>" to let each person choose in $(dot::relative "$HOST_ENV_FILE").
  - It asks at a terminal only, so only a person can choose.
USAGE
}

handle() {
  local services=() labels=() service current choice
  [ $# -eq 0 ] || framework.console.args::unexpected "$1"
  framework.console.prompt::can_ask || framework.console.output::fail "Choosing a task service needs a terminal." "$OUTPUT_MANUAL_RUN bash dot tasks:initialize"
  core.modules.tasks.service::require_template
  while IFS= read -r service; do
    services+=("$service")
    labels+=("$service — $(core.modules.tasks.service::service_description "$service")")
  done < <(core.modules.tasks.service::services)
  [ ${#services[@]} -gt 0 ] || framework.console.output::fail "No task services found in $(dot::relative "$TASK_DRIVERS_DIR")/."
  if current=$(core.modules.tasks.service::selected_service); then
    framework.console.output::line "Tasks are now kept in $(framework.console.output::paint bold "$current"); switching leaves existing ones where they are."
  fi
  framework.console.output::newline
  choice=$(framework.console.prompt::choice "Where should this project keep its tasks?" "${labels[@]}") || { framework.console.output::aborted; exit 1; }
  service="${services[$((choice - 1))]}"
  core.modules.tasks.service::load_service "$service"
  dot::use "core.modules.tasks.drivers.$service-setup"
  "core.modules.tasks.drivers.${service}-setup::setup" || framework.console.output::fail "Couldn't set up $service, so nothing changed."
  core.modules.tasks.service::select_service "$service"
  framework.console.output::success "Tasks will be kept in $service."
}
