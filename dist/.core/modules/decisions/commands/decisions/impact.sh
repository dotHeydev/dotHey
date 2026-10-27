#!/usr/bin/env bash

DESCRIPTION="Find what a decision touches."

dot::use framework.console.args core.modules.decisions.service framework.helpers.frontmatter framework.helpers.fs framework.console.output framework.helpers.record framework.helpers.text

IMPACT_DEFAULT_LINES=3
IMPACT_SCOPES=" all features decisions "

usage() {
  cat <<EOF
Finds the features that cite decisions, the docs that mention its terms, and
the decisions that cite it, so you know what a new decision collides with.

Usage:
  bash dot decisions:impact <decision>[,...] [--term <text>[,...]]... [options]
  bash dot decisions:impact --term <text>[,...]... [options]
  bash dot decisions:impact <decision> --cited-by

Arguments:
  <decision>       Decisions, as 2, 002, or their file name; comma-separated or
                   one per argument. Lists the features citing them under
                   "$FEATURE_DECISIONS_HEADING".

Options:
  --term <text>    Terms to look for in features and decisions, comma-separated;
                   repeatable. Case-insensitive, and "auth" also finds "OAuth".
  --cited-by       List the decisions that point at <decision> instead.
  --scope <what>   all, features or decisions (default: all), for --term.
  --lines <n>      Matching lines shown per file (default: $IMPACT_DEFAULT_LINES; 0 for none).
  -h, --help       Show this help.

Examples:
  bash dot decisions:impact 002,005
  bash dot decisions:impact --term session,jwt,cookie --scope features
  bash dot decisions:impact 004 --cited-by

Notes:
  - Files are ranked by how many terms they match; prefer several precise terms.
  - No output means nothing documented is touched: a real answer.
  - bash dot decisions:check checks the links between decisions.
EOF
}

add_items() {
  local list="$1" item
  shift
  while IFS= read -r item; do
    [ -z "$item" ] || printf '%s\n' "$item" >> "$list"
  done < <(printf '%s\n' "$@")
}

report_inbound() {
  local reference="$1" target file reasons path found=false
  target=$(core.modules.decisions.service::find "$reference") || framework.console.output::fail "No decision matches \"$reference\"." "See them all: bash dot scan:frontmatter Decisions"
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

print_field() {
  local value
  value=$(framework.helpers.frontmatter::field "$1" "$2")
  [ -z "$value" ] || framework.console.output::detail " $2: $value"
}

report_citations() {
  local references_file="$1" reference file decisions=() feature cited found=false
  while IFS= read -r reference; do
    file=$(core.modules.decisions.service::find "$reference") || framework.console.output::fail "No decision matches \"$reference\"." "See them all: bash dot scan:frontmatter Decisions"
    decisions+=("$file")
  done < "$references_file"
  framework.console.output::line "Features citing these decisions under \"$FEATURE_DECISIONS_HEADING\":"
  while IFS=$'\t' read -r feature cited; do
    found=true
    framework.console.output::newline
    framework.console.output::line "  $(dot::relative "$FEATURES_DIR")/$feature"
    framework.console.output::detail " cites: $cited"
    print_field "$FEATURES_DIR/$feature" description
  done < <(core.modules.decisions.service::citing_features "${decisions[@]}")
  $found || framework.console.output::detail "(none)"
  framework.console.output::newline
}

report_terms() {
  local terms_file="$1" scope="$2" lines="$3" terms=() term matched total relative hits results
  while IFS= read -r term; do
    terms+=("$term")
  done < "$terms_file"
  results=$(core.modules.decisions.service::term_matches "$scope" "${terms[@]}" | sort -t$'\t' -k1,1nr -k2,2nr)
  framework.console.output::line "Files mentioning these terms:"
  if [ -z "$results" ]; then
    framework.console.output::detail "(none)"
    framework.console.output::newline
    return
  fi
  while IFS=$'\t' read -r matched total relative hits; do
    framework.console.output::newline
    framework.console.output::line "  $relative"
    framework.console.output::detail " matched $matched of ${#terms[@]} terms ($(framework.helpers.text::plural "$total" line)): $hits"
    print_field "$BASE/$relative" description
    [ "$lines" -gt 0 ] || continue
    core.modules.decisions.service::matching_lines "$BASE/$relative" "$lines" "${terms[@]}" | sed 's/^/      /'
  done <<< "$results"
  framework.console.output::newline
}

handle() {
  local work terms references cited_by=false scope=all lines="$IMPACT_DEFAULT_LINES" reference
  framework.helpers.fs::make_temp_dir work || framework.console.output::fail "Couldn't create a temporary directory; please check free space and \$TMPDIR."
  terms="$work/terms"
  references="$work/references"
  : > "$terms"
  : > "$references"
  while [ $# -gt 0 ]; do
    case "$1" in
      --term) framework.console.args::require_value "$@"; add_items "$terms" "$(framework.console.args::split "$2")"; shift 2 ;;
      --cited-by) cited_by=true; shift ;;
      --scope) framework.console.args::require_value "$@"; scope="$2"; shift 2 ;;
      --lines) framework.console.args::require_value "$@"; lines="$2"; shift 2 ;;
      -*) framework.console.args::unexpected "$1" ;;
      *) add_items "$references" "$(framework.console.args::split "$1")"; shift ;;
    esac
  done
  [ -s "$terms" ] || [ -s "$references" ] \
    || framework.console.args::invalid "What should it look for? Please give a decision, or --term."
  ! $cited_by || [ -s "$references" ] || framework.console.args::invalid "--cited-by needs a decision to look for."
  [[ "$IMPACT_SCOPES" == *" $scope "* ]] || framework.console.args::invalid "--scope takes all, features or decisions (got $scope)."
  framework.console.args::is_number "$lines" || framework.console.args::invalid "--lines takes a whole number (got $lines)."
  if $cited_by; then
    while IFS= read -r reference; do
      report_inbound "$reference"
    done < "$references"
  elif [ -s "$references" ]; then
    report_citations "$references"
  fi
  [ ! -s "$terms" ] || report_terms "$terms" "$scope" "$lines"
}
