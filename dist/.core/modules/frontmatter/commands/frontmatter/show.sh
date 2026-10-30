# shellcheck shell=bash

DESCRIPTION="Print just the frontmatter of dotdot's docs."
JSON=true

dot::use framework.console.args framework.helpers.frontmatter framework.helpers.fs framework.console.output framework.helpers.json framework.ui.rule

SCAN_MISSING_FRONTMATTER="(no frontmatter)"

usage() {
  cat <<EOF
Prints each Markdown file's frontmatter, without its body, so a directory of
docs can be surveyed cheaply before reading any of them in full.

Usage:
  bash dot frontmatter:show <path>

Arguments:
  <path>       A directory (every *.md directly in it) or one Markdown file,
               inside $DOTDOT_NAME/; relative to $DOTDOT_NAME/ wherever you run it.

Options:
  --json       [{"file", "frontmatter": {<key>: <value>} or null}], one per file.
  -h, --help   Show this help.

Examples:
  bash dot frontmatter:show Features
  bash dot frontmatter:show Decisions/d002--no-soft-deletes.md

Notes:
  - A file without frontmatter shows as $SCAN_MISSING_FRONTMATTER.
EOF
}

# <file>'s frontmatter as a JSON object of its "key: value" lines (a line
# without a key continues the value above), or null without one.
frontmatter_json() {
  local line key="" value="" pairs=""
  framework.helpers.frontmatter::exists "$1" || { printf 'null'; return; }
  while IFS= read -r line; do
    if [[ "$line" =~ ^([A-Za-z0-9_-]+):[[:space:]]*(.*)$ ]]; then
      [ -z "$key" ] || pairs="$pairs${pairs:+,}$(framework.helpers.json::string "$key"):$(framework.helpers.json::string "$value")"
      key="${BASH_REMATCH[1]}"
      value="${BASH_REMATCH[2]}"
      [[ ! "$value" =~ ^\"(.*)\"$ ]] || value="${BASH_REMATCH[1]}"
    elif [ -n "$key" ] && [ "$line" != --- ]; then
      value="$value${value:+$'\n'}$line"
    fi
  done < <(framework.helpers.frontmatter::block "$1")
  [ -z "$key" ] || pairs="$pairs${pairs:+,}$(framework.helpers.json::string "$key"):$(framework.helpers.json::string "$value")"
  printf '{%s}' "$pairs"
}

print_frontmatter() {
  local file="$1" label="$2"
  if $DOT_JSON; then
    printf '{"file":%s,"frontmatter":%s}\n' "$(framework.helpers.json::string "$label")" "$(frontmatter_json "$file")"
    return
  fi
  framework.console.output::line "$label"
  if framework.helpers.frontmatter::exists "$file"; then
    framework.helpers.frontmatter::block "$file"
  else
    framework.console.output::line "$SCAN_MISSING_FRONTMATTER"
  fi
}

scan_directory() {
  local directory="$1" label="$2" file found=false
  for file in "$directory"/*.md; do
    [ -e "$file" ] || continue
    if ! framework.helpers.fs::within "$file" "$DOTDOT_ROOT" >/dev/null; then
      framework.console.output::warn "Skipped $label/$(basename -- "$file"): it leads outside $DOTDOT_NAME/."
      continue
    fi
    $DOT_JSON || ! $found || framework.ui.rule::show
    found=true
    print_frontmatter "$file" "$label/$(basename -- "$file")"
  done
  $found || $DOT_JSON || framework.console.output::line "No Markdown files in $label."
}

handle() {
  local label target
  [ $# -eq 1 ] || framework.console.args::invalid "Please give one directory or Markdown file in $DOTDOT_NAME/."
  label="$1"
  while [ "${label%/}" != "$label" ] && [ "$label" != "/" ]; do
    label="${label%/}"
  done
  target=$(framework.helpers.fs::within "$(paths::in_dotdot "$label")" "$DOTDOT_ROOT") \
    || framework.console.output::fail "$label is outside $DOTDOT_NAME/."
  if [ -d "$target" ]; then
    if $DOT_JSON; then
      printf '[%s]\n' "$(scan_directory "$target" "$label" | paste -sd ',' -)"
    else
      scan_directory "$target" "$label"
    fi
  elif [ -f "$target" ]; then
    case "$label" in
      *.md) if $DOT_JSON; then printf '[%s]\n' "$(print_frontmatter "$target" "$label")"; else print_frontmatter "$target" "$label"; fi ;;
      *) framework.console.output::fail_as "$EXIT_USAGE" "$label isn't a Markdown file." ;;
    esac
  else
    framework.console.output::fail_as "$EXIT_NOT_FOUND" "$label isn't a directory or Markdown file."
  fi
}
