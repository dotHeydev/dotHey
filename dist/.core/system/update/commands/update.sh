#!/usr/bin/env bash

DESCRIPTION="Update dotdot's core (.core/) to the latest dotdot; plugins and context files are untouched."

dot::use framework.console.args framework.helpers.fs framework.console.output framework.console.prompt core.system.update.service

usage() {
  cat <<EOF
bash dot update — update dotdot's core ($DOTDOT_NAME/${UPDATE_TREES[0]}/) to the latest dotdot, downloaded from
$UPDATE_REPOSITORY_URL ($UPDATE_BRANCH), then optionally run bash dot link.

Plugins ($(dot::relative "$PLUGINS_DIR")/) are left to bash dot plugins:update.
Every context file (AGENTS.md, RULES.md, PRODUCT.md, Features/, Decisions/,
Notes/, USER.md, …) is never read or written.

$UPDATE_VERSION_SETTING in $(dot::relative "$SETTINGS_FILE") holds the commit dotdot was
last installed or updated from. The update fetches that commit and the latest
one with git (only those two, into a temporary repo nothing of yours touches),
shows both, asks, and:
  - copies every file of the latest commit over dotdot's
  - removes a file only when it existed at the recorded commit and no longer
    exists at the latest (a move counts as removed here, added there). A
    removed file that was edited locally is kept and reported, never deleted
  - leaves every other file alone: your own skills, agents, and scripts
  - records the latest commit, only once everything else succeeded

Without a recorded version, or with a recorded commit the public repo doesn't
have, nothing is removed: files the latest commit lacks are listed for you to
review instead.

-y, --yes answers yes to the update's own question; link is still asked,
since it changes files outside dotdot.

Every run needs a terminal (piped input is refused), --yes included, so only a
person can start an update.

Usage:
  bash dot update [-y, --yes]
  bash dot update --help
EOF
}

report() {
  local new="$1" counts="" count
  framework.console.output::newline
  for count in "${#UPDATE_ADDED[@]} added" "${#UPDATE_UPDATED[@]} updated" "${#UPDATE_REMOVED[@]} removed"; do
    [ "${count%% *}" -eq 0 ] || counts="$counts $OUTPUT_SEPARATOR $count"
  done
  framework.console.output::success "dotdot updated to ${new:0:7}$counts."
  if [ ${#UPDATE_EDITED[@]} -gt 0 ]; then
    framework.console.output::warn "Kept the files you edited that dotdot no longer ships; please delete them once reviewed:"
    printf "$OUTPUT_INDENT%s\n" "${UPDATE_EDITED[@]}"
  fi
  if [ ${#UPDATE_UNKNOWN[@]} -gt 0 ]; then
    framework.console.output::warn "These files aren't part of dotdot ${new:0:7}. Please delete any left from older versions and keep your own:"
    printf "$OUTPUT_INDENT%s\n" "${UPDATE_UNKNOWN[@]}"
  fi
}

handle() {
  local confirmed=false old new source tree failure
  case "${1-}" in
    -y | --yes) confirmed=true; shift ;;
  esac
  [ $# -eq 0 ] || framework.console.args::unexpected "$1"
  framework.console.prompt::can_ask || framework.console.output::fail "This needs your confirmation in a terminal, so nothing changed." "$OUTPUT_MANUAL_RUN bash dot update"
  command -v git >/dev/null || framework.console.output::fail "bash dot update needs git, which isn't installed here."
  old=$(core.system.update.service::installed_commit)
  framework.helpers.fs::make_temp_dir UPDATE_WORKSPACE || framework.console.output::fail "Couldn't create a temporary directory; please check free space and \$TMPDIR."
  UPDATE_REPOSITORY="$UPDATE_WORKSPACE/repository"
  framework.console.output::spin "Downloading dotdot…" core.system.update.service::download "$old" || framework.console.output::fail "The download didn't work, so nothing changed."
  core.system.update.service::has_commit "$UPDATE_NEW_REF" || framework.console.output::fail "The download doesn't look like dotdot (it has no commit), so nothing changed."
  new=$(core.system.update.service::git rev-parse --verify "$UPDATE_NEW_REF^{commit}")
  if [ -n "$old" ] && ! core.system.update.service::has_commit "$UPDATE_OLD_REF"; then
    framework.console.output::warn "The installed version ${old:0:7} isn't in the public repo, so nothing will be deleted; files the latest no longer has are listed instead."
    old=""
  elif [ -z "$old" ]; then
    framework.console.output::warn "There's no $UPDATE_VERSION_SETTING in $(dot::relative "$SETTINGS_FILE"), so nothing will be deleted; files the latest no longer has are listed instead."
  fi
  if [ "$old" = "$new" ]; then
    framework.console.output::success "dotdot is up to date (${new:0:7})."
    return 0
  fi
  framework.console.output::line "A new dotdot is available."
  framework.console.output::detail "Latest  $(core.system.update.service::summary "$new")"
  [ -z "$old" ] || framework.console.output::detail "Yours   $(core.system.update.service::summary "$old")"
  if $confirmed; then
    framework.console.prompt::answered "Do you want to update dotdot?" "yes (--yes)"
  else
    framework.console.prompt::confirm_or_exit "Do you want to update dotdot?" n "bash dot update"
  fi
  framework.console.output::line "Updating dotdot…"
  source="$UPDATE_SOURCE"
  core.system.update.service::extract "$new" "$source" "$UPDATE_WORKSPACE/tree" || framework.console.output::fail "The download doesn't look like dotdot (can't read $source/ at ${new:0:7}), so nothing changed."
  tree="$UPDATE_WORKSPACE/tree/$source"
  [ -d "$tree/${UPDATE_TREES[0]}" ] || framework.console.output::fail "The download doesn't look like dotdot (${new:0:7} has no $source/${UPDATE_TREES[0]}/), so nothing changed."
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
    framework.console.output::fail "The update didn't finish, so your version stays as it was." "Please fix the errors above, then run: bash dot update"
  fi
  core.system.update.service::record_version "$new" || framework.console.output::fail "Files updated, but the new version couldn't be recorded in $(dot::relative "$SETTINGS_FILE") ($UPDATE_VERSION_SETTING)."
  # The new core decides what to migrate: its migrate command, in its own
  # process, asks only when a migration is pending here.
  dot::call migrate --if-pending || true
  report "$new"
  if framework.console.prompt::confirm "Do you want to refresh the links now with bash dot link?"; then
    dot::call link || true
  else
    framework.console.output::next "Run bash dot link when you're ready."
  fi
}
