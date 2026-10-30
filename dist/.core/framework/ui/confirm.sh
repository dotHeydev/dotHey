# shellcheck shell=bash

hey::use framework.ui.screen

# Yes or no to <question>, <default> (y or n, n by default) chosen first:
# ←/→ to change it, Enter to confirm, or y or n straight away. Status 0 for
# yes. Without keys to read, a typed y/n; with no one to answer, status 1.
framework.ui.confirm::ask() {
  local question="$1" default="${2:-n}" yes=true
  [ "$default" = y ] || yes=false
  if ! framework.ui.screen::reads_keys; then
    hey::use framework.console.prompt
    framework.console.prompt::confirm "$question" "$default"
    return
  fi
  framework.ui.screen::begin
  while :; do
    framework.ui.screen::draw "$(framework.ui.confirm::frame "$question" "$yes")"
    framework.ui.screen::read_key
    case "$UI_KEY" in
      left | right | up | down | tab) if $yes; then yes=false; else yes=true; fi ;;
      y | Y) yes=true; break ;;
      n | N) yes=false; break ;;
      enter) break ;;
      escape | q) framework.ui.screen::cancel ;;
      eof) framework.ui.screen::end; framework.ui.screen::erase; return 1 ;;
    esac
  done
  framework.ui.screen::end
  if $yes; then
    framework.ui.screen::answer "$question" "$UI_LABEL_YES" "$UI_STYLE_ANSWER_YES"
    return 0
  fi
  framework.ui.screen::answer "$question" "$UI_LABEL_NO" "$UI_STYLE_ANSWER_NO"
  return 1
}

# confirm's frame for <question>, Yes chosen when <yes> is true.
framework.ui.confirm::frame() {
  printf '%s  %s' "$(framework.ui.screen::question "$1")" "$(framework.ui.confirm::choices "$2")"
}

# Yes and No, the one chosen (<yes> or not) on its own color, or in
# brackets where colors are off.
framework.ui.confirm::choices() {
  local yes="$1" chosen other label_yes label_no
  if $yes; then
    chosen=" $UI_LABEL_YES " other=" $UI_LABEL_NO "
  else
    chosen=" $UI_LABEL_NO " other=" $UI_LABEL_YES "
  fi
  if framework.console.output::paints 2; then
    if $yes; then chosen=$(framework.console.output::paint "$UI_STYLE_YES" "$chosen"); else chosen=$(framework.console.output::paint "$UI_STYLE_NO" "$chosen"); fi
    other=$(framework.console.output::paint "$UI_STYLE_IDLE" "$other")
  else
    chosen="[${chosen:1:${#chosen}-2}]"
  fi
  label_yes="$chosen" label_no="$other"
  $yes || label_yes="$other" label_no="$chosen"
  printf '%s %s %s' "$(framework.console.output::paint "$UI_STYLE_POINTER" "$UI_GLYPH_POINTER")" "$label_yes" "$label_no"
}
