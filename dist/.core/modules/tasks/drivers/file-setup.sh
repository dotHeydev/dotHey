# shellcheck shell=bash

hey::use framework.console.output framework.console.args

core.modules.tasks.drivers.file-setup::setup() {
  [ -z "${1-}" ] || framework.console.args::invalid "--repo is for the github service only."
  core.modules.tasks.drivers.file::configure
  framework.console.output::detail "Each task is a file in $(hey::relative "$TASKS_DIR")/."
}
