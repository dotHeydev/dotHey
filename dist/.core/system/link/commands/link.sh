#!/usr/bin/env bash

DESCRIPTION="Seed USER.md and link dotdot and its plugins into the places the harness reads."

dot::use framework.console.args framework.console.output framework.console.prompt framework.helpers.fs framework.helpers.json core.system.link.service

usage() {
  local entry
  cat <<EOF
bash dot link — activate dotdot: seed USER.md, then symlink dotdot's and the
installed plugins' files into the locations the harness reads.

What is linked is up to you: "links" in $(dot::relative "$SETTINGS_FILE"), as JSON (dotdot's
default until it has them).
  "<origin>": [destinations]
            symlinks each destination to the origin
  "append"  {origin: [destinations]}: appends the file to each destination
            between markers naming its plugin, or dotdot (<!-- --> in Markdown,
            # elsewhere), creating it when missing (a .json only then, as JSON
            takes no markers); appends from different owners each keep their
            own region, so they never collide
  "remove"  {origin: [destinations]}: unlinks a destination still pointing at
            the origin and removes what the origin appended there; it wins
  "<owner>/<name>": {the same three, for a plugin}: its active links
  "inactive" {<owner>/<name>: {"<origin>": …, "append": …}}: each installed
            plugin's links, never applied until bash dot link:activate moves
            them into its active group

When two entries link the same destination, the general links win over a
plugin's, and otherwise the first declared wins; the one left out is reported.

Origins: @dot:<path> (in dotdot), @module:<name>:<path>,
@plugin:<owner>.<name>:<path>, @dotdotSkills / @dotdotAgents (each of dotdot's
skills or agents), @pluginsSkills / @pluginsAgents (every plugin's); a /*
ending takes each entry inside one by one. Destinations are project paths
outside dotdot and .git, never .env; appends may also go to @dot:<Doc>.md.

A plugin's inactive links are written when it is added and afresh when it is
updated (--refresh <owner>/<name>); its active group stays. The first run after
a plugin is removed drops its groups and the entries taken from it, its
broken links, and what it appended.

Run it after installing dotdot, after creating a git worktree, and after
adding, renaming, or removing anything the links cover. Re-running is safe.
USER.md is created from USER.example.md when it is missing.

Every run previews each destination, then asks [y/N] on a terminal before
changing anything (piped input is refused, unless -y is given):
  - missing                      → linked
  - already a link to dotdot     → left as is ("already linked")
  - a link into dotdot's own files that points elsewhere, broken or not
                                 → relinked ("dotdot link moved; will relink")
  - a broken link into dotdot's own files that no link names, in a
    directory the links point into
                                 → removed ("broken dotdot link; will remove")
  - anything else                → "existing; will skip"

-y / --yes applies the previewed changes without asking: at a terminal, or
when dotdot itself makes the call (the installer, plugin commands). Anywhere
else it is refused, so an agent can't approve changes for the user.

--override changes only what happens to existing destinations once confirmed:
  - a symlink pointing elsewhere → replaced ("existing; will override")
  - a real file                  → renamed to <name>.bak-<timestamp>, then
                                   linked ("existing; will back up and override")
  - a real directory             → still skipped; remove it yourself

--sweep takes back only what removed plugins left: their entries in the links,
their broken links, and what they appended; plugins:remove runs it.

A plugin's suggestions are written only by --refresh <owner>/<name>, as
plugins:add and plugins:update do, never by a plain run. --map-only writes
them and links and appends nothing.

Usage:
  bash dot link
  bash dot link --override
  bash dot link --refresh <owner>/<name>
  bash dot link --map-only [--refresh <owner>/<name>]
  bash dot link --sweep
  bash dot link -y
  bash dot link --help

Current links (origin->destination, origin relative to dotdot, destination
relative to the project):
EOF
  core.system.link.service::prepare_map "" true
  while IFS= read -r entry; do
    [ "${entry#!}" = "$entry" ] || continue
    framework.console.output::line "  - $entry"
  done < <(core.system.link.service::mappings)
  cat <<'EOF'

An origin ending in "/*" links every direct child individually. Link targets
are relative, so the links survive a clone, a move, or a container rebuild.
EOF
}

action_note() {
  case "$1" in
    link) framework.console.output::paint green "(will link)" ;;
    ok) printf '(already linked)' ;;
    move) framework.console.output::paint green "(dotdot link moved; will relink)" ;;
    prune) framework.console.output::paint green "(broken dotdot link; will remove)" ;;
    unlink) framework.console.output::paint green "(removed in the links; will unlink)" ;;
    skip) framework.console.output::paint yellow "(existing; will skip)" ;;
    relink) framework.console.output::paint red "(existing; will override)" ;;
    backup) framework.console.output::paint red "(existing; will back up and override)" ;;
    append) framework.console.output::paint green "(will append)" ;;
    appended) printf '(already appended)' ;;
    unappend) framework.console.output::paint green "(removed in the links; will remove what was appended)" ;;
    create) framework.console.output::paint green "(will create)" ;;
    exists) framework.console.output::paint yellow "(existing; will keep)" ;;
  esac
}

print_seeds() {
  local note
  for note in ${LINK_MAP_NOTES[@]+"${LINK_MAP_NOTES[@]}"}; do
    framework.console.output::line "  $(framework.console.output::paint green "(will $note)")"
  done
  case "$(core.system.link.service::user_state)" in
    create) framework.console.output::line "  $DOTDOT_NAME/USER.md $(framework.console.output::paint green "(will create from USER.example.md)")" ;;
    existing) framework.console.output::line "  $DOTDOT_NAME/USER.md $(framework.console.output::paint yellow "(existing; will skip)")" ;;
  esac
}

print_preview() {
  local index
  framework.console.output::line "Preview only; nothing changes unless you answer y below:"
  print_seeds
  for index in ${LINK_ACTIONS[@]+"${!LINK_ACTIONS[@]}"}; do
    printf '  %s ' "${LINK_LABELS[$index]}"
    action_note "${LINK_ACTIONS[$index]}"
    printf '\n'
  done
  for index in ${LINK_APPEND_ACTIONS[@]+"${!LINK_APPEND_ACTIONS[@]}"}; do
    printf '  %s ← %s ' "${LINK_APPEND_LABELS[$index]}" "${LINK_APPEND_MARKERS[$index]}"
    action_note "${LINK_APPEND_ACTIONS[$index]}"
    printf '\n'
  done
  for index in ${LINK_NOTICES[@]+"${!LINK_NOTICES[@]}"}; do
    framework.console.output::warn "${LINK_NOTICES[$index]}"
  done
  [ "$LINK_OVERRIDABLE" -eq 0 ] \
    || framework.console.output::line "Run with --override to replace the $LINK_OVERRIDABLE existing symlink(s)/file(s) above; files are backed up first."
}

print_errors() {
  local message
  for message in ${LINK_ERRORS[@]+"${LINK_ERRORS[@]}"}; do
    framework.console.output::error "$message"
  done
  LINK_ERRORS=()
}

print_result() {
  local warning
  print_errors
  framework.console.output::line "Done. $LINK_LINKED linked, $LINK_REMOVED removed, $LINK_APPENDED appended, $LINK_UNAPPENDED taken back, $LINK_UNCHANGED unchanged, $LINK_SKIPPED skipped, $LINK_FAILURES failed."
  for warning in ${LINK_WARNINGS[@]+"${LINK_WARNINGS[@]}"}; do
    framework.console.output::warn "Overridden: $warning"
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
    framework.console.output::line "They can't be merged automatically (different values that aren't lists or objects); merge them by hand."
    return 0
  fi
  framework.console.prompt::confirm "Merge them in $(dot::relative "$SETTINGS_FILE"), keeping every destination?" n || return 0
  printf '%s\n' "$merged" | framework.helpers.fs::write "$SETTINGS_FILE" \
    || framework.console.output::fail "Could not write $(dot::relative "$SETTINGS_FILE")."
  framework.console.output::success "Merged in $(dot::relative "$SETTINGS_FILE")."
}

map_only() {
  local confirmed="$1" refresh="$2" note
  core.system.link.service::prepare_map "$refresh" true
  print_errors
  if [ ${#LINK_MAP_NOTES[@]} -eq 0 ]; then
    framework.console.output::line "Nothing to do."
    return 0
  fi
  framework.console.output::line "Preview only; nothing changes unless you answer y below:"
  for note in "${LINK_MAP_NOTES[@]}"; do
    framework.console.output::line "  $(framework.console.output::paint green "(will $note)")"
  done
  if $confirmed; then
    framework.console.output::line "Writing $(dot::relative "$SETTINGS_FILE") (-y)."
  else
    framework.console.prompt::confirm_or_exit "Write $(dot::relative "$SETTINGS_FILE")?" n "bash dot link --map-only"
  fi
  core.system.link.service::save_map
  print_errors
  [ "$LINK_FAILURES" -eq 0 ]
}

handle() {
  local override=false confirmed=false refresh="" only_map=false sweep=false
  while [ $# -gt 0 ]; do
    case "$1" in
      --override) override=true ;;
      --map-only) only_map=true ;;
      --sweep) sweep=true ;;
      -y | --yes) confirmed=true ;;
      --refresh)
        framework.console.args::require_value "$@"
        [[ "$2" =~ ^[a-z0-9][a-z0-9-]*/[a-z0-9][a-z0-9-]*$ ]] || framework.console.args::invalid "--refresh takes a plugin as <owner>/<name>: $2"
        refresh="$refresh $2"
        shift
        ;;
      *) framework.console.args::unexpected "$1" ;;
    esac
    shift
  done
  ! $confirmed || guards::skip_confirmation \
    || framework.console.output::fail "-y applies changes unseen, so it needs a terminal; ask the user to run bash dot link."
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
  print_preview
  if [ "$LINK_CHANGES" -eq 0 ]; then
    framework.console.output::line "Nothing to do."
    [ "$LINK_FAILURES" -eq 0 ]
    return
  fi
  if $confirmed; then
    framework.console.output::line "Applying $LINK_CHANGES change(s) (-y)."
  else
    framework.console.prompt::confirm_or_exit "Apply $LINK_CHANGES change(s)?" n "bash dot link"
  fi
  core.system.link.service::apply
  print_result
  [ "$LINK_FAILURES" -eq 0 ]
}
