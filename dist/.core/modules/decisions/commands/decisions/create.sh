#!/usr/bin/env bash

DESCRIPTION="Document a new decision from the template."

dot::use framework.console.args core.modules.decisions.console core.modules.decisions.service framework.helpers.fs framework.console.output framework.helpers.template framework.helpers.text

usage() {
  local heading key
  cat <<EOF
Creates the next numbered decision in Decisions/ from the decision template;
one flag per template section. To change a decision afterwards, use
bash dot decisions:update, or edit its prose and bump "modified".

Usage:
  bash dot decisions:create <name> --statement <text> --elaboration <text>
                            [options]

Arguments:
  <name>                       Short name for the file (e.g. "JWT in httpOnly
                               cookie"); not the rule itself.

Options:
  --statement <text>           Required. The decision as a first-person rule,
                               able to stand alone; becomes the title and the
                               description.
  --elaboration <text>         Required. One plain paragraph: what must happen,
                               to whom, and with what side effects.
  -s, --status <status>        $(core.modules.decisions.service::statuses | paste -sd ' ' -)
                               (default: $DECISION_DEFAULT_STATUS).
  --$DECISION_SUPERSEDED_FLAG-by <decision>   Record it as already replaced by <decision>.
EOF
  while IFS= read -r heading; do
    key=$(framework.helpers.template::key "$heading")
    case "$(core.modules.decisions.service::kind "$key")" in
      decision | feature) printf '  --%-27s %s: a %s per use.\n' "$key <ref>" "$heading" "$(core.modules.decisions.service::kind "$key")" ;;
      *) printf '  --%-27s %s: a line per use.\n' "$key <text>" "$heading" ;;
    esac
  done < <(framework.helpers.template::headings "$DECISION_TEMPLATE")
  cat <<EOF
  -h, --help                   Show this help.

Examples:
  bash dot decisions:create "JWT in httpOnly cookie" \\
    --statement "We keep the session JWT in an httpOnly cookie." \\
    --elaboration "Every authenticated response sets it as one." \\
    --status accepted --influenced-by 002 --impacts 7

Notes:
  - The section flags and statuses come from the decision template.
  - A <ref> is a number (2, 002) or a file name; it's checked to exist, and
    its link is built for you.
EOF
}

handle() {
  local name="" statement="" has_name=false has_statement=false has_elaboration=false
  local status="$DECISION_DEFAULT_STATUS" status_flag="" superseder="" sections_dir key kind link slug path
  [ -f "$DECISION_TEMPLATE" ] || framework.console.output::fail "The template $(dot::relative "$DECISION_TEMPLATE") is missing." "bash dot update restores it."
  [ $# -gt 0 ] || framework.console.args::invalid "A decision needs a name, --statement and --elaboration."
  framework.helpers.fs::make_temp_dir sections_dir || framework.console.output::fail "Couldn't create a temporary directory; please check free space and \$TMPDIR."
  while [ $# -gt 0 ]; do
    case "$1" in
      -s | --status)
        framework.console.args::require_value "$@"
        core.modules.decisions.service::is_status "$2" || framework.console.args::invalid "\"$2\" isn't a decision status; please use one of $(core.modules.decisions.service::statuses | paste -sd ' ' -)."
        status_flag=$(core.modules.decisions.console::choose_status "$status_flag" "$2")
        status="$2"
        shift 2
        ;;
      --statement) framework.console.args::require_value "$@"; statement="$2"; has_statement=true; shift 2 ;;
      --elaboration) framework.console.args::require_value "$@"; printf '%s' "$2" > "$sections_dir/.elaboration"; has_elaboration=true; shift 2 ;;
      "--$DECISION_SUPERSEDED_FLAG-by")
        [ $# -ge 2 ] || framework.console.args::invalid "--$DECISION_SUPERSEDED_FLAG-by needs the decision that replaces this one, e.g. --$DECISION_SUPERSEDED_FLAG-by 007."
        status_flag=$(core.modules.decisions.console::choose_status "$status_flag" "$DECISION_SUPERSEDED_FLAG")
        superseder="$2"
        shift 2
        ;;
      --*)
        key="${1#--}"
        framework.helpers.template::has_key "$DECISION_TEMPLATE" "$key" || framework.console.args::invalid "--$key isn't a decision section."
        framework.console.args::require_value "$@"
        kind=$(core.modules.decisions.service::kind "$key")
        if [ "$kind" = text ]; then
          core.modules.decisions.service::append_section "$sections_dir/$key" "$2"
        else
          link=$(core.modules.decisions.service::reference_link "$kind" "$2") || framework.console.args::invalid "No $kind matches \"$2\" (--$key)."
          core.modules.decisions.service::append_section "$sections_dir/$key" "$link"
        fi
        shift 2
        ;;
      -*) framework.console.args::unexpected "$1" ;;
      *)
        ! $has_name || framework.console.args::unexpected "$1"
        name="$1"
        has_name=true
        shift
        ;;
    esac
  done
  $has_name || framework.console.args::invalid "A decision needs a name."
  $has_statement || framework.console.args::invalid "A decision needs --statement."
  $has_elaboration || framework.console.args::invalid "A decision needs --elaboration."
  if [ "$status_flag" = "$DECISION_SUPERSEDED_FLAG" ]; then
    status=$(core.modules.decisions.service::superseded_status "$superseder") \
      || framework.console.args::invalid "No decision matches \"$superseder\" (--$DECISION_SUPERSEDED_FLAG-by)."
  fi
  slug=$(framework.helpers.text::slug "$name")
  [ -n "$slug" ] || framework.console.args::invalid "The name needs at least one letter or digit."
  path=$(core.modules.decisions.service::create "$slug" "$status" "$statement" "$sections_dir") || framework.console.output::fail "Couldn't create the decision; please try again."
  framework.console.output::success "Documented decision $(framework.helpers.record::number "$(basename -- "$path")")."
  framework.console.output::detail "$(dot::relative "$path")"
}
