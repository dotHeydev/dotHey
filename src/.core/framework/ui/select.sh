# shellcheck shell=bash

hey::use framework.ui.screen

# One of <option>..., picked with ↑/↓ (or its number) and Enter, printed.
# Without keys to read, a numbered list to type from; with no one to answer,
# status 1, for the command to fall back to its flags.
framework.ui.select::ask() {
  local question="$1" current=1 index
  shift
  if ! framework.ui.screen::reads_keys; then
    hey::use framework.console.prompt
    index=$(framework.console.prompt::choice "$question" "$@") || return 1
    printf '%s\n' "${!index}"
    return
  fi
  framework.ui.screen::begin
  while :; do
    framework.ui.screen::draw "$(framework.ui.select::frame "$question" "$current" "$@")"
    framework.ui.screen::read_key
    case "$UI_KEY" in
      up | left) current=$((current > 1 ? current - 1 : $#)) ;;
      down | right | tab) current=$((current < $# ? current + 1 : 1)) ;;
      [1-9]) [ "$UI_KEY" -gt $# ] || current=$UI_KEY ;;
      enter) break ;;
      escape | q) framework.ui.screen::cancel ;;
      eof) framework.ui.screen::end; framework.ui.screen::erase; return 1 ;;
    esac
  done
  framework.ui.screen::end
  framework.ui.screen::answer "$question" "${!current}"
  printf '%s\n' "${!current}"
}

# select's frame for <question>, <current> (1-based) hovered.
framework.ui.select::frame() {
  local question="$1" current="$2" index
  shift 2
  framework.ui.screen::question "$question"
  for ((index = 1; index <= $#; index++)); do
    if [ "$index" -eq "$current" ]; then
      printf '\n%s' "$(framework.ui.screen::option true "$UI_GLYPH_RADIO_ON" true "${!index}")"
    else
      printf '\n%s' "$(framework.ui.screen::option false "$UI_GLYPH_RADIO_OFF" false "${!index}")"
    fi
  done
  printf '\n%s' "$(framework.ui.screen::hint "$UI_HINT_SELECT")"
}
