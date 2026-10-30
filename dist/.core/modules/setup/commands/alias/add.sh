# shellcheck shell=bash

DESCRIPTION="Add the hey alias to your shell, to type hey instead of bash hey."
DOCS="getting-started/setup"

hey::use framework.console.args framework.console.output framework.console.prompt framework.ui.checkbox core.modules.setup.alias

usage() {
  cat <<EOF
Adds one line to the rc file of each shell you pick, so hey runs ./hey (or
dotHey's own entry when that link is missing) and you no longer type bash
first. It shows every file and line, and asks before writing; run it again
after moving dotHey to update the lines.

Usage:
  bash hey alias:add [--shell <a,b>] [-y, --yes]

Options:
  --shell <a,b>   The shells to add it to: ${ALIAS_SHELLS[*]}. Without it,
                  a terminal asks, yours (\$SHELL) checked; with -y, yours.
  -y, --yes       Add it without asking. Only at a terminal, or when dotHey
                  itself runs it.
  -h, --help      Show this help.

Examples:
  bash hey alias:add
  bash hey alias:add --shell zsh,bash --yes

Notes:
  - mksh counts as ksh (~/.mkshrc), and csh as tcsh (~/.cshrc).
  - It works in new terminals, or in this one after: source <file>.
  - bash hey alias:remove takes it back.
EOF
}

# A path with the home folder as ~, for people to read.
shown() {
  printf '%s\n' "${1/#"$HOME"/"~"}"
}

# The shells picked at the terminal, yours checked, each with its file.
ask_shells() {
  local mine="$1" shell index=0 checked="" labels=() picked
  for shell in "${ALIAS_SHELLS[@]}"; do
    index=$((index + 1))
    labels+=("$shell  $(framework.console.output::paint "$UI_STYLE_MUTED" "($(shown "$(core.modules.setup.alias::file "$shell")"))")")
    [ "$shell" != "$mine" ] || checked="$index"
  done
  picked=$(framework.ui.checkbox::ask --checked "$checked" "Which shells should get the hey alias?" "${labels[@]}") || return 1
  printf '%s\n' "$picked" | awk '{ print $1 }'
}

handle() {
  local confirmed=false shells="" shell file line current changes=0 entry written=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --shell)
        framework.console.args::require_value "$@"
        shells=$(framework.console.args::split "$2" | tr '\n' ' ')
        shift
        ;;
      -y | --yes) confirmed=true ;;
      *) framework.console.args::unexpected "$1" ;;
    esac
    shift
  done
  ! $confirmed || guards::skip_confirmation \
    || framework.console.output::fail_as "$EXIT_PRECONDITION" "-y only works in a terminal, so nothing changed unseen." "$OUTPUT_MANUAL_RUN bash hey alias:add"
  for shell in $shells; do
    core.modules.setup.alias::is_shell "$shell" || framework.console.args::invalid "There's no shell $shell to add it to; pick from: ${ALIAS_SHELLS[*]}."
  done
  entry="${HEY_BIN#"$BASE"/}"
  if [ -z "$shells" ]; then
    if $confirmed; then
      shells=$(core.modules.setup.alias::shell)
      [ -n "$shells" ] || framework.console.args::invalid "Couldn't tell which shell you use (\$SHELL is ${SHELL:-unset}); name it with --shell."
    else
      framework.console.prompt::can_ask || framework.console.output::fail_as "$EXIT_PRECONDITION" "Which shells should get the hey alias? No one is at a terminal to ask." \
        "$OUTPUT_MANUAL_RUN bash hey alias:add"
      shells=$(ask_shells "$(core.modules.setup.alias::shell)") || exit 1
      [ -n "$shells" ] || { framework.console.output::line "No shell picked, so nothing changed."; return 0; }
    fi
  fi
  framework.console.output::line "This adds the hey alias to:"
  for shell in $shells; do
    file=$(core.modules.setup.alias::file "$shell")
    line=$(core.modules.setup.alias::line "$shell" "$entry")
    if current=$(core.modules.setup.alias::current "$file") && [ "$current" = "$line" ]; then
      framework.console.output::detail "$(shown "$file"), already there"
      continue
    fi
    framework.console.output::detail "$(shown "$file"): $(framework.console.output::code "$line")"
    changes=$((changes + 1))
  done
  if [ "$changes" -eq 0 ]; then
    framework.console.output::success "The hey alias is already in place."
    return 0
  fi
  $confirmed || framework.console.prompt::confirm_or_exit "Do you want to add it?" y "bash hey alias:add"
  for shell in $shells; do
    file=$(core.modules.setup.alias::file "$shell")
    line=$(core.modules.setup.alias::line "$shell" "$entry")
    [ "$(core.modules.setup.alias::current "$file" 2>/dev/null)" != "$line" ] || continue
    core.modules.setup.alias::write "$file" "$line" || framework.console.output::fail "Couldn't add the alias to $(shown "$file")."
    written+=("$(shown "$file")")
  done
  framework.console.output::success "Added the hey alias."
  if [ ${#written[@]} -eq 1 ]; then
    framework.console.output::next "It works in new terminals, or in this one after: source ${written[0]}"
  else
    framework.console.output::next "It works in new terminals, or in an open one after sourcing its file."
  fi
}
