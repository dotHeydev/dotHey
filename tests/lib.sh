#!/usr/bin/env bash

TESTS_DIR=$(CDPATH='' cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPOSITORY_DIR=$(dirname -- "$TESTS_DIR")
SOURCE_DIR="$REPOSITORY_DIR/dist"
DOTDOT_DIRECTORY=".dot"

sandbox::create() {
  SANDBOX=$(mktemp -d)
  SANDBOX=$(cd -P -- "$SANDBOX" && pwd)
  cp -a "$SOURCE_DIR" "$SANDBOX/$DOTDOT_DIRECTORY"
  ln -s "$DOTDOT_DIRECTORY/.core/system/bin/dot" "$SANDBOX/dot"
  DOTDOT="$SANDBOX/$DOTDOT_DIRECTORY"
  sandbox::settings
}

# Writes .dot/dot.json as the installer leaves it (every migration applied),
# every feature flag on unless the members given set featureFlags, plus the
# members given, e.g. '"tasks": {"service": "x"}'.
sandbox::settings() {
  local file list="" flags
  for file in "$DOTDOT"/.core/system/migrations/*.sh; do
    [ -f "$file" ] || continue
    file="${file##*/}"
    list="$list${list:+, }\"${file%.sh}\""
  done
  case "${1-}" in
    *'"featureFlags"'*) flags="" ;;
    *) flags=$(sed -n '/"featureFlags"/,/}/{s/: *false/: true/;p;}' "$DOTDOT/.core/dot.defaults.json" | tr -d '\n') ;;
  esac
  printf '{"state": {"version": "", "commit": "", "isReady": false, "migrations": [%s]}%s%s}\n' "$list" "${flags:+, ${flags%,}}" "${1:+, $1}" > "$DOTDOT/dot.json"
}

# A secret-shaped value built at run time, <count> times "F4k3", so no
# token-like literal sits in the source for a leak scanner to flag.
fake_secret() {
  local count="${1:-5}" value=""
  while [ "$count" -gt 0 ]; do
    value="${value}F4k3"
    count=$((count - 1))
  done
  printf '%s' "$value"
}

sandbox::destroy() {
  [ -z "${SANDBOX-}" ] || rm -rf -- "$SANDBOX"
}

run() {
  local status=0
  OUTPUT=$(cd "$SANDBOX" && DOT_INTERNAL_CALL="${DOT_INTERNAL_CALL-1}" "$@" 2>"$SANDBOX/.stderr" </dev/null) || status=$?
  ERRORS=""
  IFS= read -r -d '' ERRORS < "$SANDBOX/.stderr" || true
  ERRORS="${ERRORS%$'\n'}"
  STATUS=$status
}

dot() {
  run bash ./dot "$@"
}

core() {
  local code="$1"
  run bash -c ". '$DOTDOT/.core/system/boot.sh'; set -euo pipefail; $code"
}

count_assertion() {
  [ -z "${ASSERTIONS_FILE-}" ] || printf '.' >> "$ASSERTIONS_FILE"
}

fail() {
  printf '%s\n' "$1" >&2
  printf '  stdout: %s\n  stderr: %s\n  status: %s\n' "${OUTPUT-}" "${ERRORS-}" "${STATUS-}" >&2
  exit 1
}

assert_success() {
  count_assertion
  [ "$STATUS" -eq 0 ] || fail "expected success${1:+: $1}"
}

assert_failure() {
  count_assertion
  [ "$STATUS" -ne 0 ] || fail "expected failure${1:+: $1}"
}

assert_equal() {
  count_assertion
  [ "$1" = "$2" ] || fail "expected [$2], got [$1]"
}

assert_contains() {
  count_assertion
  case "$1" in
    *"$2"*) ;;
    *) fail "expected to contain [$2]" ;;
  esac
}

assert_not_contains() {
  count_assertion
  case "$1" in
    *"$2"*) fail "expected not to contain [$2]" ;;
  esac
}

assert_file() {
  count_assertion
  [ -f "$1" ] || fail "expected file $1"
}

assert_no_file() {
  count_assertion
  [ ! -e "$1" ] && [ ! -L "$1" ] || fail "expected no file $1"
}

assert_link_to() {
  count_assertion
  [ -L "$1" ] || fail "expected a link at $1"
  [ "$(cd "$(dirname -- "$1")" && cd -P -- "$(dirname -- "$(readlink "$1")")" && pwd)/$(basename -- "$(readlink "$1")")" = "$2" ] \
    || fail "expected $1 to point at $2, got $(readlink "$1")"
}

add_plugin() {
  local plugin="$1" path="$2"
  core "dot::use core.system.plugins.console core.system.plugins.manifest core.system.plugins.service
    core.system.plugins.service::fetch $plugin '' $path
    core.system.plugins.manifest::validate \"\$PLUGIN_SOURCE\" $plugin
    core.system.plugins.console::install $plugin \"\$PLUGIN_SOURCE\"
    core.system.plugins.console::suggest --refresh-plugin $plugin"
  assert_success "add $plugin"
}

# Writes a plugin's dotdot/plugin.json in <directory>: the current plugin API
# and each "<kind>:<origin>-><destination>[-><destination>…]" given (kind
# link or append).
manifest() {
  local directory="$1" entry kind separator
  shift
  {
    printf '{"requires": 3, "description": "Test plugin."'
    for kind in link append; do
      printf ', "%s": {' "$kind"
      separator=""
      for entry in "$@"; do
        [ "${entry%%:*}" = "$kind" ] || continue
        entry="${entry#*:}"
        printf '%s"%s": ["%s"]' "$separator" "${entry%%->*}" "$(printf '%s' "${entry#*->}" | sed 's/->/", "/g')"
        separator=", "
      done
      printf '}'
    done
    printf '}\n'
  } > "$directory/dotdot/plugin.json"
}

# Writes the links of .dot/dot.json from
# "<kind>:<origin>-><destination>[-><destination>…]" entries (kind link,
# append, or skip): the general ones.
links() {
  local entry kind separator=""
  sandbox::settings "\"links\": $({
    printf '{'
    for entry in "$@"; do
      [ "${entry%%:*}" = link ] || continue
      entry="${entry#*:}"
      printf '"%s": ["%s"], ' "${entry%%->*}" "$(printf '%s' "${entry#*->}" | sed 's/->/", "/g')"
    done
    for kind in append skip; do
      printf '"%s": {' "$kind"
      separator=""
      for entry in "$@"; do
        [ "${entry%%:*}" = "$kind" ] || continue
        entry="${entry#*:}"
        printf '%s"%s": ["%s"]' "$separator" "${entry%%->*}" "$(printf '%s' "${entry#*->}" | sed 's/->/", "/g')"
        separator=", "
      done
      printf '}, '
    done
    printf '"inactive": {}}'
  })"
}

# Rows on stdin, as read_map gives them, written as the links.
save_links() {
  printf "core.system.link.service::write_map | { map=\$(cat); framework.helpers.json::set \"\$(cat '%s')\" .links \"\$map\"; } > '%s.new' && mv '%s.new' '%s'" \
    "$DOTDOT/dot.json" "$DOTDOT/dot.json" "$DOTDOT/dot.json" "$DOTDOT/dot.json"
}

# Links a plugin's waiting links, as a user does.
take_suggestions() {
  dot plugins:link "$1" -y
  assert_success "activate the links of $1"
}

# Adds an entry to the general links: link, append, or skip.
add_entry() {
  core "dot::use core.system.link.service
    { core.system.link.service::read_map; printf '.\t%s\t%s\t%s\n' '$1' '$2' '$3'; } \
      | $(save_links)"
  assert_success "add $1 $2 -> $3"
}

# What <path> selects in the links, compact, one result per line.
map_value() {
  local path=".links$1"
  [ "$1" != . ] || path=".links"
  core "dot::use framework.helpers.json; framework.helpers.json::values \"\$(cat '$DOTDOT/dot.json')\" '$path'"
  printf '%s' "$OUTPUT"
}

# What <path> selects in the JSON <document>, one result per line, as
# framework.helpers.json::values prints it.
json_value() {
  printf '%s' "$1" > "$SANDBOX/.json"
  core "dot::use framework.helpers.json; framework.helpers.json::values \"\$(cat '$SANDBOX/.json')\" '$2'"
  printf '%s' "$OUTPUT"
}
