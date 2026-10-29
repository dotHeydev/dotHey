#!/usr/bin/env bash

dot::use framework.console.args framework.console.output framework.console.prompt framework.helpers.json framework.helpers.text core.system.link.service

LINK_VERBOSE=false

# An entry that stays as it is, listed only with --verbose.
core.system.link.console::unchanged_entry() {
  ! $LINK_VERBOSE || framework.console.output::entry dim "$UI_MARK_UNCHANGED" "$@"
}

# A link's line: its origin → its destination.
core.system.link.console::link_entry() {
  local origin="$1" label="$2"
  case "$3" in
    link) framework.console.output::entry blue "$UI_MARK_LINKED" "$(dot::relative "$origin") $UI_ARROW $label" ;;
    ok) core.system.link.console::unchanged_entry "$label" "already linked" ;;
    move) framework.console.output::entry blue "$UI_MARK_LINKED" "$(dot::relative "$origin") $UI_ARROW $label" "moved; relink" ;;
    prune) framework.console.output::entry red "$UI_MARK_REMOVED" "$label" "broken; remove" ;;
    unlink) framework.console.output::entry red "$UI_MARK_REMOVED" "$label" "no longer listed; unlink" ;;
    skip) framework.console.output::entry yellow "$UI_MARK_TAKEN" "$label" "exists; skip" ;;
    relink) framework.console.output::entry red "$UI_MARK_TAKEN" "$label" "exists; replace" ;;
    backup) framework.console.output::entry red "$UI_MARK_TAKEN" "$label" "exists; back up and replace" ;;
  esac
}

# An append's line: its origin > its destination, in <owner>'s section.
core.system.link.console::append_entry() {
  local origin="$1" label="$2" owner="$3"
  case "$4" in
    append) framework.console.output::entry blue "$UI_MARK_APPENDED" "$(dot::relative "$origin") $UI_ARROW $label" "section of $owner" ;;
    appended) core.system.link.console::unchanged_entry "$label" "section of $owner already appended" ;;
    unappend) framework.console.output::entry red "$UI_MARK_REMOVED" "$label" "take back the section of $owner" ;;
    create) framework.console.output::entry green "$UI_MARK_ADDED" "$label" "from $(dot::relative "$origin")" ;;
    exists) core.system.link.console::unchanged_entry "$label" "exists; keep" ;;
  esac
}

# An edit of the links in dot.json.
core.system.link.console::map_entry() {
  case "$1" in
    remove*) framework.console.output::entry red "$UI_MARK_REMOVED" "$(dot::relative "$SETTINGS_FILE")" "$1" ;;
    *) framework.console.output::entry green "$UI_MARK_ADDED" "$(dot::relative "$SETTINGS_FILE")" "$1" ;;
  esac
}

core.system.link.console::print_seeds() {
  local note
  for note in ${LINK_MAP_NOTES[@]+"${LINK_MAP_NOTES[@]}"}; do
    core.system.link.console::map_entry "$note"
  done
  case "$(core.system.link.service::user_state)" in
    create) framework.console.output::entry green "$UI_MARK_ADDED" "$DOTDOT_NAME/USER.md" "from USER.example.md" ;;
    existing) core.system.link.console::unchanged_entry "$DOTDOT_NAME/USER.md" "exists; keep" ;;
  esac
}

# Each planned change, as a line.
core.system.link.console::print_changes() {
  local index
  core.system.link.console::print_seeds
  for index in ${LINK_ACTIONS[@]+"${!LINK_ACTIONS[@]}"}; do
    core.system.link.console::link_entry "${LINK_ORIGINS[$index]}" "${LINK_LABELS[$index]}" "${LINK_ACTIONS[$index]}"
  done
  for index in ${LINK_APPEND_ACTIONS[@]+"${!LINK_APPEND_ACTIONS[@]}"}; do
    core.system.link.console::append_entry "${LINK_APPEND_ORIGINS[$index]}" "${LINK_APPEND_LABELS[$index]}" "${LINK_APPEND_MARKERS[$index]}" "${LINK_APPEND_ACTIONS[$index]}"
  done
}

core.system.link.console::print_notices() {
  local index
  for index in ${LINK_NOTICES[@]+"${!LINK_NOTICES[@]}"}; do
    framework.console.output::warn "${LINK_NOTICES[$index]}"
  done
  [ "$LINK_OVERRIDABLE" -eq 0 ] \
    || framework.console.output::next "To replace the $LINK_OVERRIDABLE taken destination(s) above, run ${LINK_OVERWRITE_COMMAND:-bash dot link} --overwrite (files are backed up first)."
}

core.system.link.console::print_errors() {
  local message
  for message in ${LINK_ERRORS[@]+"${LINK_ERRORS[@]}"}; do
    if [ "${message#*$LINK_TAB}" != "$message" ]; then
      framework.console.output::error "${message%%$LINK_TAB*}" "${message#*$LINK_TAB}"
    else
      framework.console.output::error "$message"
    fi
  done
  LINK_ERRORS=()
}

# The planned changes as JSON: each link, append, and seed that changes
# something or is skipped, and how many destinations are taken.
core.system.link.console::print_json_plan() {
  local index changes=""
  ! $LINK_SEED_USER || changes=$(core.system.link.console::json_change create "$(dot::relative "$USER_EXAMPLE_FILE")" "$DOTDOT_NAME/USER.md")
  for index in ${LINK_ACTIONS[@]+"${!LINK_ACTIONS[@]}"}; do
    core.system.link.service::is_change "${LINK_ACTIONS[$index]}" || [ "${LINK_ACTIONS[$index]}" = skip ] || continue
    changes="$changes${changes:+,}$(core.system.link.console::json_change "${LINK_ACTIONS[$index]}" "$(dot::relative "${LINK_ORIGINS[$index]}")" "${LINK_LABELS[$index]}")"
  done
  for index in ${LINK_APPEND_ACTIONS[@]+"${!LINK_APPEND_ACTIONS[@]}"}; do
    core.system.link.service::is_change "${LINK_APPEND_ACTIONS[$index]}" || continue
    changes="$changes${changes:+,}$(core.system.link.console::json_change "${LINK_APPEND_ACTIONS[$index]}" "$(dot::relative "${LINK_APPEND_ORIGINS[$index]}")" "${LINK_APPEND_LABELS[$index]}")"
  done
  printf '{"changes":[%s],"taken":%s}\n' "$changes" "$LINK_OVERRIDABLE"
}

core.system.link.console::json_change() {
  printf '{"action":%s,"origin":%s,"destination":%s}' "$(framework.helpers.json::string "$1")" "$(framework.helpers.json::string "$2")" "$(framework.helpers.json::string "$3")"
}

# What was done, as JSON counts.
core.system.link.console::print_json_result() {
  printf '{"linked":%s,"removed":%s,"appended":%s,"takenBack":%s,"skipped":%s,"failed":%s}\n' \
    "$LINK_LINKED" "$LINK_REMOVED" "$LINK_APPENDED" "$LINK_UNAPPENDED" "$LINK_SKIPPED" "$LINK_FAILURES"
}

# What was done, its non-zero counts only.
core.system.link.console::print_result() {
  local warning counts=() count label
  core.system.link.console::print_errors
  for count in "$LINK_LINKED|linked" "$LINK_REMOVED|removed" "$LINK_APPENDED|appended" "$LINK_UNAPPENDED|taken back" "$LINK_SKIPPED|skipped"; do
    label="${count#*|}"
    count="${count%%|*}"
    [ "$count" -eq 0 ] || counts+=("$count $label")
  done
  label=$(IFS='|'; printf '%s' "${counts[*]-}")
  label="${label//|/ $UI_SEPARATOR }"
  if [ "$LINK_FAILURES" -eq 0 ]; then
    framework.console.output::success "Done${label:+: $label}."
  else
    framework.console.output::error "$(framework.helpers.text::plural "$LINK_FAILURES" change) failed${label:+ ($label)}."
  fi
  for warning in ${LINK_WARNINGS[@]+"${LINK_WARNINGS[@]}"}; do
    framework.console.output::warn "$warning"
  done
}

# Shows the planned changes, then applies them once agreed: with -y
# (<confirmed>), or at the prompt. With --preview (<preview>), or with no one
# to ask, it stops after showing them, having changed nothing. <command> is
# what applies them.
core.system.link.console::confirm_changes() {
  local confirmed="$1" preview="$2" command="$3"
  framework.console.output::line "This will:"
  core.system.link.console::print_changes
  core.system.link.console::print_notices
  if ! $preview && ! $confirmed && ! framework.console.prompt::can_ask; then
    framework.console.output::line "No one at a terminal to confirm, so this is only a preview."
    preview=true
  fi
  if $preview; then
    framework.console.output::line "Preview only — nothing changed."
    framework.console.output::next "To apply $(framework.helpers.text::plural "$LINK_CHANGES" change): $OUTPUT_MANUAL_RUN $command"
    exit 0
  fi
  if $confirmed; then
    framework.console.output::line "Applying $(framework.helpers.text::plural "$LINK_CHANGES" change) (-y)…"
  else
    framework.console.prompt::confirm_or_exit "Do you want to apply $(framework.helpers.text::plural "$LINK_CHANGES" change)?" n "$command"
  fi
}

# plugins:link and plugins:unlink: <plugin>'s links alone, <mode> link (its
# waiting links applied, then moved to active) or unlink (its active links
# taken back, then moved to "inactive"), previewed and confirmed as link does.
core.system.link.console::plugin_links() {
  local mode="$1" plugin="" overwrite=false preview=false confirmed=false state to command
  shift
  while [ $# -gt 0 ]; do
    case "$1" in
      --overwrite | --force) overwrite=true ;;
      --preview | --dry-run) preview=true ;;
      -y | --yes) confirmed=true ;;
      -*) framework.console.args::unexpected "$1" ;;
      *) [ -z "$plugin" ] || framework.console.args::unexpected "$1"; plugin="$1" ;;
    esac
    shift
  done
  [ -n "$plugin" ] || framework.console.args::invalid "Which plugin? Please give it as <owner>/<name>."
  guards::plugin_id "$plugin" || framework.console.args::invalid "\"$plugin\" isn't a plugin name; please use <owner>/<name>."
  ! $confirmed || guards::skip_confirmation \
    || framework.console.output::fail_as "$EXIT_PRECONDITION" "-y only works in a terminal, so nothing changed unseen." "$OUTPUT_MANUAL_RUN bash dot plugins:$mode $plugin"
  core.system.link.service::has_map \
    || framework.console.output::fail_as "$EXIT_PRECONDITION" "$(dot::relative "$SETTINGS_FILE") has no links yet." "Please run bash dot link first."
  state=$(core.system.link.service::group_state "$plugin")
  if [ "$mode" = link ]; then
    to=active
    [ "$state" != active ] || framework.console.output::fail_as "$EXIT_PRECONDITION" "$plugin's links are already linked, with none waiting." "To link them again: bash dot link"
    [ "$state" != both ] || $overwrite \
      || framework.console.output::fail_as "$EXIT_PRECONDITION" "$plugin's links are already linked; new ones wait under \"inactive\"." "To take the new ones: bash dot plugins:link $plugin --overwrite"
  else
    to=inactive
    [ "$state" != inactive ] || framework.console.output::fail_as "$EXIT_PRECONDITION" "$plugin's links aren't linked." "To link them: bash dot plugins:link $plugin"
    [ "$state" != both ] || $overwrite \
      || framework.console.output::fail_as "$EXIT_PRECONDITION" "$plugin also has links waiting under \"inactive\"." "To replace them: bash dot plugins:unlink $plugin --overwrite"
  fi
  [ "$state" != none ] || framework.console.output::fail_as "$EXIT_NOT_FOUND" "$plugin has no links in $(dot::relative "$SETTINGS_FILE")." "See the plugins: bash dot plugins:list"
  LINK_ONLY_GROUP="$plugin"
  LINK_ONLY_MODE="$mode"
  LINK_OVERWRITE_COMMAND="bash dot plugins:$mode $plugin"
  core.system.link.service::plan "$overwrite" ""
  core.system.link.service::count_changes
  core.system.link.console::print_errors
  [ "$LINK_FAILURES" -eq 0 ] || exit "$EXIT_FAILURE"
  command="bash dot plugins:$mode $plugin$(! $overwrite || printf ' --overwrite')"
  if [ "$LINK_CHANGES" -gt 0 ]; then
    core.system.link.console::confirm_changes "$confirmed" "$preview" "$command"
    core.system.link.service::apply
  elif $preview; then
    framework.console.output::line "Preview only — nothing to change on disk; $plugin's links would move to \"$to\"."
    return 0
  fi
  core.system.link.service::move_group "$plugin" "$to" "$overwrite"
  core.system.link.console::print_result
  [ "$LINK_FAILURES" -eq 0 ] || exit "$EXIT_FAILURE"
  if [ "$to" = active ]; then
    framework.console.output::detail "$plugin's links are now active."
  else
    framework.console.output::detail "$plugin's links are now under \"inactive\"."
  fi
}
