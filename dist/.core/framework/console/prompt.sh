#!/usr/bin/env bash

dot::use framework.console.output framework.console.args

PROMPT_YES_PATTERN='^[Yy]([Ee][Ss])?$'

framework.console.prompt::can_ask() {
  [ -t 0 ] && ! framework.console.output::is_unattended
}

framework.console.prompt::is_interactive() {
  framework.console.prompt::can_ask && [ -t 1 ]
}

# A question: a blank line above it, then the question in bold.
framework.console.prompt::question() {
  printf '\n' >&2
  framework.console.output::render 2 "$(framework.console.output::bold "$(framework.console.output::blue "$1")")"
}

# A question answered without asking, as the flag that answered it.
framework.console.prompt::answered() {
  framework.console.output::line "$(framework.console.prompt::question "$1" 2>&1) $2"
}

framework.console.prompt::confirm() {
  local question="$1" default="${2:-n}" hint="[y/N]" reply=""
  [ "$default" != y ] || hint="[Y/n]"
  framework.console.prompt::can_ask || return 1
  read -r -p "$(framework.console.prompt::question "$question") $hint " reply || return 1
  [[ ${reply:-$default} =~ $PROMPT_YES_PATTERN ]]
}

framework.console.prompt::confirm_or_abort() {
  local question="$1" default="${2:-n}" command="${3:-the command}"
  framework.console.prompt::confirm "$question" "$default" && return 0
  if framework.console.prompt::can_ask; then
    framework.console.output::aborted
    return 1
  fi
  local OUTPUT_ERROR_STATUS="$EXIT_PRECONDITION"
  framework.console.output::error "This needs your confirmation in a terminal, so nothing changed." "$OUTPUT_MANUAL_RUN $command"
  return "$EXIT_PRECONDITION"
}

framework.console.prompt::confirm_or_exit() {
  local status=0
  framework.console.prompt::confirm_or_abort "$@" || status=$?
  [ "$status" -eq 0 ] || exit "$status"
}

# <value> when it isn't empty; else, at a terminal, the answer to <question>;
# off one (or with no answer), the usage error <missing>.
framework.console.prompt::require() {
  local value="$1" question="$2" missing="$3" answer
  if [ -n "$value" ]; then
    printf '%s\n' "$value"
    return
  fi
  framework.console.prompt::is_interactive || framework.console.args::invalid "$missing"
  answer=$(framework.console.prompt::ask "$question")
  [ -n "$answer" ] || framework.console.args::invalid "$missing"
  printf '%s\n' "$answer"
}

# After answers were asked for: the command that gives them as flags, to reuse.
framework.console.prompt::hint() {
  framework.console.output::next "Next time: $*" >&2
}

framework.console.prompt::ask() {
  local question="$1" default="${2-}" reply=""
  framework.console.prompt::can_ask || return 1
  read -r -p "$(framework.console.prompt::question "$question")${default:+ [$default]}: " reply || reply=""
  printf '%s\n' "${reply:-$default}"
}

framework.console.prompt::secret() {
  local question="$1" reply=""
  framework.console.prompt::can_ask || return 1
  read -r -s -p "$(framework.console.prompt::question "$question"): " reply || reply=""
  printf '\n' >&2
  printf '%s' "$reply"
}

framework.console.prompt::choice() {
  local question="$1" option
  shift
  framework.console.prompt::can_ask || return 1
  framework.console.prompt::question "$question" >&2
  printf '\n' >&2
  PS3="Choose 1–$# (Ctrl-D cancels): "
  select option in "$@"; do
    if [ -n "$option" ]; then
      printf '%s\n' "$REPLY"
      return 0
    fi
    framework.console.output::line "Please pick a number from the list." >&2
  done
  return 1
}
