#!/usr/bin/env bash

DESCRIPTION="Bring dotdot's own files (the link map, the plugins lock) up to this version's format."

dot::use framework.console.args framework.console.output framework.console.prompt framework.helpers.json framework.helpers.text

usage() {
  cat <<USAGE
bash dot $DOT_COMMAND — run the migrations still pending: each moves or
converts a file dotdot keeps (in $(dot::relative "$DOTDOT_ROOT")/) from an older version's
format into this one's. They live in $(dot::relative "$SYSTEM_DIR")/migrations/,
one per file, and run in order. state.migrations in $(dot::relative "$SETTINGS_FILE") lists those
applied; a migration it doesn't list is pending (all of them when it is
missing, as in an install from before migrations; the installer lists every
one).

While one is pending, every other command but update stops and asks for this
one, so nothing reads a file in a format it no longer knows. bash dot update
offers to run it afterwards.

Previews what would run, then asks [y/N] at a terminal; -y skips the question
at a terminal or when dotdot itself makes the call.

--when-pending prints nothing when there is nothing to migrate; bash dot
update calls it right after updating the core.

Usage:
  bash dot $DOT_COMMAND [-y] [--when-pending]
  bash dot $DOT_COMMAND --help
USAGE
}

handle() {
  local confirmed=false quiet=false file pending=()
  while [ $# -gt 0 ]; do
    case "$1" in
      -y | --yes) confirmed=true ;;
      --when-pending) quiet=true ;;
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
  framework.console.output::line "bash dot migrate will run:"
  for file in "${pending[@]}"; do
    framework.console.output::entry blue "$OUTPUT_SEPARATOR" "${file##*/}" "$(kernel::description "$file")"
  done
  if $confirmed; then
    guards::skip_confirmation || framework.console.output::fail "-y only works in a terminal, so nothing ran unseen." "$OUTPUT_MANUAL_RUN bash dot migrate"
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
