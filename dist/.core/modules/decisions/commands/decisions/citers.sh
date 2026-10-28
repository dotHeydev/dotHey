#!/usr/bin/env bash

DESCRIPTION="List the decisions that point at a decision."
DOCS="decisions"

dot::use framework.console.args core.modules.decisions.service framework.helpers.frontmatter framework.console.output

usage() {
  cat <<EOF
Lists the decisions that cite a decision or name it in "superseded by", with
why each points at it, so you know what relies on it before it changes.

Usage:
  bash dot decisions:citers <decision>[,...]

Arguments:
  <decision>   Decisions, as 2, 002, or their file name; comma-separated or
               one per argument.

Options:
  -h, --help   Show this help.

Examples:
  bash dot decisions:citers 004
  bash dot decisions:citers 002,005

Notes:
  - bash dot decisions:impact lists the features citing a decision instead.
EOF
}

print_field() {
  local value
  value=$(framework.helpers.frontmatter::field "$1" "$2")
  [ -z "$value" ] || framework.console.output::detail " $2: $value"
}

report_citers() {
  local reference="$1" target file reasons path found=false
  target=$(core.modules.decisions.service::find "$reference") \
    || framework.console.output::fail_as "$EXIT_NOT_FOUND" "No decision matches \"$reference\"." "See them all: bash dot frontmatter:show Decisions"
  framework.console.output::line "Decisions pointing at $target:"
  while IFS=$'\t' read -r file reasons; do
    found=true
    path="$DECISIONS_DIR/$file"
    framework.console.output::newline
    framework.console.output::line "  $file"
    framework.console.output::detail " $reasons"
    print_field "$path" description
    print_field "$path" status
  done < <(core.modules.decisions.service::inbound "$target")
  $found || framework.console.output::detail "(none)"
  framework.console.output::newline
}

handle() {
  local references=() reference
  while [ $# -gt 0 ]; do
    case "$1" in
      -*) framework.console.args::unexpected "$1" ;;
      *)
        while IFS= read -r reference; do
          references+=("$reference")
        done < <(framework.console.args::split "$1")
        shift
        ;;
    esac
  done
  [ ${#references[@]} -gt 0 ] || framework.console.args::invalid "Which decision? Please give its number, e.g. 004."
  for reference in "${references[@]}"; do
    report_citers "$reference"
  done
}
