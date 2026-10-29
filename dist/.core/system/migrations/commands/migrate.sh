#!/usr/bin/env bash

DESCRIPTION="Upgrade dotdot's own files to this version's format."
DOCS="updating-dotdot"

dot::use framework.console.args framework.console.output framework.console.prompt framework.helpers.json framework.helpers.text

usage() {
  cat <<USAGE
Runs the migrations still pending, in order: each converts a file dotdot keeps
in $DOTDOT_NAME/ from an older format. While one is pending, every command but
upgrade asks for this one first.

Usage:
  bash dot migrate [-y, --yes]

Options:
  -y, --yes      Run without asking. Only at a terminal, or when dotdot itself
                 runs it.
  -h, --help     Show this help.

Notes:
  - state.migrations in $(dot::relative "$SETTINGS_FILE") lists the migrations applied.
USAGE
}

handle() {
  local confirmed=false quiet=false file pending=()
  while [ $# -gt 0 ]; do
    case "$1" in
      -y | --yes) confirmed=true ;;
      --if-pending) quiet=true ;;
      *) framework.console.args::unexpected "$1" ;;
    esac
    shift
  done
  while IFS= read -r file; do
    pending+=("$file")
  done < <(kernel::pending_migrations)
  if [ ${#pending[@]} -eq 0 ]; then
    $quiet || framework.console.output::success "Everything is up to date; nothing to migrate."
    return 0
  fi
  framework.console.output::line "These migrations will run:"
  for file in "${pending[@]}"; do
    framework.console.output::entry blue "$UI_SEPARATOR" "${file##*/}" "$(kernel::description "$file")"
  done
  if $confirmed; then
    guards::skip_confirmation || framework.console.output::fail_as "$EXIT_PRECONDITION" "-y only works in a terminal, so nothing ran unseen." "$OUTPUT_MANUAL_RUN bash dot migrate"
    framework.console.output::line "Migrating (-y)…"
  else
    framework.console.prompt::confirm_or_exit "Do you want to run $(framework.helpers.text::plural "${#pending[@]}" migration)?" n "bash dot migrate"
  fi
  for file in "${pending[@]}"; do
    ( . "$file"; migrate ) || framework.console.output::fail "${file##*/} didn't finish, so the ones after it didn't run." "Please fix the errors above, then run: bash dot migrate"
    record "${file##*/}"
    framework.console.output::success "${file##*/}"
  done
}

# Adds a migration to state.migrations.
record() {
  local applied list
  applied=$(dot::setting state.migrations "[]") && applied=$(framework.helpers.json::values "$applied" '.[]') \
    || framework.console.output::fail "${1%.sh} ran, but couldn't be recorded in $(dot::relative "$SETTINGS_FILE") (state.migrations); it may run again next time."
  list=$({ [ -z "$applied" ] || printf '%s\n' "$applied"; printf '%s\n' "${1%.sh}"; } | framework.helpers.json::lines | paste -sd, -)
  dot::save_setting state.migrations "[$list]" \
    || framework.console.output::fail "${1%.sh} ran, but couldn't be recorded in $(dot::relative "$SETTINGS_FILE") (state.migrations); it may run again next time."
}
