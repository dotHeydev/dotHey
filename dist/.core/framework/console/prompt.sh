# shellcheck shell=bash

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

# Yes or no to <question>, <default> (y or n) on Enter: at a terminal that
# reads keys, framework.ui.confirm; else a typed y/n.
framework.console.prompt::confirm() {
  local question="$1" default="${2:-n}" hint="[y/N]" reply=""
  [ "$default" != y ] || hint="[Y/n]"
  framework.console.prompt::can_ask || return 1
  dot::use framework.ui.screen
  if framework.ui.screen::reads_keys; then
    dot::use framework.ui.confirm
    framework.ui.confirm::ask "$question" "$default"
    return
  fi
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

# Whether someone can type a secret: a terminal to ask at, even when stdin
# and stderr are pipes, and no agent or CI running.
framework.console.prompt::can_ask_secret() {
  ! framework.console.output::is_unattended && { : </dev/tty; } 2>/dev/null
}

# <text> as pinentry reads it in a command: %, CR, and LF escaped.
framework.console.prompt::assuan() {
  local text="${1//%/%25}"
  text="${text//$'\r'/%0D}"
  printf '%s' "${text//$'\n'/%0A}"
}

# Asks for a secret through pinentry, gpg's secure prompt, on the terminal
# only (pinentry-curses, else pinentry-tty: never a window), for a secret no
# system prompt takes (a token gpg is to encrypt). dotdot never reads keys
# itself; passwords and passphrases are left to the system's own prompts
# (ssh-add, gpg, the keychain). Prints the secret on stdout, for the caller
# to hand on through a pipe; fails with no terminal, no terminal pinentry,
# or nothing typed.
framework.console.prompt::pinentry() {
  local description="$1" label="${2:-Secret:}" program="" candidate tty reply
  framework.console.prompt::can_ask_secret || { dot::raise "A secret is only typed at a terminal, so nothing was asked."; return 1; }
  for candidate in pinentry-curses pinentry-tty; do
    command -v "$candidate" >/dev/null && { program="$candidate"; break; }
  done
  [ -n "$program" ] || { dot::raise "There's no terminal pinentry to ask with, so nothing was asked." "Please install pinentry-curses or pinentry-tty (gnupg's pinentry package)."; return 1; }
  tty=$(tty </dev/tty 2>/dev/null) || { dot::raise "Couldn't find the terminal to ask at."; return 1; }
  reply=$(printf 'OPTION ttyname=%s\nOPTION ttytype=%s\nSETTITLE dotdot\nSETDESC %s\nSETPROMPT %s\nGETPIN\nBYE\n' \
    "$tty" "${TERM:-dumb}" "$(framework.console.prompt::assuan "$description")" "$(framework.console.prompt::assuan "$label")" \
    | "$program" --ttyname "$tty" 2>/dev/null | sed -n 's/^D //p') || reply=""
  [ -n "$reply" ] || { dot::raise "Nothing was typed."; return 1; }
  printf '%s' "$reply"
  reply=""
}

# The number of the <option> picked for <question>: at a terminal that reads
# keys, with framework.ui.select; else typed from a numbered list.
framework.console.prompt::choice() {
  local question="$1" option index=0
  shift
  framework.console.prompt::can_ask || return 1
  dot::use framework.ui.screen
  if framework.ui.screen::reads_keys; then
    dot::use framework.ui.select
    option=$(framework.ui.select::ask "$question" "$@") || return
    for ((index = 1; index < $#; index++)); do
      [ "${!index}" != "$option" ] || break
    done
    printf '%s\n' "$index"
    return 0
  fi
  framework.console.prompt::question "$question" >&2
  printf '\n' >&2
  # shellcheck disable=SC2059
  PS3=$(printf "$UI_HINT_CHOICE" "$#")
  select option in "$@"; do
    if [ -n "$option" ]; then
      printf '%s\n' "$REPLY"
      return 0
    fi
    framework.console.output::line "$UI_HINT_INVALID" >&2
  done
  return 1
}
