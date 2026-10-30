# shellcheck shell=bash

dot::use framework.console.output framework.console.prompt

# Sets up <repository>; without one, asks for it and to go on, at a terminal.
core.modules.tasks.drivers.github-setup::setup() {
  local repository="${1-}" labels asked=false
  [ -n "$repository" ] || framework.console.prompt::can_ask \
    || framework.console.output::fail_as "$EXIT_USAGE" "Which repository? Please give --repo <owner>/<name>." "bash dot tasks:initialize --service github --repo <owner>/<name>"
  core.modules.tasks.drivers.github::is_authenticated \
    || framework.console.output::fail_as "$EXIT_PRECONDITION" "GitHub tasks need gh signed in, or DOT_GH_TOKEN in $(dot::relative "$HOST_ENV_FILE")." "Please run gh auth login (get gh at https://cli.github.com)."
  if [ -z "$repository" ]; then
    repository=$(framework.console.prompt::ask "GitHub repository for tasks (owner/name)" "$(core.modules.tasks.drivers.github::detected_repository)")
    asked=true
  fi
  core.modules.tasks.drivers.github::check_repository "$repository" || exit
  labels=$(core.modules.tasks.drivers.github::managed_labels | paste -sd ',' - | sed 's/,/, /g')
  framework.console.output::line "This adds or updates these labels in $repository: $labels."
  ! $asked || framework.console.prompt::confirm "Do you want to continue?" || framework.console.output::fail "Cancelled — nothing changed."
  core.modules.tasks.drivers.github::configure "$repository" || exit
  framework.console.output::detail "Each task is an issue labelled \"$TASK_LABEL\" in $repository."
}
