# shellcheck shell=bash

DESCRIPTION="Link dotHey and its plugins where your agents read them."
DOCS="configuration/linking"
JSON=true

hey::use framework.console.args framework.console.output framework.console.prompt framework.helpers.fs framework.helpers.json framework.helpers.text core.system.link.service core.system.link.console

usage() {
  cat <<EOF
Seeds $DOTHEY_NAME/USER.md, then links and appends what the "links" in
$(hey::relative "$SETTINGS_FILE") list. It previews every change and asks before applying any;
with no one at a terminal to ask, it only previews.

Usage:
  bash hey link [--overwrite] [--preview] [-v, --verbose] [-y, --yes] [--json]

Options:
  --overwrite          Replace destinations that already exist: a symlink is
                       replaced, a file is backed up as <name>.bak-<time> first.
                       A real directory is always skipped. Also --force.
  --preview            Show the changes, and stop. Also --dry-run.
  -v, --verbose        List the entries that stay as they are, too.
  -y, --yes            Apply without asking. Only at a terminal, or when dotHey
                       itself runs it.
  --json               Print the changes as {"changes": [{"action", "origin",
                       "destination"}], "taken"}, and stop; with -y, apply them
                       and print {"linked", "removed", "appended", "takenBack",
                       "skipped", "failed"}.
  -h, --help           Show this help.

Examples:
  bash hey link
  bash hey link --preview
  bash hey link --overwrite -v

Links:
  "<origin>": ["<destination>", ...]   symlink each destination to the origin
  "append": {"<origin>": [...]}        append the file to each destination,
                                       between markers naming its owner
  "skip": {"<origin>": [...]}          never link or append these; what dotHey
                                       linked or appended there is taken back
  "<owner>/<name>": {...}              a plugin's active links, same shape
  "inactive": {"<owner>/<name>": ...}  a plugin's links, never applied until
                                       they are activated

  Origins: @hey:<path>, @module:<name>:<path>, @plugin:<owner>.<name>:<path>,
  @dotheySkills, @dotheyAgents, @pluginsSkills, @pluginsAgents; a /* ending
  links each entry inside. Destinations are project paths outside $DOTHEY_NAME/
  and .git/, never .env; appends may also go to @hey:<Doc>.md. When two entries
  claim one destination, your own links win, then the first declared.

Notes:
  - Link a plugin's own links with bash hey plugins:link.
  - Run it after installing dotHey, creating a git worktree, or adding,
    renaming or removing anything the links cover. Re-running is safe.
  - Links are relative, so they survive a clone, a move or a rebuild.
  - bash hey link -v lists every current link.
EOF
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
  framework.console.prompt::confirm "Do you want to merge them in $(hey::relative "$SETTINGS_FILE"), keeping every destination?" y || return 0
  printf '%s\n' "$merged" | framework.helpers.fs::write "$SETTINGS_FILE" \
    || framework.console.output::fail "Couldn't write $(hey::relative "$SETTINGS_FILE"); please check that it's writable."
  framework.console.output::success "Merged them in $(hey::relative "$SETTINGS_FILE")."
}

map_only() {
  local confirmed="$1" refresh="$2" note
  core.system.link.service::prepare_map "$refresh" true
  core.system.link.console::print_errors
  if [ ${#LINK_MAP_NOTES[@]} -eq 0 ]; then
    framework.console.output::success "The links are up to date."
    return 0
  fi
  framework.console.output::line "This will:"
  for note in "${LINK_MAP_NOTES[@]}"; do
    core.system.link.console::map_entry "$note"
  done
  if $confirmed; then
    framework.console.output::line "Writing $(hey::relative "$SETTINGS_FILE") (-y)…"
  else
    framework.console.prompt::confirm_or_exit "Do you want to write $(hey::relative "$SETTINGS_FILE")?" y "bash hey link --settings-only"
  fi
  core.system.link.service::save_map
  core.system.link.console::print_errors
  [ "$LINK_FAILURES" -eq 0 ]
}

handle() {
  local override=false confirmed=false preview=false refresh="" only_map=false sweep=false
  while [ $# -gt 0 ]; do
    case "$1" in
      --overwrite | --force) override=true ;;
      --preview | --dry-run) preview=true ;;
      --settings-only) only_map=true ;;
      --remove-uninstalled) sweep=true ;;
      --relink-from)
        framework.console.args::require_value "$@"
        core.system.link.service::relink_from "$2" || framework.console.args::invalid "--relink-from needs dotHey's former place in the project (got $2)."
        shift
        ;;
      -v | --verbose) LINK_VERBOSE=true ;;
      -y | --yes) confirmed=true ;;
      --refresh-plugin)
        framework.console.args::require_value "$@"
        guards::plugin_name "$2" || framework.console.args::invalid "--refresh-plugin needs a plugin as <owner>/<name> (got $2)."
        refresh="$refresh $2"
        shift
        ;;
      *) framework.console.args::unexpected "$1" ;;
    esac
    shift
  done
  ! $confirmed || guards::skip_confirmation \
    || framework.console.output::fail_as "$EXIT_PRECONDITION" "-y only works in a terminal, so nothing changed unseen." "$OUTPUT_MANUAL_RUN bash hey link"
  if $only_map; then
    map_only "$confirmed" "$refresh"
    return
  fi
  if $sweep; then
    core.system.link.service::plan_sweep
  else
    $confirmed || $HEY_JSON || offer_merge
    LINK_PREVIEW=$preview
    core.system.link.service::plan "$override" "$refresh"
  fi
  core.system.link.service::count_changes
  core.system.link.console::print_errors
  if $sweep; then
    core.system.link.service::apply
    core.system.link.console::print_changes
    core.system.link.console::print_errors
    [ "$LINK_FAILURES" -eq 0 ]
    return
  fi
  if $HEY_JSON; then
    if $preview || ! $confirmed; then
      core.system.link.console::print_json_plan
      return 0
    fi
    core.system.link.service::apply
    core.system.link.console::print_errors
    core.system.link.console::print_json_result
    [ "$LINK_FAILURES" -eq 0 ]
    return
  fi
  if [ "$LINK_CHANGES" -eq 0 ]; then
    ! $LINK_VERBOSE || core.system.link.console::print_changes
    core.system.link.console::print_notices
    [ "$LINK_FAILURES" -gt 0 ] || framework.console.output::success "Everything is already linked."
    [ "$LINK_FAILURES" -eq 0 ]
    return
  fi
  core.system.link.console::confirm_changes "$confirmed" "$preview" "bash hey link$(! $override || printf ' --overwrite')"
  core.system.link.service::apply
  core.system.link.console::print_result
  [ "$LINK_FAILURES" -eq 0 ]
}
