#!/usr/bin/env bash
# install.sh — install dotdot into the current folder.
#
# Downloads dotdot from the repo's main branch, places its dist/ here as
# .dot/ (or --dir <path>), links dotdot's entry point as ./dot, and runs dot
# link -y for its default links. It only installs: bash dot setup links the
# harnesses, which it offers to run (or runs, given setup flags). Nothing that
# already exists is overwritten: an existing dotdot is offered an update or a
# setup instead. Plugins are never installed here: add the ones you trust
# afterwards with bash dot plugins:add <owner>/<name>.
# Output stays quiet: progress lines, then the result; a failing step shows
# its output.
#
#   curl -fsSL https://raw.githubusercontent.com/dotdot-sh/dotdot/main/install.sh | bash
#   curl … | bash -s -- --dir .agents/.dot --harness claude,cursor --strategy combine --yes

set -euo pipefail

REPO="dotdot-sh/dotdot"
BRANCH="main"
ARCHIVE_URL="https://github.com/$REPO/archive/refs/heads/$BRANCH.tar.gz"
SOURCE_DIR="dist"
MIGRATIONS_DIR=".core/system/migrations"
SETTINGS_FILE="dot.json"
JSON_HELPER=".core/framework/helpers/json.sh"
DEFAULT_DIR=".dot"
ENTRY_LINK="dot"
BIN_PATH=".core/system/bin/dot"
BOOT_FILE=".core/system/boot.sh"
TEMP_PREFIX=".dot-install."
REQUIRED_COMMANDS=(curl tar gzip mktemp ln mv)
# dotdot's spinner: one frame every SPINNER_INTERVAL seconds.
SPINNER_FRAMES=(' ·●' ' •⏺' ' ⏺•' ' ●·' ' ⏺•' ' •⏺' ' ·●')
SPINNER_INTERVAL=0.07
USAGE="Usage: bash install.sh [--dir <path>] [--harness <a,b>] [--strategy combine|own] [--yes]"

main() {
  local GREEN="" RED="" YELLOW="" BLUE="" BOLD="" RESET=""
  if [ -t 1 ] && [ -z "${NO_COLOR-}" ]; then
    GREEN=$'\033[32m' RED=$'\033[31m' YELLOW=$'\033[33m' BLUE=$'\033[34m' BOLD=$'\033[1m' RESET=$'\033[0m'
  fi
  local name="${BOLD}dotdot${RESET}"
  DOTDOT_DIR="$DEFAULT_DIR"
  SETUP_FLAGS=()
  parse_arguments "$@"
  ENTRY_POINT="$DOTDOT_DIR/$BIN_PATH"
  base="$PWD"
  check_requirements
  check_place
  check_existing

  temp=$(mktemp -d "$base/$TEMP_PREFIX"XXXXXX) || fail "Couldn't create a temporary directory in $base; nothing was installed."
  trap 'rm -rf -- "$temp"' EXIT
  trap 'exit 130' INT TERM HUP
  log="$temp/log"
  spin "Downloading $name…" download_and_unpack
  local source
  source=$(find_source "$temp/tree") || fail "Couldn't find dotdot in the download ($SOURCE_DIR/$BOOT_FILE is missing); nothing was installed."

  printf 'Getting %s ready for your project…\n' "$name"
  check_existing
  rename_paths "$source/$SOURCE_DIR"
  mkdir -p -- "$(dirname -- "$base/$DOTDOT_DIR")"
  mv -- "$source/$SOURCE_DIR" "$base/$DOTDOT_DIR" || fail "Couldn't place dotdot at $base/$DOTDOT_DIR."
  record_version "$temp/dotdot.tar.gz"
  record_migrations
  ln -s -- "$ENTRY_POINT" "$base/$ENTRY_LINK" || fail "Couldn't link $base/$ENTRY_LINK."
  quietly "Link" env DOT_INTERNAL_CALL=1 bash "$base/$ENTRY_LINK" link -y
  quietly "Checking bash $ENTRY_LINK" bash "$base/$ENTRY_LINK"

  printf '\n%s%s✓%s %s is installed in %s/.\n' "$BOLD" "$GREEN" "$RESET" "$name" "$DOTDOT_DIR"
  if [ ${#SETUP_FLAGS[@]} -gt 0 ]; then
    printf '\n'
    DOT_INTERNAL_CALL=1 bash "$base/$ENTRY_LINK" setup "${SETUP_FLAGS[@]}" || fail "The setup didn't finish; run it again with: bash $ENTRY_LINK setup"
  elif can_prompt; then
    offer_setup
  else
    next_steps
  fi
}

# Reads the flags: --dir for the installer, the setup flags handed to bash
# dot setup.
parse_arguments() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --dir)
        [ $# -ge 2 ] || fail "--dir needs a value. $USAGE"
        DOTDOT_DIR="${2%/}"
        shift
        ;;
      --harness | --strategy)
        [ $# -ge 2 ] || fail "$1 needs a value. $USAGE"
        SETUP_FLAGS+=("$1" "$2")
        shift
        ;;
      -y | --yes) SETUP_FLAGS+=(--yes) ;;
      -h | --help) printf '%s\n' "$USAGE"; exit 0 ;;
      *) fail "Unknown argument: $1. $USAGE" ;;
    esac
    shift
  done
}

# Whether a person can answer: a terminal to read from, and no agent, CI, or
# --no-input asking for none.
can_prompt() {
  [ -z "${AI_AGENT-}" ] && [ "${CLAUDECODE-}" != 1 ] && [ "${DOT_NO_INPUT-}" != 1 ] && [ -z "${CI-}" ] \
    && { : < /dev/tty; } 2>/dev/null
}

# A numbered choice read from the terminal, even when stdin is the script;
# prints the number picked.
choose() {
  local question="$1" reply index=1 option
  shift
  {
    printf '\n%s%s%s\n' "$BOLD" "$question" "$RESET"
    for option in "$@"; do
      printf '  %s) %s\n' "$index" "$option"
      index=$((index + 1))
    done
    printf 'Choose 1–%s [1]: ' "$#"
  } >&2
  read -r reply < /dev/tty || reply=""
  printf '%s\n' "${reply:-1}"
}

offer_setup() {
  case "$(choose "Set dotdot up for this project now?" "Here, step by step (bash $ENTRY_LINK setup)" "With your agent: tell it \"set up dotdot\"" "Later")" in
    1) bash "$base/$ENTRY_LINK" setup < /dev/tty || fail "The setup didn't finish; run it again with: bash $ENTRY_LINK setup" ;;
    2) printf "   %s%s→%s Tell your coding agent \"set up dotdot\"; it takes it from there.\n" "$BOLD" "$BLUE" "$RESET" ;;
    *) next_steps ;;
  esac
}

next_steps() {
  printf '   %s%s→%s Set it up for your harnesses: %sbash %s setup%s\n' "$BOLD" "$BLUE" "$RESET" "$BOLD" "$ENTRY_LINK" "$RESET"
  printf "   %s%s→%s Or tell your coding agent \"set up dotdot\"; it takes it from there.\n" "$BOLD" "$BLUE" "$RESET"
  printf '   %s%s→%s See all commands: %sbash %s%s\n' "$BOLD" "$BLUE" "$RESET" "$BOLD" "$ENTRY_LINK" "$RESET"
}

fail() {
  printf '%s%s✗%s %s\n\n' "$BOLD" "$RED" "$RESET" "$*" >&2
  exit 1
}

# Runs "$@" with its output kept in $log, shown only if it fails as step $1.
quietly() {
  local label="$1"
  shift
  if ! "$@" >"$log" 2>&1; then
    printf "%s%s✗%s %s didn't finish:\n" "$BOLD" "$RED" "$RESET" "$label" >&2
    sed 's/^/   /' "$log" >&2
    fail "Please fix the errors above, then run: bash $ENTRY_LINK link"
  fi
}


check_requirements() {
  local command missing=()
  for command in "${REQUIRED_COMMANDS[@]}"; do
    command -v "$command" >/dev/null || missing+=("$command")
  done
  [ ${#missing[@]} -eq 0 ] || fail "dotdot needs ${missing[*]}, which isn't installed here."
}

# Refuses a --dir outside the project, in .git/, or onto .env or the entry.
check_place() {
  if [ "$base" = "/" ] || [ "$base" = "${HOME-}" ]; then
    fail "Please run this from your project's directory, not $base."
  fi
  [ -w "$base" ] || fail "Can't write to $base; please check its permissions."
  case "/$DOTDOT_DIR/" in
    //* | */../* | */./* | */.git/* | "/$ENTRY_LINK/" | /.env/) fail "dotdot can't live in $DOTDOT_DIR: it must be a place in the project, outside .git/." ;;
  esac
}

# An existing dotdot (the dot entry, or the place taken) is never installed
# over: at a terminal, it is offered an update or a setup instead.
check_existing() {
  local name
  for name in "$DOTDOT_DIR" "$ENTRY_LINK"; do
    [ -e "$base/$name" ] || [ -L "$base/$name" ] || continue
    if [ -f "$base/$ENTRY_LINK" ] && can_prompt; then
      case "$(choose "dotdot is already installed here." "Update it (bash $ENTRY_LINK upgrade)" "Run its setup again (bash $ENTRY_LINK setup)" "Cancel")" in
        1) exec bash "$base/$ENTRY_LINK" upgrade < /dev/tty ;;
        2) exec bash "$base/$ENTRY_LINK" setup < /dev/tty ;;
      esac
      exit 0
    fi
    fail "$base/$name already exists, so nothing was installed. To update dotdot, run: bash $ENTRY_LINK upgrade; to set it up again: bash $ENTRY_LINK setup"
  done
}

# Writes dotdot's own paths for a --dir other than .dot/, as bash dot upgrade
# does for the files it brings.
rename_paths() {
  local source="$1" file replacement
  [ "$DOTDOT_DIR" != "$DEFAULT_DIR" ] || return 0
  replacement=$(printf '%s' "$DOTDOT_DIR/" | sed 's/[|&\\]/\\&/g')
  grep -rl --null --binary-files=without-match -F "$DEFAULT_DIR/" "$source" | while IFS= read -r -d '' file; do
    sed "s|\\$DEFAULT_DIR/|$replacement|g" "$file" > "$file.renamed" && cat -- "$file.renamed" > "$file" && rm -f -- "$file.renamed"
  done
}

# DOT_INSTALL_ARCHIVE, a local archive, replaces the download (for tests).
download_and_unpack() {
  mkdir -p -- "$temp/tree"
  if [ -n "${DOT_INSTALL_ARCHIVE-}" ]; then
    [ -f "$DOT_INSTALL_ARCHIVE" ] && cp -- "$DOT_INSTALL_ARCHIVE" "$temp/dotdot.tar.gz"
  else
    curl --proto '=https' --tlsv1.2 -fsSL -o "$temp/dotdot.tar.gz" "$ARCHIVE_URL"
  fi
  tar -xzf "$temp/dotdot.tar.gz" -C "$temp/tree"
}

# Prints label $1, with a spinner after it on a terminal while "$@" runs in
# the background; its output is kept in $log and shown only if it fails.
spin() {
  local label="$1" pid tick=0
  shift
  "$@" >"$log" 2>&1 &
  pid=$!
  if [ -t 1 ]; then
    while kill -0 "$pid" 2>/dev/null; do
      printf '\r%s%s ' "$label" "${SPINNER_FRAMES[$((tick % ${#SPINNER_FRAMES[@]}))]}"
      tick=$((tick + 1))
      sleep "$SPINNER_INTERVAL"
    done
    printf '\r\033[K'
  fi
  printf '%s\n' "$label"
  if ! wait "$pid"; then
    printf "%s%s✗%s The download didn't work:\n" "$BOLD" "$RED" "$RESET" >&2
    sed 's/^/   /' "$log" >&2
    fail "Nothing was installed."
  fi
}

# Prints the unpacked archive's single top-level folder, named after the repo
# and branch, which holds dotdot's source.
find_source() {
  local top
  for top in "$1"/*/; do
    if [ -f "$top$SOURCE_DIR/$BOOT_FILE" ]; then
      printf '%s\n' "${top%/}"
      return
    fi
  done
  return 1
}

# Sets <path> to <json> in the state of .dot/dot.json with dotdot's
# own JSON helper, the rest of the file left as shipped.
set_state() {
  local settings="$base/$DOTDOT_DIR/$SETTINGS_FILE" document
  # shellcheck source=/dev/null
  document=$(. "$base/$DOTDOT_DIR/$JSON_HELPER" && framework.helpers.json::set "$(cat -- "$settings")" ".state.$1" "$2" --keep-format) \
    && printf '%s\n' "$document" > "$settings" \
    || printf "%s%s! Couldn't record state.%s in %s.%s\n" "$BOLD" "$YELLOW" "$1" "$SETTINGS_FILE" "$RESET"
}

# A fresh install has nothing to migrate: every migration it ships is applied.
record_migrations() {
  local file list=""
  for file in "$base/$DOTDOT_DIR/$MIGRATIONS_DIR"/*.sh; do
    [ -f "$file" ] || continue
    file="${file##*/}"
    list="$list${list:+, }\"${file%.sh}\""
  done
  set_state migrations "[$list]"
}

# GitHub archives carry their commit in a pax header; dot upgrade diffs
# against it to know what it may remove. Without it, the first update just
# removes nothing.
record_version() {
  local commit
  commit=$(gzip -dc -- "$1" 2>/dev/null | head -c 1024 | tr -d '\000' | grep -ao 'comment=[0-9a-f]\{40\}' | cut -d= -f2 || true)
  if [ -n "$commit" ]; then
    set_state version "\"$commit\""
  else
    printf "%s%s! Couldn't read the installed version; the first bash dot upgrade won't clean up stale files.%s\n" "$BOLD" "$YELLOW" "$RESET"
  fi
}

# Called last, so a download cut short runs nothing at all.
main "$@"
