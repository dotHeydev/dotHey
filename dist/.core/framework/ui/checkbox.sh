#!/usr/bin/env bash

dot::use framework.ui.screen

# Any of <option>..., toggled with Space and confirmed with Enter, each printed
# on its own line; --checked <n,n> checks those (1-based) first. An option's
# note, after two spaces ("Cursor  (9 skills)"), stays out of the answer line. Without keys
# to read, their numbers typed; with no one to answer, status 1, for the
# command to fall back to its flags.
framework.ui.checkbox::ask() {
  local checked=" " current=1 question index picked=""
  if [ "${1-}" = --checked ]; then
    checked=" ${2//,/ } "
    shift 2
  fi
  question="$1"
  shift
  if ! framework.ui.screen::reads_keys; then
    framework.ui.checkbox::typed "$question" "$checked" "$@"
    return
  fi
  framework.ui.screen::begin
  while :; do
    framework.ui.screen::draw "$(framework.ui.checkbox::frame "$question" "$current" "$checked" "$@")"
    framework.ui.screen::read_key
    case "$UI_KEY" in
      up | left) current=$((current > 1 ? current - 1 : $#)) ;;
      down | right | tab) current=$((current < $# ? current + 1 : 1)) ;;
      space)
        case "$checked" in
          *" $current "*) checked="${checked/ $current / }" ;;
          *) checked="$checked$current " ;;
        esac
        ;;
      enter) break ;;
      escape | q) framework.ui.screen::cancel ;;
      eof) framework.ui.screen::end; framework.ui.screen::erase; return 1 ;;
    esac
  done
  framework.ui.screen::end
  for ((index = 1; index <= $#; index++)); do
    [[ "$checked" != *" $index "* ]] || picked="$picked${picked:+, }${!index%%  *}"
  done
  framework.ui.screen::answer "$question" "${picked:-none}"
  for ((index = 1; index <= $#; index++)); do
    [[ "$checked" != *" $index "* ]] || printf '%s\n' "${!index}"
  done
}

# checkbox's frame for <question>, <current> (1-based) hovered, and the
# options numbered in <checked> (" 1 3 ") checked.
framework.ui.checkbox::frame() {
  local question="$1" current="$2" checked="$3" index hovered on mark
  shift 3
  framework.ui.screen::question "$question"
  for ((index = 1; index <= $#; index++)); do
    hovered=false on=false mark="$UI_GLYPH_CHECK_OFF"
    [ "$index" -ne "$current" ] || hovered=true
    [[ "$checked" != *" $index "* ]] || on=true mark="$UI_GLYPH_CHECK_ON"
    printf '\n%s' "$(framework.ui.screen::option "$hovered" "$mark" "$on" "${!index}")"
  done
  printf '\n%s' "$(framework.ui.screen::hint "$UI_HINT_CHECKBOX")"
}

# checkbox::ask as a numbered list, its numbers typed on one line; Enter
# keeps those in <checked> (" 1 3 ").
framework.ui.checkbox::typed() {
  local question="$1" checked="$2" reply number index valid defaults
  shift 2
  dot::use framework.console.prompt
  framework.console.prompt::can_ask || return 1
  framework.console.prompt::question "$question" >&2
  for ((index = 1; index <= $#; index++)); do
    framework.console.output::emit 2 "$index) ${!index}"
  done
  while :; do
    # shellcheck disable=SC2059
    defaults=$(printf '%s' "${checked# }" | sed 's/ *$//; s/ /,/g')
    read -r -p "$(printf "$UI_HINT_CHOICES" "$#")${defaults:+[$defaults] }" reply || return 1
    [ -n "$reply" ] || reply="$checked"
    reply="${reply//,/ }"
    valid=true
    for number in $reply; do
      case "$number" in
        *[!0-9]* | 0*) valid=false ;;
        *) [ "$number" -le $# ] || valid=false ;;
      esac
    done
    ! $valid || break
    framework.console.output::line "$UI_HINT_INVALID" >&2
  done
  for ((index = 1; index <= $#; index++)); do
    case " $reply " in
      *" $index "*) printf '%s\n' "${!index}" ;;
    esac
  done
}
