#!/usr/bin/env bash

DESCRIPTION="Link dotdot and its plugins where your agents read them."

dot::use framework.console.args framework.console.output framework.console.prompt framework.helpers.fs framework.helpers.json framework.helpers.text core.system.link.service

usage() {
  cat <<EOF
Seeds $DOTDOT_NAME/USER.md, then links and appends what the "links" in
$(dot::relative "$SETTINGS_FILE") list. It previews every change and asks before applying any.

Usage:
  bash dot link [--replace-existing] [-v, --verbose] [-y, --yes]

Options:
  --replace-existing   Replace destinations that already exist: a symlink is
                       replaced, a file is backed up as <name>.bak-<time> first.
                       A real directory is always skipped.
  -v, --verbose        List the entries that stay as they are, too.
  -y, --yes            Apply without asking. Only at a terminal, or when dotdot
                       itself runs it.
  -h, --help           Show this help.

For dotdot's own plugin commands:
  --refresh-plugin <owner>/<name>   Write the plugin's suggested links afresh,
                                    under "inactive".
  --settings-only                   Write $(dot::relative "$SETTINGS_FILE") only; link nothing.
  --remove-uninstalled              Take back only what removed plugins left.

Examples:
  bash dot link
  bash dot link --replace-existing
  bash dot link -v

The links:
  "<origin>": ["<destination>", ...]   symlink each destination to the origin
  "append": {"<origin>": [...]}        append the file to each destination,
                                       between markers naming its owner
  "remove": {"<origin>": [...]}        unlink, and take back what it appended
  "<owner>/<name>": {...}              a plugin's active links, same shape
  "inactive": {"<owner>/<name>": ...}  a plugin's links, never applied until
                                       bash dot link:activate takes them

  Origins: @dot:<path>, @module:<name>:<path>, @plugin:<owner>.<name>:<path>,
  @dotdotSkills, @dotdotAgents, @pluginsSkills, @pluginsAgents; a /* ending
  links each entry inside. Destinations are project paths outside $DOTDOT_NAME/
  and .git/, never .env; appends may also go to @dot:<Doc>.md. When two entries
  claim one destination, your own links win, then the first declared.

Notes:
  - Run it after installing dotdot, creating a git worktree, or adding,
    renaming or removing anything the links cover. Re-running is safe.
  - Links are relative, so they survive a clone, a move or a rebuild.
  - bash dot link -v lists every current link.
EOF
}

LINK_VERBOSE=false

# An entry that stays as it is, listed only with --verbose.
unchanged_entry() {
  ! $LINK_VERBOSE || framework.console.output::entry dim "·" "$@"
}

# A link's line: its origin → its destination.
link_entry() {
  local origin="$1" label="$2"
  case "$3" in
    link) framework.console.output::entry blue "~" "$(dot::relative "$origin") → $label" ;;
    ok) unchanged_entry "$label" "already linked" ;;
    move) framework.console.output::entry blue "~" "$(dot::relative "$origin") → $label" "moved; relink" ;;
    prune) framework.console.output::entry red "-" "$label" "broken; remove" ;;
    unlink) framework.console.output::entry red "-" "$label" "no longer listed; unlink" ;;
    skip) framework.console.output::entry yellow "!" "$label" "exists; skip" ;;
    relink) framework.console.output::entry red "!" "$label" "exists; replace" ;;
    backup) framework.console.output::entry red "!" "$label" "exists; back up and replace" ;;
  esac
}

# An append's line: its origin > its destination, in <owner>'s section.
append_entry() {
  local origin="$1" label="$2" owner="$3"
  case "$4" in
    append) framework.console.output::entry blue ">" "$(dot::relative "$origin") → $label" "section of $owner" ;;
    appended) unchanged_entry "$label" "section of $owner already appended" ;;
    unappend) framework.console.output::entry red "-" "$label" "take back the section of $owner" ;;
    create) framework.console.output::entry green "+" "$label" "from $(dot::relative "$origin")" ;;
    exists) unchanged_entry "$label" "exists; keep" ;;
  esac
}

# An edit of the links in dot.json.
map_entry() {
  case "$1" in
    remove*) framework.console.output::entry red "-" "$(dot::relative "$SETTINGS_FILE")" "$1" ;;
    *) framework.console.output::entry green "+" "$(dot::relative "$SETTINGS_FILE")" "$1" ;;
  esac
}

print_seeds() {
  local note
  for note in ${LINK_MAP_NOTES[@]+"${LINK_MAP_NOTES[@]}"}; do
    map_entry "$note"
  done
  case "$(core.system.link.service::user_state)" in
    create) framework.console.output::entry green "+" "$DOTDOT_NAME/USER.md" "from USER.example.md" ;;
    existing) unchanged_entry "$DOTDOT_NAME/USER.md" "exists; keep" ;;
  esac
}

# Each planned change, as a line.
print_changes() {
  local index
  print_seeds
  for index in ${LINK_ACTIONS[@]+"${!LINK_ACTIONS[@]}"}; do
    link_entry "${LINK_ORIGINS[$index]}" "${LINK_LABELS[$index]}" "${LINK_ACTIONS[$index]}"
  done
  for index in ${LINK_APPEND_ACTIONS[@]+"${!LINK_APPEND_ACTIONS[@]}"}; do
    append_entry "${LINK_APPEND_ORIGINS[$index]}" "${LINK_APPEND_LABELS[$index]}" "${LINK_APPEND_MARKERS[$index]}" "${LINK_APPEND_ACTIONS[$index]}"
  done
}

print_notices() {
  local index
  for index in ${LINK_NOTICES[@]+"${!LINK_NOTICES[@]}"}; do
    framework.console.output::warn "${LINK_NOTICES[$index]}"
  done
  [ "$LINK_OVERRIDABLE" -eq 0 ] \
    || framework.console.output::next "To replace the $LINK_OVERRIDABLE taken destination(s) above, run bash dot link --replace-existing (files are backed up first)."
}

print_errors() {
  local message
  for message in ${LINK_ERRORS[@]+"${LINK_ERRORS[@]}"}; do
    framework.console.output::error "$message"
  done
  LINK_ERRORS=()
}

# What was done, its non-zero counts only.
print_result() {
  local warning counts=() count label
  print_errors
  for count in "$LINK_LINKED|linked" "$LINK_REMOVED|removed" "$LINK_APPENDED|appended" "$LINK_UNAPPENDED|taken back" "$LINK_SKIPPED|skipped"; do
    label="${count#*|}"
    count="${count%%|*}"
    [ "$count" -eq 0 ] || counts+=("$count $label")
  done
  label=$(IFS='|'; printf '%s' "${counts[*]-}")
  label="${label//|/ $OUTPUT_SEPARATOR }"
  if [ "$LINK_FAILURES" -eq 0 ]; then
    framework.console.output::success "Done${label:+: $label}."
  else
    framework.console.output::error "$(framework.helpers.text::plural "$LINK_FAILURES" change) failed${label:+ ($label)}."
  fi
  for warning in ${LINK_WARNINGS[@]+"${LINK_WARNINGS[@]}"}; do
    framework.console.output::warn "$warning"
  done
}

# At a terminal, offers to merge each key the links define twice, so every
# destination is kept; one that can't be merged is left to the user.
offer_merge() {
  local notice merged
  framework.console.prompt::can_ask && core.system.link.service::has_map || return 0
  core.system.link.service::note_duplicates
  [ ${#LINK_NOTICES[@]} -gt 0 ] || return 0
  for notice in "${LINK_NOTICES[@]}"; do
    framework.console.output::warn "$notice"
  done
  LINK_NOTICES=()
  if ! merged=$(framework.helpers.json::merge_duplicates "$(cat -- "$SETTINGS_FILE")" links); then
    framework.console.output::line "These can't be merged automatically; please merge them by hand."
    return 0
  fi
  framework.console.prompt::confirm "Do you want to merge them in $(dot::relative "$SETTINGS_FILE"), keeping every destination?" n || return 0
  printf '%s\n' "$merged" | framework.helpers.fs::write "$SETTINGS_FILE" \
    || framework.console.output::fail "Couldn't write $(dot::relative "$SETTINGS_FILE"); please check that it's writable."
  framework.console.output::success "Merged them in $(dot::relative "$SETTINGS_FILE")."
}

map_only() {
  local confirmed="$1" refresh="$2" note
  core.system.link.service::prepare_map "$refresh" true
  print_errors
  if [ ${#LINK_MAP_NOTES[@]} -eq 0 ]; then
    framework.console.output::success "The links are up to date."
    return 0
  fi
  framework.console.output::line "bash dot link will:"
  for note in "${LINK_MAP_NOTES[@]}"; do
    map_entry "$note"
  done
  if $confirmed; then
    framework.console.output::line "Writing $(dot::relative "$SETTINGS_FILE") (-y)…"
  else
    framework.console.prompt::confirm_or_exit "Do you want to write $(dot::relative "$SETTINGS_FILE")?" n "bash dot link --settings-only"
  fi
  core.system.link.service::save_map
  print_errors
  [ "$LINK_FAILURES" -eq 0 ]
}

handle() {
  local override=false confirmed=false refresh="" only_map=false sweep=false
  while [ $# -gt 0 ]; do
    case "$1" in
      --replace-existing) override=true ;;
      --settings-only) only_map=true ;;
      --remove-uninstalled) sweep=true ;;
      -v | --verbose) LINK_VERBOSE=true ;;
      -y | --yes) confirmed=true ;;
      --refresh-plugin)
        framework.console.args::require_value "$@"
        [[ "$2" =~ ^[a-z0-9][a-z0-9-]*/[a-z0-9][a-z0-9-]*$ ]] || framework.console.args::invalid "--refresh-plugin needs a plugin as <owner>/<name> (got $2)."
        refresh="$refresh $2"
        shift
        ;;
      *) framework.console.args::unexpected "$1" ;;
    esac
    shift
  done
  ! $confirmed || guards::skip_confirmation \
    || framework.console.output::fail "-y only works in a terminal, so nothing changed unseen." "$OUTPUT_MANUAL_RUN bash dot link"
  if $only_map; then
    map_only "$confirmed" "$refresh"
    return
  fi
  if $sweep; then
    core.system.link.service::plan_sweep
  else
    $confirmed || offer_merge
    core.system.link.service::plan "$override" "$refresh"
  fi
  core.system.link.service::count_changes
  print_errors
  if $sweep; then
    core.system.link.service::apply
    print_changes
    print_errors
    [ "$LINK_FAILURES" -eq 0 ]
    return
  fi
  if [ "$LINK_CHANGES" -eq 0 ]; then
    ! $LINK_VERBOSE || print_changes
    print_notices
    [ "$LINK_FAILURES" -gt 0 ] || framework.console.output::success "Everything is already linked."
    [ "$LINK_FAILURES" -eq 0 ]
    return
  fi
  framework.console.output::line "bash dot link will:"
  print_changes
  print_notices
  if $confirmed; then
    framework.console.output::line "Applying $(framework.helpers.text::plural "$LINK_CHANGES" change) (-y)…"
  else
    framework.console.prompt::confirm_or_exit "Do you want to apply $(framework.helpers.text::plural "$LINK_CHANGES" change)?" n "bash dot link"
  fi
  core.system.link.service::apply
  print_result
  [ "$LINK_FAILURES" -eq 0 ]
}
