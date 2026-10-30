# shellcheck shell=bash

dot::use framework.console.output framework.console.prompt framework.ui.rule

TERMINAL_FALLBACK_EDITORS=(nano vi)

framework.console.terminal::page() {
  local file="$1" print="${2:-false}"
  if ! $print && [ -t 1 ] && command -v less >/dev/null; then
    less -R -- "$file"
    return
  fi
  framework.ui.rule::show
  printf '%s\n' "$(cat -- "$file")"
  framework.ui.rule::show
}

framework.console.terminal::editor() {
  local editor="${VISUAL:-${EDITOR:-}}" candidate
  if [ -n "$editor" ]; then
    printf '%s\n' "$editor"
    return
  fi
  for candidate in "${TERMINAL_FALLBACK_EDITORS[@]}"; do
    if command -v "$candidate" >/dev/null; then
      printf '%s\n' "$candidate"
      return
    fi
  done
  return 1
}

framework.console.terminal::edit() {
  local file="$1" editor
  framework.console.prompt::is_interactive || framework.console.output::fail_as "$EXIT_PRECONDITION" "Editing needs a terminal." "Please pass the content as flags instead (see --help)."
  editor=$(framework.console.terminal::editor) || framework.console.output::fail "No editor found." "Please set \$EDITOR, e.g. export EDITOR=nano"
  sh -c "$editor \"\$1\"" sh "$file" </dev/tty >/dev/tty
}
