# shellcheck shell=bash

DESCRIPTION="Open a new xray to discuss a topic in a file."
DOCS="work/xrays"
JSON=true

hey::use framework.console.args core.modules.xrays.service framework.console.output framework.helpers.record framework.helpers.text framework.console.prompt

usage() {
  cat <<USAGE
Creates the next numbered xray in Xrays/ from the xray template,
ready for its topics and questions.

Usage:
  bash hey xrays:create <title> --description <text>

Arguments:
  <title>                The xray's title; becomes its file name.

Options:
  --description <text>   Required. One sentence: what it settles, and why it
                         matters.
  --json                 Print {"id", "path"}.
  -h, --help             Show this help.

Examples:
  bash hey xrays:create "Existing project adoption" \\
    --description "How dotHey moves into a project with its own harness setup."

Notes:
  - At a terminal, a missing title or --description is asked for.
USAGE
}

handle() {
  local name="" description="" slug path
  while [ $# -gt 0 ]; do
    case "$1" in
      --description) framework.console.args::require_value "$@"; description=$(framework.helpers.text::oneline <<< "$2"); shift 2 ;;
      -*) framework.console.args::unexpected "$1" ;;
      *) [ -z "$name" ] || framework.console.args::unexpected "$1"; name="$1"; shift ;;
    esac
  done
  local asked=false
  [ -n "$name" ] && [ -n "$description" ] || asked=true
  name=$(framework.console.prompt::require "$name" "The xray's title" "An xray needs a title.")
  description=$(framework.console.prompt::require "$description" "What does it settle, and why does it matter" "An xray needs --description.")
  ! $asked || framework.console.prompt::hint "bash hey xrays:create \"$name\" --description \"$description\""
  framework.helpers.text::is_one_line "$name" || framework.console.args::invalid "The name must fit on one line."
  slug=$(framework.helpers.text::slug "$name")
  [ -n "$slug" ] || framework.console.args::invalid "The name needs at least one letter or digit."
  path=$(core.modules.xrays.service::create "$name" "$slug" "$description") || framework.console.output::fail "Couldn't create the xray; please try again."
  framework.console.output::created "Opened xray $(framework.helpers.record::number "$(basename -- "$path")")." "$(basename -- "$path" .md)" "$(hey::relative "$path")"
}
