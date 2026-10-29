#!/usr/bin/env bash

DESCRIPTION="Scan the project for harnesses and what they already hold."
DOCS="setting-up"
JSON=true

dot::use framework.console.args framework.console.output framework.helpers.json core.modules.setup.service core.modules.setup.console

usage() {
  cat <<EOF
Lists each harness dotdot supports, the ones the project uses, and what their
places already hold (instructions, skills, agents, rules), with dotdot's
setup. Other top-level Markdown docs are listed as unsure: context the
project may want dotdot to take in. It reads paths and sizes only, never
.env, .git/, or anything a link leads outside the project, and changes
nothing.

Usage:
  bash dot adopt --scan [--json]

Options:
  --scan       Scan the project.
  --json       Print {"harnesses", "detected", "items", "setup", "invalid"}.
  -h, --help   Show this help.

Examples:
  bash dot adopt --scan
  bash dot adopt --scan --json
EOF
}

# The scan as JSON.
print_json() {
  local ids="$1" detected="$2" rows="$3" id kind path size harnesses="" found="" items="" invalid="" setup
  for id in $ids; do
    harnesses="$harnesses${harnesses:+,}{\"id\":$(framework.helpers.json::string "$id"),\"name\":$(framework.helpers.json::string "$(core.harnesses.harness::data "$id" .name)"),\"detected\":$([[ " $detected " == *" $id "* ]] && printf true || printf false)}"
  done
  for id in $detected; do
    found="$found${found:+,}$(framework.helpers.json::string "$id")"
  done
  while IFS="$SETUP_TAB" read -r id kind path size; do
    [ -n "$path" ] || continue
    items="$items${items:+,}{\"harness\":$([ "$id" != "$SETUP_NO_HARNESS" ] && framework.helpers.json::string "$id" || printf null),\"kind\":$(framework.helpers.json::string "$kind"),\"path\":$(framework.helpers.json::string "$path"),\"size\":${size:-0}}"
  done <<< "$rows"
  for id in ${SETUP_INVALID[@]+"${SETUP_INVALID[@]}"}; do
    invalid="$invalid${invalid:+,}$(framework.helpers.json::string "$id")"
  done
  setup="{\"harnesses\":$(core.modules.setup.service::state "$SETUP_HARNESSES_SETTING" "[]"),\"type\":$(dot::json_value "$SETTINGS_FILE" ".$SETUP_TYPE_SETTING" 2>/dev/null || printf null),\"location\":$(framework.helpers.json::string "$DOTDOT_NAME"),\"pending\":$(core.modules.setup.service::state "$SETUP_PENDING_SETTING" "[]")}"
  printf '{"harnesses":[%s],"detected":[%s],"items":[%s],"setup":%s,"invalid":[%s]}\n' "$harnesses" "$found" "$items" "$setup" "$invalid"
}

handle() {
  local scan=false ids detected rows
  while [ $# -gt 0 ]; do
    case "$1" in
      --scan) scan=true ;;
      *) framework.console.args::unexpected "$1" ;;
    esac
    shift
  done
  $scan || framework.console.args::invalid "What should adopt do? Only --scan is supported so far."
  core.modules.setup.service::harnesses
  ids="$SETUP_IDS"
  core.modules.setup.console::warn_invalid
  # shellcheck disable=SC2086
  detected=$(core.modules.setup.service::detected $ids | tr '\n' ' ')
  # shellcheck disable=SC2086
  rows=$(core.modules.setup.service::scan $ids)
  rows=$(printf '%s\n%s' "$rows" "$(core.modules.setup.service::unsure "$rows")" | grep -v '^$' || true)
  if $DOT_JSON; then
    print_json "$ids" "$detected" "$rows"
    return
  fi
  core.modules.setup.console::found "$rows"
  framework.console.output::detail "Harnesses: $ids"
  framework.console.output::detail "Detected: ${detected:-none}"
}
