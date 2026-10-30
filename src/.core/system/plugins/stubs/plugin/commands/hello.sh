# shellcheck shell=bash

DESCRIPTION="Greet from the plugin."

hey::use framework.console.args framework.console.output

usage() {
  framework.console.output::line "bash hey $HEY_COMMAND — greet from the plugin."
  framework.console.output::newline
  framework.console.output::line "Usage:"
  framework.console.output::line "  bash hey $HEY_COMMAND [name]"
}

handle() {
  [ $# -le 1 ] || framework.console.args::unexpected "$2"
  framework.console.output::success "Hello, ${1:-world}!"
}
