# shellcheck shell=bash

DESCRIPTION="Move a task to discarded."
DOCS="tasks"

hey::use core.modules.tasks.console core.modules.tasks.service

usage() {
  core.modules.tasks.console::status_usage "${HEY_COMMAND#tasks:}"
}

handle() {
  core.modules.tasks.console::move "${HEY_COMMAND#tasks:}" "$@"
}
