#!/usr/bin/env bash

DESCRIPTION="Print just the frontmatter of dotdot's docs."

dot::use framework.console.args framework.helpers.frontmatter framework.helpers.fs framework.console.output

SCAN_MISSING_FRONTMATTER="(no frontmatter)"

usage() {
  cat <<EOF
Prints each Markdown file's frontmatter, without its body, so a directory of
docs can be surveyed cheaply before reading any of them in full.

Usage:
  bash dot scan:frontmatter <path>

Arguments:
  <path>       A directory (every *.md directly in it) or one Markdown file,
               inside $DOTDOT_NAME/; relative to $DOTDOT_NAME/ wherever you run it.

Options:
  -h, --help   Show this help.

Examples:
  bash dot scan:frontmatter Features
  bash dot scan:frontmatter Decisions/d002--no-soft-deletes.md

Notes:
  - A file without frontmatter shows as $SCAN_MISSING_FRONTMATTER.
EOF
}

print_frontmatter() {
  local file="$1" label="$2"
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
    ! $found || framework.console.output::rule
    found=true
    print_frontmatter "$file" "$label/$(basename -- "$file")"
  done
  $found || framework.console.output::line "No Markdown files in $label."
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
    scan_directory "$target" "$label"
  elif [ -f "$target" ]; then
    case "$label" in
      *.md) print_frontmatter "$target" "$label" ;;
      *) framework.console.output::fail "$label isn't a Markdown file." ;;
    esac
  else
    framework.console.output::fail "$label isn't a directory or Markdown file."
  fi
}
