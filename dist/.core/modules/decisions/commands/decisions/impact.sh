#!/usr/bin/env bash

DESCRIPTION="Find what a decision touches."
DOCS="decisions"
JSON=true

dot::use framework.console.args core.modules.decisions.service framework.helpers.frontmatter framework.helpers.fs framework.console.output framework.helpers.record framework.helpers.text framework.helpers.json

IMPACT_DEFAULT_LINES=3
IMPACT_SCOPES=" all features decisions "

usage() {
  cat <<EOF
Finds the features that cite decisions and the docs that mention its terms,
so you know what a new decision collides with.

Usage:
  bash dot decisions:impact <decision>[,...] [--term <text>[,...]]... [options]
  bash dot decisions:impact --term <text>[,...]... [options]

Arguments:
  <decision>       Decisions, as 2, 002, or their file name; comma-separated or
                   one per argument. Lists the features citing them under
                   "$FEATURE_DECISIONS_HEADING".

Options:
  --term <text>    Terms to look for in features and decisions, comma-separated;
                   repeatable. Case-insensitive, and "auth" also finds "OAuth".
  --scope <what>   all, features or decisions (default: all), for --term.
  --lines <n>      Matching lines shown per file (default: $IMPACT_DEFAULT_LINES; 0 for none).
  --json           {"features": [{"path", "cites", "description"}] or null,
                   "terms": [{"path", "matched", "lines", "hits", "description",
                   "matches"}] or null}.
  -h, --help       Show this help.

Examples:
  bash dot decisions:impact 002,005
  bash dot decisions:impact --term session,jwt,cookie --scope features

Notes:
  - Files are ranked by how many terms they match; prefer several precise terms.
  - No output means nothing documented is touched: a real answer.
  - bash dot decisions:citers lists the decisions that point at one.
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

print_field() {
  local value
  value=$(framework.helpers.frontmatter::field "$1" "$2")
  [ -z "$value" ] || framework.console.output::detail " $2: $value"
}

report_citations() {
  local references_file="$1" reference file decisions=() feature cited found=false
  while IFS= read -r reference; do
    file=$(core.modules.decisions.service::find "$reference") || framework.console.output::fail_as "$EXIT_NOT_FOUND" "No decision matches \"$reference\"." "See them all: bash dot frontmatter:show Decisions"
    decisions+=("$file")
  done < "$references_file"
  if $DOT_JSON; then
    while IFS=$'\t' read -r feature cited; do
      printf '{"path":%s,"cites":%s,"description":%s}\n' "$(framework.helpers.json::string "$(dot::relative "$FEATURES_DIR")/$feature")" \
        "$(framework.helpers.json::string "$cited")" "$(framework.helpers.json::string "$(framework.helpers.frontmatter::field "$FEATURES_DIR/$feature" description)")"
    done < <(core.modules.decisions.service::citing_features "${decisions[@]}")
    return
  fi
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
  if $DOT_JSON; then
    [ -n "$results" ] || return 0
    while IFS=$'\t' read -r matched total relative hits; do
      printf '{"path":%s,"matched":%s,"lines":%s,"hits":%s,"description":%s,"matches":[%s]}\n' "$(framework.helpers.json::string "$relative")" \
        "$matched" "$total" "$(framework.helpers.json::string "$hits")" "$(framework.helpers.json::string "$(framework.helpers.frontmatter::field "$BASE/$relative" description)")" \
        "$([ "$lines" -eq 0 ] || core.modules.decisions.service::matching_lines "$BASE/$relative" "$lines" "${terms[@]}" | framework.helpers.json::lines | paste -sd ',' -)"
    done <<< "$results"
    return
  fi
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
  local work terms references scope=all lines="$IMPACT_DEFAULT_LINES"
  framework.helpers.fs::make_temp_dir work || framework.console.output::fail "Couldn't create a temporary directory; please check free space and \$TMPDIR."
  terms="$work/terms"
  references="$work/references"
  : > "$terms"
  : > "$references"
  while [ $# -gt 0 ]; do
    case "$1" in
      --term) framework.console.args::require_value "$@"; add_items "$terms" "$(framework.console.args::split "$2")"; shift 2 ;;
      --scope) framework.console.args::require_value "$@"; scope="$2"; shift 2 ;;
      --lines) framework.console.args::require_value "$@"; lines="$2"; shift 2 ;;
      -*) framework.console.args::unexpected "$1" ;;
      *) add_items "$references" "$(framework.console.args::split "$1")"; shift ;;
    esac
  done
  [ -s "$terms" ] || [ -s "$references" ] \
    || framework.console.args::invalid "What should it look for? Please give a decision, or --term."
  [[ "$IMPACT_SCOPES" == *" $scope "* ]] || framework.console.args::invalid "--scope takes all, features or decisions (got $scope)."
  framework.console.args::is_number "$lines" || framework.console.args::invalid "--lines takes a whole number (got $lines)."
  if $DOT_JSON; then
    local features=null found=null
    if [ -s "$references" ]; then
      features=$(report_citations "$references") || exit
      features="[$(printf '%s\n' "$features" | paste -sd ',' -)]"
    fi
    if [ -s "$terms" ]; then
      found=$(report_terms "$terms" "$scope" "$lines") || exit
      found="[$(printf '%s\n' "$found" | paste -sd ',' -)]"
    fi
    printf '{"features":%s,"terms":%s}\n' "$features" "$found"
    return
  fi
  [ ! -s "$references" ] || report_citations "$references"
  [ ! -s "$terms" ] || report_terms "$terms" "$scope" "$lines"
}
