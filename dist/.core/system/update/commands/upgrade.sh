# shellcheck shell=bash

DESCRIPTION="Update dotHey's core to its latest version."
DOCS="updating-dothey"

hey::use framework.console.args framework.helpers.fs framework.helpers.json framework.console.output framework.console.prompt framework.ui.spinner core.system.update.service

usage() {
  cat <<EOF
Updates dotHey's core ($(hey::relative "$CORE_DIR")/) from
$UPDATE_REPOSITORY_URL ($UPDATE_BRANCH) in one step, showing both
versions. Plugins and your context files are never touched. When the links
need refreshing, it offers to (at a terminal), or says to run bash hey link.

Usage:
  bash hey upgrade [--link [<link options>...]]

Options:
  --link       Refresh the links right after, without asking: runs bash hey
               link with the options that follow, e.g. --link -y --overwrite.
               Options without --link are ignored, with a warning.
  -h, --help   Show this help.

Examples:
  bash hey upgrade
  bash hey upgrade --link -y

Notes:
  - A file is deleted only when the installed version had it and the latest
    doesn't; one you edited is kept and listed.
  - Without a known installed version (state.$UPDATE_COMMIT_STATE in $(hey::relative "$SETTINGS_FILE")), nothing
    is deleted: the files the latest no longer has are listed instead.
  - Plugins update with bash hey plugins:update.
EOF
}

report() {
  local new="$1" counts="" count
  framework.console.output::newline
  for count in "${#UPDATE_ADDED[@]} added" "${#UPDATE_UPDATED[@]} updated" "${#UPDATE_REMOVED[@]} removed"; do
    [ "${count%% *}" -eq 0 ] || counts="$counts $UI_SEPARATOR $count"
  done
  framework.console.output::success "dotHey updated to ${new:0:7}$counts."
  if [ ${#UPDATE_EDITED[@]} -gt 0 ]; then
    framework.console.output::warn "Kept the files you edited that dotHey no longer ships; please delete them once reviewed:"
    printf "$UI_INDENT%s\n" "${UPDATE_EDITED[@]}"
  fi
  if [ ${#UPDATE_UNKNOWN[@]} -gt 0 ]; then
    framework.console.output::warn "These files aren't part of dotHey ${new:0:7}. Please delete any left from older versions and keep your own:"
    printf "$UI_INDENT%s\n" "${UPDATE_UNKNOWN[@]}"
  fi
}

# Whether the upgraded links need refreshing: status 0 when bash hey link
# would change something, 1 when nothing, 2 when it can't tell.
links_need_refresh() {
  local plan actions
  plan=$(hey::call link --preview --json 2>/dev/null) || return 2
  actions=$(framework.helpers.json::values "$plan" '.changes[].action' 2>/dev/null) || return 2
  printf '%s\n' "$actions" | grep -qvx -e skip -e ''
}

# The links after an upgrade: refreshed when asked to (--link), else offered
# when they need it, or the command to run for them.
refresh_links() {
  local status=0
  if $1; then
    shift
    hey::call link "$@"
    return
  fi
  links_need_refresh || status=$?
  case "$status" in
    1) return 0 ;;
    2) framework.console.output::next "Run bash hey link to check the links." ;;
    *)
      # link shows what changes and asks before applying it.
      if framework.console.prompt::can_ask && framework.console.prompt::confirm "Do you want to refresh the links now?" y; then
        hey::call link || return
      else
        framework.console.output::next "Run bash hey link to refresh the links."
      fi
      ;;
  esac
}

handle() {
  local old new source tree failure link=false link_options=() ignored=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --link) link=true; shift; link_options=("$@"); break ;;
      *) ignored+=("$1"); shift ;;
    esac
  done
  # Options are bash hey link's, and only after --link: the upgrade goes on
  # without them.
  if [ ${#ignored[@]} -eq 1 ]; then
    framework.console.output::warn "Ignoring ${ignored[0]}, since it only works after --link."
  elif [ ${#ignored[@]} -gt 1 ]; then
    framework.console.output::warn "Ignoring ${ignored[0]} and $((${#ignored[@]} - 1)) more, since they only work after --link."
  fi
  command -v git >/dev/null || framework.console.output::fail_as "$EXIT_PRECONDITION" "Upgrading needs git, which isn't installed here."
  old=$(core.system.update.service::installed_commit)
  # The upgrade replaces .core/, so a fallback for its files can't be there.
  FS_TEMP_FALLBACK="$DOTHEY_ROOT/$HEY_TEMP_DIR"
  framework.helpers.fs::make_temp_dir UPDATE_WORKSPACE || framework.console.output::fail "Couldn't create a temporary directory; please check free space and \$TMPDIR."
  UPDATE_REPOSITORY="$UPDATE_WORKSPACE/repository"
  framework.ui.spinner::run "Downloading dotHey…" core.system.update.service::download "$old" || framework.console.output::fail "The download didn't work, so nothing changed."
  core.system.update.service::has_commit "$UPDATE_NEW_REF" || framework.console.output::fail "The download doesn't look like dotHey (it has no commit), so nothing changed."
  new=$(core.system.update.service::git rev-parse --verify "$UPDATE_NEW_REF^{commit}")
  if [ -n "$old" ] && ! core.system.update.service::has_commit "$UPDATE_OLD_REF"; then
    framework.console.output::warn "The installed version ${old:0:7} isn't in the public repo, so nothing will be deleted; files the latest no longer has are listed instead."
    old=""
  elif [ -z "$old" ]; then
    framework.console.output::warn "There's no state.$UPDATE_COMMIT_STATE in $(hey::relative "$SETTINGS_FILE"), so nothing will be deleted; files the latest no longer has are listed instead."
  fi
  if [ "$old" = "$new" ]; then
    framework.console.output::success "dotHey is up to date (${new:0:7})."
    # With --link, the links are refreshed anyway, so one run always ends linked.
    ! $link || hey::call link ${link_options[@]+"${link_options[@]}"}
    return
  fi
  framework.console.output::line "A new dotHey is available."
  framework.console.output::detail "Latest  $(core.system.update.service::summary "$new")"
  [ -z "$old" ] || framework.console.output::detail "Yours   $(core.system.update.service::summary "$old")"
  framework.console.output::line "Updating dotHey…"
  source="$UPDATE_SOURCE"
  core.system.update.service::extract "$new" "$source" "$UPDATE_WORKSPACE/tree" || framework.console.output::fail "The download doesn't look like dotHey (can't read $source/ at ${new:0:7}), so nothing changed."
  tree="$UPDATE_WORKSPACE/tree/$source"
  [ -d "$tree/${UPDATE_TREES[0]}" ] || framework.console.output::fail "The download doesn't look like dotHey (${new:0:7} has no $source/${UPDATE_TREES[0]}/), so nothing changed."
  core.system.update.service::compare "$tree"
  if [ -n "$old" ]; then
    core.system.update.service::find_removed "$old" "$new" "$source"
  else
    core.system.update.service::find_unknown "$tree"
  fi
  if ! core.system.update.service::copy "$tree"; then
    for failure in "${UPDATE_FAILURES[@]}"; do
      framework.console.output::error "$failure"
    done
    framework.console.output::fail "The update didn't finish, so your version stays as it was." "Please fix the errors above, then run: bash hey upgrade"
  fi
  core.system.update.service::record_version "$new" || framework.console.output::fail "Files updated, but the new version couldn't be recorded in $(hey::relative "$SETTINGS_FILE") (state.$UPDATE_COMMIT_STATE)."
  # The new core decides what to migrate: its migrate command, in its own
  # process, asks only when a migration is pending here.
  hey::call migrate --if-pending || true
  report "$new"
  refresh_links "$link" ${link_options[@]+"${link_options[@]}"}
}
