# shellcheck shell=bash

dot::use framework.console.args core.modules.release.service framework.console.output framework.console.prompt framework.helpers.text

# One push option of release:create and release:push, its arguments counted
# into RELEASE_TAKEN; fails for anything else.
core.modules.release.console::parse_push_option() {
  RELEASE_TAKEN=1
  case "$1" in
    --force)
      framework.console.prompt::can_ask \
        || framework.console.output::fail_as "$EXIT_PRECONDITION" "Force-pushing is only confirmed at a terminal, so nothing changed." "$OUTPUT_MANUAL_RUN bash dot $DOT_COMMAND ... --force"
      RELEASE_FORCE=true
      ;;
    --keep-tokens)
      framework.console.args::require_value "$@"
      RELEASE_CACHE_MINUTES="$2"
      [[ "$RELEASE_CACHE_MINUTES" =~ $RELEASE_CACHE_MINUTES_PATTERN ]] || framework.console.args::invalid "--keep-tokens takes whole minutes, e.g. --keep-tokens 15."
      RELEASE_TAKEN=2
      ;;
    *) return 1 ;;
  esac
}

# Whether <value> names remotes (comma-separated), not a version or a flag.
core.modules.release.console::is_remotes() {
  local name found=false
  while IFS= read -r name; do
    [[ "$name" =~ $RELEASE_REMOTE_NAME_PATTERN ]] || return 1
    found=true
  done < <(framework.console.args::split "${1-}")
  $found
}

# Remotes to push to without asking, comma-separated, into RELEASE_PUSH_TO.
core.modules.release.console::add_remotes() {
  local name
  while IFS= read -r name; do
    [[ "$name" =~ $RELEASE_REMOTE_NAME_PATTERN ]] || framework.console.args::invalid "\"$name\" isn't a remote name of release.remotes."
    RELEASE_PUSH_TO+=("$name")
  done < <(framework.console.args::split "$1")
}

core.modules.release.console::wants_push() {
  local name="$1" tag="$2"
  core.modules.release.service::is_targeted "$name" || framework.console.prompt::confirm "Do you want to push $tag to $name?" || return 1
  ! $RELEASE_FORCE || core.modules.release.console::confirm_force "$name"
}

# A force-push to <name> goes on only once its name is typed back.
core.modules.release.console::confirm_force() {
  local name="$1" answer
  answer=$(framework.console.prompt::ask "This replaces $name's history. Type its name to go on") || answer=""
  [ "$answer" = "$name" ] && return 0
  framework.console.output::line "That isn't $name, so it isn't force-pushed."
  return 1
}

core.modules.release.console::push() {
  local branch="$1" tag="$2" index name failures=0 tried=0 force=""
  ! $RELEASE_FORCE || force=--force
  core.modules.release.service::point_remotes
  framework.console.output::newline
  for index in "${!RELEASE_REMOTES[@]}"; do
    name="${RELEASE_REMOTES[$index]}"
    if ! core.modules.release.console::wants_push "$name" "$tag"; then
      framework.console.output::line "Skipped $name."
      framework.console.output::next "Push later with: bash dot release:push $name${force:+ --force}"
      continue
    fi
    tried=$((tried + 1))
    framework.console.output::line "Pushing to $name…"
    if core.modules.release.service::push_with_token "$RELEASE_DESTINATION" "$name" "${RELEASE_REMOTE_URLS[$index]}" -q --atomic ${force:+"$force"} "refs/heads/$branch" --tags; then
      framework.console.output::success "Pushed to $name."
    else
      if [ -s "$DOT_ERROR_FILE" ]; then
        dot::flush_errors
      else
        framework.console.output::error "Couldn't push to $name."
      fi
      framework.console.output::next "Retry with: bash dot release:push $name${force:+ --force}" >&2
      failures=$((failures + 1))
    fi
  done
  [ "$failures" -gt 0 ] || { framework.console.output::newline; return 0; }
  # One remote's failure says it all; several get a summary.
  [ "$tried" -gt 1 ] || exit "$EXIT_FAILURE"
  framework.console.output::newline
  framework.console.output::fail "$failures of $tried pushes didn't go through; the release commit and tag are kept."
}

core.modules.release.console::print_warnings() {
  local warning
  for warning in ${RELEASE_WARNINGS[@]+"${RELEASE_WARNINGS[@]}"}; do
    framework.console.output::warn "$warning"
  done
}
