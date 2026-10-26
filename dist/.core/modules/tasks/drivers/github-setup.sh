#!/usr/bin/env bash

dot::use framework.console.output framework.console.prompt

core.modules.tasks.drivers.github-setup::setup() {
  local repository labels
  framework.console.prompt::can_ask || framework.console.output::fail "Setting up GitHub tasks needs a terminal."
  core.modules.tasks.drivers.github::is_authenticated \
    || framework.console.output::fail "GitHub tasks need gh logged in (gh auth login; install it from https://cli.github.com) or DOT_GH_TOKEN in $(dot::relative "$HOST_ENV_FILE")."
  repository=$(framework.console.prompt::ask "GitHub repository for tasks (owner/name)" "$(core.modules.tasks.drivers.github::detected_repository)")
  core.modules.tasks.drivers.github::check_repository "$repository" || exit 1
  labels=$(core.modules.tasks.drivers.github::managed_labels | paste -sd ',' - | sed 's/,/, /g')
  framework.console.output::line "This creates (or updates) these labels in $repository: $labels."
  framework.console.prompt::confirm "Continue?" || framework.console.output::fail "Cancelled."
  core.modules.tasks.drivers.github::configure "$repository" || exit 1
  framework.console.output::line "Tasks are issues labelled \"$TASK_LABEL\" in $repository."
}
