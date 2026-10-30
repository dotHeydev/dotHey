# shellcheck shell=bash

# The hey alias: one line in the user's shell rc file, so typing hey runs
# ./hey, or dotHey's own entry when that link is missing. It sits between
# markers, so it's added once and taken back exactly.

hey::use framework.helpers.fs

# The shells offered; mksh counts as ksh, and csh as tcsh.
ALIAS_SHELLS=(bash zsh fish ksh tcsh)
ALIAS_OPEN="# dothey"
ALIAS_CLOSE="# /dothey"

# The user's shell, by its login shell ($SHELL): one of ALIAS_SHELLS, or
# nothing.
core.modules.setup.alias::shell() {
  local shell="${SHELL##*/}"
  case "$shell" in
    mksh) shell=ksh ;;
    csh) shell=tcsh ;;
  esac
  core.modules.setup.alias::is_shell "$shell" && printf '%s\n' "$shell"
  return 0
}

core.modules.setup.alias::is_shell() {
  [[ " ${ALIAS_SHELLS[*]} " == *" $1 "* ]]
}

# The rc file <shell> reads as it starts.
core.modules.setup.alias::file() {
  case "$1" in
    bash)
      if [ "$(uname -s 2>/dev/null)" = Darwin ]; then printf '%s\n' "$HOME/.bash_profile"; else printf '%s\n' "$HOME/.bashrc"; fi
      ;;
    zsh) printf '%s\n' "${ZDOTDIR:-$HOME}/.zshrc" ;;
    fish) printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/fish/config.fish" ;;
    ksh) if [ "${SHELL##*/}" = mksh ]; then printf '%s\n' "$HOME/.mkshrc"; else printf '%s\n' "$HOME/.kshrc"; fi ;;
    tcsh) if [ "${SHELL##*/}" = csh ]; then printf '%s\n' "$HOME/.cshrc"; else printf '%s\n' "$HOME/.tcshrc"; fi ;;
    *) return 1 ;;
  esac
}

# The alias in <shell>'s syntax (POSIX's for any other): ./hey, or the entry
# at <entry> (a project path) when ./hey is missing.
core.modules.setup.alias::line() {
  local shell="$1" entry="$2"
  case "$shell" in
    fish) printf "alias hey 'bash (test -e hey; and echo hey; or echo %s)'\n" "$entry" ;;
    tcsh) printf "alias hey 'bash \`test -e hey && echo hey || echo %s\`'\n" "$entry" ;;
    *) printf "alias hey='bash \$([ -e hey ] && echo hey || echo %s)'\n" "$entry" ;;
  esac
}

# The line between dotHey's markers in <file>, if any.
core.modules.setup.alias::current() {
  [ -f "$1" ] || return 1
  awk -v opening="$ALIAS_OPEN" -v closing="$ALIAS_CLOSE" '$0 == opening { on = 1; next } $0 == closing { on = 0; next } on { print; found = 1 } END { exit !found }' "$1"
}

# <file> without dotHey's block.
core.modules.setup.alias::without() {
  awk -v opening="$ALIAS_OPEN" -v closing="$ALIAS_CLOSE" '$0 == opening { on = 1; next } on && $0 == closing { on = 0; next } !on' "$1"
}

# <file>, or the file it links to: a dotfiles manager's link stays a link.
core.modules.setup.alias::target() {
  if [ -L "$1" ]; then framework.helpers.fs::resolve "$1"; else printf '%s\n' "$1"; fi
}

# <line> as dotHey's block in <file>: in place of the one there, or appended.
core.modules.setup.alias::write() {
  local file line="$2" kept=""
  file=$(core.modules.setup.alias::target "$1") || { hey::raise "Couldn't follow the link $1."; return 1; }
  mkdir -p -- "$(dirname -- "$file")" || { hey::raise "Couldn't create $(dirname -- "$file")."; return 1; }
  # Failing to read the file stops here, never writing over it.
  [ ! -f "$file" ] || kept=$(core.modules.setup.alias::without "$file") || { hey::raise "Couldn't read $file."; return 1; }
  { [ -z "$kept" ] || printf '%s\n\n' "$kept"; printf '%s\n%s\n%s\n' "$ALIAS_OPEN" "$line" "$ALIAS_CLOSE"; } \
    | framework.helpers.fs::write "$file" || { hey::raise "Couldn't write $file."; return 1; }
}

# <file> with dotHey's block taken out.
core.modules.setup.alias::remove() {
  local file
  file=$(core.modules.setup.alias::target "$1") || { hey::raise "Couldn't follow the link $1."; return 1; }
  local kept
  kept=$(core.modules.setup.alias::without "$file") || { hey::raise "Couldn't read $file."; return 1; }
  printf '%s\n' "$kept" | framework.helpers.fs::write "$file" || { hey::raise "Couldn't write $file."; return 1; }
}
