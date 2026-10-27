#!/usr/bin/env bash

dot::use framework.console.args core.modules.release.service framework.console.output framework.console.prompt framework.helpers.text

# One push option of release:create and release:push, its arguments counted
# into RELEASE_TAKEN; fails for anything else.
core.modules.release.console::parse_push_option() {
  RELEASE_TAKEN=1
  case "$1" in
    -f | --force) RELEASE_FORCE=true ;;
    --keep-tokens)
      framework.console.args::require_value "$@"
      RELEASE_CACHE_MINUTES="$2"
      [[ "$RELEASE_CACHE_MINUTES" =~ $RELEASE_CACHE_MINUTES_PATTERN ]] || framework.console.args::invalid "--keep-tokens takes whole minutes, e.g. --keep-tokens 15."
      RELEASE_TAKEN=2
      ;;
    *) return 1 ;;
  esac
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
  core.modules.release.service::is_targeted "$name" && return 0
  framework.console.prompt::confirm "Do you want to push $tag to $name?"
}

core.modules.release.console::push() {
  local branch="$1" tag="$2" index name failures=0 force=""
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
    [ "$(core.modules.release.service::token_store)" != gpg ] || framework.console.output::info "Pushing to $name… please enter the token's passphrase if asked."
    if core.modules.release.service::push_with_token "$RELEASE_DESTINATION" "$name" "${RELEASE_REMOTE_URLS[$index]}" -q --atomic ${force:+"$force"} "refs/heads/$branch" --tags; then
      framework.console.output::success "Pushed to $name."
    else
      framework.console.output::error "Couldn't push to $name." "Retry with: bash dot release:push $name${force:+ --force}"
      failures=$((failures + 1))
    fi
  done
  framework.console.output::newline
  [ "$failures" -eq 0 ] || framework.console.output::fail "$(framework.helpers.text::plural "$failures" push) didn't go through; the release commit and tag are kept."
}

core.modules.release.console::print_warnings() {
  local warning
  for warning in ${RELEASE_WARNINGS[@]+"${RELEASE_WARNINGS[@]}"}; do
    framework.console.output::warn "$warning"
  done
}
