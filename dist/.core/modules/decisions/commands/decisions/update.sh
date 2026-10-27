#!/usr/bin/env bash

DESCRIPTION="Change a decision's status and refresh its timestamp."

dot::use framework.console.args core.modules.decisions.console core.modules.decisions.service framework.helpers.frontmatter framework.console.output

usage() {
  cat <<EOF
bash dot decisions:update — set an existing decision's status and refresh its
"modified" timestamp in one step.

The timestamp is not a flag: it is the whole reason this exists rather than
being left to a hand edit, so it is always set to now.

Usage:
  bash dot decisions:update <decision> <status>
  bash dot decisions:update <decision> $DECISION_SUPERSEDED_FLAG --by <decision>
  bash dot decisions:update --help

Arguments:
  <decision>         The decision to update. Accepts "2", "002", or
                     "d002--no-soft-deletes.md" — whichever you have to hand.
  <status>           $(core.modules.decisions.service::statuses | paste -sd ' ' -), or $DECISION_SUPERSEDED_FLAG.

Optional:
  --by <decision>    With $DECISION_SUPERSEDED_FLAG: the decision that replaces it, in any of
                     the forms above. The status string — "superseded by
                     [dNNN](dNNN--slug.md)" — is built here, and <decision> is
                     checked to exist, so the link cannot be typed wrong.

Examples:
  bash dot decisions:update 002 accepted
  bash dot decisions:update 002 $DECISION_SUPERSEDED_FLAG --by 007

Only the status and the timestamp change. To edit a decision's prose, edit the
file directly — and bump "modified" yourself if you do.
EOF
}

handle() {
  local reference="" status="" status_flag="" superseder="" file path previous
  [ $# -gt 0 ] || framework.console.args::invalid "Which decision, and which status?"
  while [ $# -gt 0 ]; do
    case "$1" in
      --by)
        framework.console.args::require_value "$@"
        superseder="$2"
        shift 2
        ;;
      -*) framework.console.args::unexpected "$1" ;;
      *)
        if [ -z "$reference" ]; then
          reference="$1"
        elif [ -z "$status_flag" ]; then
          [ "$1" = "$DECISION_SUPERSEDED_FLAG" ] || core.modules.decisions.service::is_status "$1" \
            || framework.console.args::invalid "\"$1\" isn't a decision status; please use one of $(core.modules.decisions.service::statuses | paste -sd ' ' -), or $DECISION_SUPERSEDED_FLAG."
          status_flag="$1"
          status="$1"
        else
          framework.console.args::unexpected "$1"
        fi
        shift
        ;;
    esac
  done
  [ -n "$reference" ] || framework.console.args::invalid "Which decision? Please give its number, e.g. 002."
  [ -n "$status_flag" ] || framework.console.args::invalid "Which status? e.g. accepted, or $DECISION_SUPERSEDED_FLAG --by 007."
  if [ "$status_flag" = "$DECISION_SUPERSEDED_FLAG" ]; then
    [ -n "$superseder" ] || framework.console.args::invalid "$DECISION_SUPERSEDED_FLAG needs the decision that replaces this one, e.g. --by 007."
  else
    [ -z "$superseder" ] || framework.console.args::invalid "--by only goes with $DECISION_SUPERSEDED_FLAG."
  fi
  file=$(core.modules.decisions.service::find "$reference") || framework.console.output::fail "No decision matches \"$reference\"." "See them all: bash dot scan:frontmatter Decisions"
  path="$DECISIONS_DIR/$file"
  if [ "$status_flag" = "$DECISION_SUPERSEDED_FLAG" ]; then
    status=$(core.modules.decisions.service::superseded_status "$superseder") \
      || framework.console.output::fail "No decision matches \"$superseder\" (--by)."
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
