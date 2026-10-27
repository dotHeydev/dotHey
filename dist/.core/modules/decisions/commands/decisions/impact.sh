#!/usr/bin/env bash

DESCRIPTION="Find what a decision touches: citing features, related docs, and the decisions citing it."

dot::use framework.console.args core.modules.decisions.service framework.helpers.frontmatter framework.helpers.fs framework.console.output framework.helpers.record framework.helpers.text

IMPACT_DEFAULT_LINES=3
IMPACT_SCOPES=" all features decisions "

usage() {
  cat <<EOF
bash dot decisions:impact — find the documented features a proposed decision would
affect, and the existing decisions that bear on it.

A decision is only safe to write down once you know what it collides with, and
only stays trustworthy while its links still point at real files. This answers it three ways (decisions:check keeps the links honest):

  <decision>    Which features cite these decisions in their "$FEATURE_DECISIONS_HEADING"
                section? That is a declared link rather than a guess, so run it
                first: once you know which existing decisions influence the new
                one, the features already built against them are the ones most
                likely to be contradicted.

  --term        Which features and decisions mention these things at all? The
                wider net for what declared links miss — nothing forces a
                feature to cite the decision it actually depends on.

  --cited-by    Which decisions point at <decision> — because it superseded
                them, or because it shaped them? Every edge between decisions is
                stored once, on the decision that declares it, so the reverse
                direction is derived here rather than written into both files
                where the two copies could disagree.

They combine in one invocation. The output is bounded either way: a raw grep
over Features/ and Decisions/ returns either everything or nothing useful, and
reading whole feature docs to find out costs far more context than the answer
is worth.

Usage:
  bash dot decisions:impact <decision>[,<decision>...] [--term <text>[,...]]... [--scope all|features|decisions] [--lines <n>]
  bash dot decisions:impact --term <text>[,<text>...]... [--scope all|features|decisions] [--lines <n>]
  bash dot decisions:impact <decision> --cited-by
  bash dot decisions:impact --help

Arguments:
  <decision>        Decision references, comma-separated or one per argument.
                    Accepts "2", "002", or "d002--no-soft-deletes.md".

Optional:
  --term <text>     Search terms, comma-separated. Repeatable.
  --cited-by        Report the decisions listing <decision> in any of their
                    link sections, with the section that names it.
  --scope <what>    features | decisions | all   (default: all). Applies to
                    the term search only.
  --lines <n>       Matching lines to show per file (default: $IMPACT_DEFAULT_LINES, 0 for none).

Examples:
  bash dot decisions:impact 002,005
  bash dot decisions:impact --term session,jwt,cookie --scope features
  bash dot decisions:impact 004 --cited-by
  bash dot decisions:impact 002 --term session,jwt

Notes:
  - A decision reference is resolved against Decisions/ and must exist,
    so a typo is reported rather than silently returning no citations.
  - Terms match as case-insensitive literal substrings, so "auth" also hits
    "authorize" and "OAuth". Prefer several precise terms over one broad one:
    files are ranked by how many distinct terms they match.
  - A file matching nothing is not listed. No output at all means the decision
    touches nothing already documented — a real answer, and a useful one.
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
  ! $cited_by || [ -s "$references" ] || framework.console.args::invalid "--cited-by needs the decision it looks for, e.g. bash dot decisions:impact 004 --cited-by."
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
