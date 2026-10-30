# shellcheck shell=bash

DESCRIPTION="Choose where the project keeps its tasks."
DOCS="tasks"

dot::use framework.console.args framework.console.output framework.console.prompt core.modules.tasks.service

usage() {
  local service
  cat <<USAGE
Sets up where this project keeps its tasks: the service given, or, at a
terminal, the one you choose. Running it again switches services; existing
tasks stay where they are.

Usage:
  bash dot tasks:initialize [--service <service>] [--repo <owner>/<name>]

Options:
  --service <service>      The service (below); asked for at a terminal.
  --repo <owner>/<name>    With github: the repository for tasks; asked for at
                           a terminal (default there: this repo's origin).
  -h, --help               Show this help.

Examples:
  bash dot tasks:initialize --service files
  bash dot tasks:initialize --service github --repo acme/app

Services:
USAGE
  while IFS= read -r service; do
    printf '  %-12s %s\n' "$service" "$(core.modules.tasks.service::service_description "$service")"
  done < <(core.modules.tasks.service::services)
  cat <<USAGE

Notes:
  - The first task command runs it for you.
  - The choice is saved as $TASK_SERVICE_SETTING in $(dot::relative "$SETTINGS_FILE"), shared by the
    project; set it to "@env:<KEY>" to let each person choose in $(dot::relative "$HOST_ENV_FILE").
USAGE
}

handle() {
  local services=() labels=() service="" repository="" current choice
  while [ $# -gt 0 ]; do
    case "$1" in
      --service) framework.console.args::require_value "$@"; service="$2"; shift 2 ;;
      --repo) framework.console.args::require_value "$@"; repository="$2"; shift 2 ;;
      *) framework.console.args::unexpected "$1" ;;
    esac
  done
  core.modules.tasks.service::require_template
  while IFS= read -r current; do
    services+=("$current")
    labels+=("$current — $(core.modules.tasks.service::service_description "$current")")
  done < <(core.modules.tasks.service::services)
  [ ${#services[@]} -gt 0 ] || framework.console.output::fail "No task services found in $(dot::relative "$TASK_DRIVERS_DIR")/."
  if [ -n "$service" ]; then
    [[ " ${services[*]} " == *" $service "* ]] || framework.console.args::invalid "\"$service\" isn't a task service: $(printf '%s ' "${services[@]}")"
  else
    framework.console.prompt::can_ask || framework.console.args::invalid "Which service? Please give --service <$(printf '%s\n' "${services[@]}" | paste -sd '|' -)>."
    if current=$(core.modules.tasks.service::selected_service); then
      framework.console.output::line "Tasks are now kept in $(framework.console.output::bold "$current"); switching leaves existing ones where they are."
    fi
    framework.console.output::newline
    choice=$(framework.console.prompt::choice "Where should this project keep its tasks?" "${labels[@]}") || { framework.console.output::aborted; exit 1; }
    service="${services[$((choice - 1))]}"
  fi
  core.modules.tasks.service::load_service "$service"
  dot::use "core.modules.tasks.drivers.$service-setup"
  "core.modules.tasks.drivers.${service}-setup::setup" "$repository" || framework.console.output::fail "Couldn't set up $service, so nothing changed."
  core.modules.tasks.service::select_service "$service"
  framework.console.output::success "Tasks will be kept in $service."
}
