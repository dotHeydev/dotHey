#!/usr/bin/env bash

# The dot alias: one line in the user's shell rc file, so typing dot runs
# ./dot, or dotdot's own entry when that link is missing. It sits between
# markers, so it's added once and taken back exactly.

dot::use framework.helpers.fs

ALIAS_SHELLS=" bash zsh fish ksh mksh tcsh csh "
ALIAS_OPEN="# dotdot"
ALIAS_CLOSE="# /dotdot"

# The user's shell, by its login shell ($SHELL): one of ALIAS_SHELLS, or
# nothing.
core.modules.setup.alias::shell() {
  local shell="${SHELL##*/}"
  [[ "$ALIAS_SHELLS" != *" $shell "* ]] || printf '%s\n' "$shell"
}

# The rc file <shell> reads as it starts.
core.modules.setup.alias::file() {
  case "$1" in
    bash)
      if [ "$(uname -s 2>/dev/null)" = Darwin ]; then printf '%s\n' "$HOME/.bash_profile"; else printf '%s\n' "$HOME/.bashrc"; fi
      ;;
    zsh) printf '%s\n' "${ZDOTDIR:-$HOME}/.zshrc" ;;
    fish) printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/fish/config.fish" ;;
    ksh) printf '%s\n' "$HOME/.kshrc" ;;
    mksh) printf '%s\n' "$HOME/.mkshrc" ;;
    tcsh) printf '%s\n' "$HOME/.tcshrc" ;;
    csh) printf '%s\n' "$HOME/.cshrc" ;;
    *) return 1 ;;
  esac
}

# The alias in <shell>'s syntax (POSIX's for any other): ./dot, or the entry
# at <entry> (a project path) when ./dot is missing.
core.modules.setup.alias::line() {
  local shell="$1" entry="$2"
  case "$shell" in
    fish) printf "alias dot 'bash (test -e dot; and echo dot; or echo %s)'\n" "$entry" ;;
    tcsh | csh) printf "alias dot 'bash \`test -e dot && echo dot || echo %s\`'\n" "$entry" ;;
    *) printf "alias dot='bash \$([ -e dot ] && echo dot || echo %s)'\n" "$entry" ;;
  esac
}

# The line between dotdot's markers in <file>, if any.
core.modules.setup.alias::current() {
  [ -f "$1" ] || return 1
  awk -v opening="$ALIAS_OPEN" -v closing="$ALIAS_CLOSE" '$0 == opening { on = 1; next } $0 == closing { on = 0; next } on { print; found = 1 } END { exit !found }' "$1"
}

# <file> without dotdot's block.
core.modules.setup.alias::without() {
  awk -v opening="$ALIAS_OPEN" -v closing="$ALIAS_CLOSE" '$0 == opening { on = 1; next } on && $0 == closing { on = 0; next } !on' "$1"
}

# <file>, or the file it links to: a dotfiles manager's link stays a link.
core.modules.setup.alias::target() {
  if [ -L "$1" ]; then framework.helpers.fs::resolve "$1"; else printf '%s\n' "$1"; fi
}

# <line> as dotdot's block in <file>: in place of the one there, or appended.
core.modules.setup.alias::write() {
  local file line="$2" kept=""
  file=$(core.modules.setup.alias::target "$1") || { dot::raise "Couldn't follow the link $1."; return 1; }
  mkdir -p -- "$(dirname -- "$file")" || { dot::raise "Couldn't create $(dirname -- "$file")."; return 1; }
  # Failing to read the file stops here, never writing over it.
  [ ! -f "$file" ] || kept=$(core.modules.setup.alias::without "$file") || { dot::raise "Couldn't read $file."; return 1; }
  { [ -z "$kept" ] || printf '%s\n\n' "$kept"; printf '%s\n%s\n%s\n' "$ALIAS_OPEN" "$line" "$ALIAS_CLOSE"; } \
    | framework.helpers.fs::write "$file" || { dot::raise "Couldn't write $file."; return 1; }
}

# <file> with dotdot's block taken out.
core.modules.setup.alias::remove() {
  local file
  file=$(core.modules.setup.alias::target "$1") || { dot::raise "Couldn't follow the link $1."; return 1; }
  local kept
  kept=$(core.modules.setup.alias::without "$file") || { dot::raise "Couldn't read $file."; return 1; }
  printf '%s\n' "$kept" | framework.helpers.fs::write "$file" || { dot::raise "Couldn't write $file."; return 1; }
}
