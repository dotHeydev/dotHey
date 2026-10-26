#!/usr/bin/env bash

dot::use framework.console.output

core.modules.tasks.drivers.file-setup::setup() {
  core.modules.tasks.drivers.file::configure
  framework.console.output::detail "Each task is a file in $(dot::relative "$TASKS_DIR")/."
}
