# shellcheck shell=bash

DESCRIPTION="Change a decision's status."
DOCS="decisions"

dot::use framework.console.args core.modules.decisions.console core.modules.decisions.service framework.helpers.frontmatter framework.console.output

usage() {
  cat <<EOF
Sets a decision's status and refreshes its "modified" date, in one step.

Usage:
  bash dot decisions:update <decision> --status <status>
  bash dot decisions:update <decision> --status $DECISION_SUPERSEDED_FLAG --by <replacement>

Arguments:
  <decision>        The decision, as 2, 002, or its file name.

Options:
  -s, --status <status>
                    Required. $(core.modules.decisions.service::statuses | paste -sd ' ' -), or
                    $DECISION_SUPERSEDED_FLAG.
  --by <replacement>
                    With $DECISION_SUPERSEDED_FLAG: the decision that replaces it (checked
                    to exist; the link is built for you).
  -h, --help        Show this help.

Examples:
  bash dot decisions:update 002 --status accepted
  bash dot decisions:update 002 --status $DECISION_SUPERSEDED_FLAG --by 007

Notes:
  - Only the status and the date change. To change the prose, edit the file
    and bump "modified".
EOF
}

handle() {
  local reference="" status="" status_flag="" superseder="" file path previous
  [ $# -gt 0 ] || framework.console.args::invalid "Which decision, and which status?"
  while [ $# -gt 0 ]; do
    case "$1" in
      -s | --status)
        framework.console.args::require_value "$@"
        [ -z "$status_flag" ] || framework.console.args::invalid "Please give one status at a time."
        [ "$2" = "$DECISION_SUPERSEDED_FLAG" ] || core.modules.decisions.service::is_status "$2" \
          || framework.console.args::invalid "\"$2\" isn't a decision status; please use one of $(core.modules.decisions.service::statuses | paste -sd ' ' -), or $DECISION_SUPERSEDED_FLAG."
        status_flag="$2"
        status="$2"
        shift 2
        ;;
      --by)
        framework.console.args::require_value "$@"
        superseder="$2"
        shift 2
        ;;
      -*) framework.console.args::unexpected "$1" ;;
      *)
        [ -z "$reference" ] || framework.console.args::unexpected "$1"
        reference="$1"
        shift
        ;;
    esac
  done
  [ -n "$reference" ] || framework.console.args::invalid "Which decision? Please give its number, e.g. 002."
  [ -n "$status_flag" ] || framework.console.args::invalid "Which status? e.g. --status accepted, or --status $DECISION_SUPERSEDED_FLAG --by 007."
  if [ "$status_flag" = "$DECISION_SUPERSEDED_FLAG" ]; then
    [ -n "$superseder" ] || framework.console.args::invalid "$DECISION_SUPERSEDED_FLAG needs the decision that replaces this one, e.g. --by 007."
  else
    [ -z "$superseder" ] || framework.console.args::invalid "--by only goes with $DECISION_SUPERSEDED_FLAG."
  fi
  file=$(core.modules.decisions.service::find "$reference") || framework.console.output::fail_as "$EXIT_NOT_FOUND" "No decision matches \"$reference\"." "See them all: bash dot frontmatter:show Decisions"
  path="$DECISIONS_DIR/$file"
  if [ "$status_flag" = "$DECISION_SUPERSEDED_FLAG" ]; then
    status=$(core.modules.decisions.service::superseded_status "$superseder") \
      || framework.console.output::fail_as "$EXIT_NOT_FOUND" "No decision matches \"$superseder\" (--by)."
  fi
  case "$status" in
    *"]($file)"*) framework.console.output::fail "A decision can't supersede itself." ;;
  esac
  framework.helpers.frontmatter::exists "$path" || framework.console.output::fail "$file has no frontmatter to update."
  previous=$(framework.helpers.frontmatter::field "$path" status)
  core.modules.decisions.service::update_status "$path" "$status" || framework.console.output::fail "$file's frontmatter needs status: and modified:."
  framework.console.output::success "Decision $(framework.helpers.record::number "$file") is now $status (was ${previous:-unset})."
  framework.console.output::detail "$(dot::relative "$path")"
}
