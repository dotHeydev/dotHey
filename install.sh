#!/usr/bin/env bash
# install.sh — install dotdot into the current folder.
#
# Downloads dotdot from the repo's main branch, places its dist/ here as
# .dot/, links dotdot's entry point as ./dot, and runs dot link -y. Nothing
# that already exists is overwritten: an existing .dot/ or dot stops the
# install untouched. Plugins are never installed here: add the ones you trust
# afterwards with bash dot plugins:add <owner>/<name>.
# Output stays quiet: progress lines, then the result; a failing step shows
# its output.

set -euo pipefail

REPO="dotdot-sh/dotdot"
BRANCH="main"
ARCHIVE_URL="https://github.com/$REPO/archive/refs/heads/$BRANCH.tar.gz"
SOURCE_DIR="dist"
MIGRATIONS_DIR=".core/system/migrations"
SETTINGS_FILE="dot.json"
JSON_HELPER=".core/framework/helpers/json.sh"
DOTDOT_DIR=".dot"
ENTRY_LINK="dot"
ENTRY_POINT="$DOTDOT_DIR/.core/system/bin/dot"
BOOT_FILE=".core/system/boot.sh"
TEMP_PREFIX=".dot-install."
REQUIRED_COMMANDS=(curl tar gzip mktemp ln mv)
# dotdot's spinner: one frame every SPINNER_INTERVAL seconds.
SPINNER_FRAMES=(' ·●' ' •⏺' ' ⏺•' ' ●·' ' ⏺•' ' •⏺' ' ·●')
SPINNER_INTERVAL=0.07

main() {
  local GREEN="" RED="" YELLOW="" BOLD="" RESET=""
  if [ -t 1 ]; then
    GREEN=$'\033[32m' RED=$'\033[31m' YELLOW=$'\033[33m' BOLD=$'\033[1m' RESET=$'\033[0m'
  fi
  local name="${BOLD}dotdot${RESET}"
  base="$PWD"
  check_requirements
  check_destination

  temp=$(mktemp -d "$base/$TEMP_PREFIX"XXXXXX) || fail "Couldn't create a temporary directory in $base; nothing was installed."
  trap 'rm -rf -- "$temp"' EXIT
  trap 'exit 130' INT TERM HUP
  log="$temp/log"
  spin "Downloading $name…" download_and_unpack
  local source
  source=$(find_source "$temp/tree") || fail "Couldn't find dotdot in the download ($SOURCE_DIR/$BOOT_FILE is missing); nothing was installed."

  printf 'Getting %s ready for your project…\n' "$name"
  check_destination
  mv -- "$source/$SOURCE_DIR" "$base/$DOTDOT_DIR" || fail "Couldn't place dotdot at $base/$DOTDOT_DIR."
  record_version "$temp/dotdot.tar.gz"
  record_migrations
  ln -s -- "$ENTRY_POINT" "$base/$ENTRY_LINK" || fail "Couldn't link $base/$ENTRY_LINK."
  quietly "Link" env DOT_INTERNAL_CALL=1 bash "$base/$ENTRY_LINK" link -y
  quietly "Checking bash $ENTRY_LINK" bash "$base/$ENTRY_LINK"

  printf '\n%s✓ %s is ready!%s\n\n' "$GREEN" "$name$GREEN" "$RESET"
  printf "   → Tell your coding agent that you're using %s and it'll take it from there.\n" "$name"
  printf "     Or fill in your project's context manually in %s%s/%s.\n" "$BOLD" "$DOTDOT_DIR" "$RESET"
  printf '   → Using Claude Code? %sbash %s plugins:add dotdot-sh/claude-code%s\n' "$BOLD" "$ENTRY_LINK" "$RESET"
  printf '   → See all commands: %sbash %s%s\n' "$BOLD" "$ENTRY_LINK" "$RESET"
  printf '\n%s🚀 Build something amazing!%s\n\n' "$BOLD" "$RESET"
}

fail() {
  printf '%s❌ %s%s\n\n' "$RED" "$*" "$RESET" >&2
  exit 1
}

# Runs "$@" with its output kept in $log, shown only if it fails as step $1.
quietly() {
  local label="$1"
  shift
  if ! "$@" >"$log" 2>&1; then
    printf "%s❌ %s didn't finish:%s\n" "$RED" "$label" "$RESET" >&2
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

check_destination() {
  local name
  if [ "$base" = "/" ] || [ "$base" = "${HOME-}" ]; then
    fail "Please run this from your project's directory, not $base."
  fi
  [ -w "$base" ] || fail "Can't write to $base; please check its permissions."
  for name in "$DOTDOT_DIR" "$ENTRY_LINK"; do
    if [ -e "$base/$name" ] || [ -L "$base/$name" ]; then
      fail "$base/$name already exists, so nothing was installed."
    fi
  done
}

download_and_unpack() {
  mkdir -p -- "$temp/tree"
  curl --proto '=https' --tlsv1.2 -fsSL -o "$temp/dotdot.tar.gz" "$ARCHIVE_URL"
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
    printf "%s❌ The download didn't work:%s\n" "$RED" "$RESET" >&2
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
    || printf "%s⚠️  Couldn't record state.%s in %s.%s\n" "$YELLOW" "$1" "$SETTINGS_FILE" "$RESET"
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

# GitHub archives carry their commit in a pax header; dot update diffs
# against it to know what it may remove. Without it, the first update just
# removes nothing.
record_version() {
  local commit
  commit=$(gzip -dc -- "$1" 2>/dev/null | head -c 1024 | tr -d '\000' | grep -ao 'comment=[0-9a-f]\{40\}' | cut -d= -f2 || true)
  if [ -n "$commit" ]; then
    set_state version "\"$commit\""
  else
    printf "%s⚠️  Couldn't read the installed version; the first bash dot update won't clean up stale files.%s\n" "$YELLOW" "$RESET"
  fi
}

# Called last, so a download cut short runs nothing at all.
main "$@"
