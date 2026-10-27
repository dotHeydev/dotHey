#!/usr/bin/env bash

DESCRIPTION="Open a new xray to discuss a topic in a file."

dot::use framework.console.args core.modules.xrays.service framework.console.output framework.helpers.record framework.helpers.text

usage() {
  cat <<USAGE
Creates the next numbered xray in Xrays/ from the xray template,
ready for its topics and questions.

Usage:
  bash dot xrays:create <name> --description <text>

Arguments:
  <name>                 The xray's title; becomes its file name.

Options:
  --description <text>   Required. One sentence: what it settles, and why it
                         matters.
  -h, --help             Show this help.

Examples:
  bash dot xrays:create "Existing project adoption" \\
    --description "How dotdot moves into a project with its own harness setup."
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
  [ -n "$name" ] || framework.console.args::invalid "An xray needs a name."
  [ -n "$description" ] || framework.console.args::invalid "An xray needs --description."
  framework.helpers.text::is_one_line "$name" || framework.console.args::invalid "The name must fit on one line."
  slug=$(framework.helpers.text::slug "$name")
  [ -n "$slug" ] || framework.console.args::invalid "The name needs at least one letter or digit."
  path=$(core.modules.xrays.service::create "$name" "$slug" "$description") || framework.console.output::fail "Couldn't create the xray; please try again."
  framework.console.output::success "Opened xray $(framework.helpers.record::number "$(basename -- "$path")")."
  framework.console.output::detail "$(dot::relative "$path")"
}
