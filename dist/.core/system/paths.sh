#!/usr/bin/env bash

BIN_DIR="$SYSTEM_DIR/bin"
DOT_BIN="$BIN_DIR/dot"
SYSTEM_PARTS=(plugins link update migrations)
MIGRATIONS_DIR="$SYSTEM_DIR/migrations"
CORE_MODULES=(onboarding ready setup frontmatter housekeeping notes xrays features decisions tasks release tui)
MODULE_COMMANDS_DIR="commands"
KEEP_FILE=".gitkeep"

# The project's settings (overrides, the links map, dotdot's state, and
# "@env:<KEY>" references into .env), the defaults dotdot ships, and the host
# project's .env, which alone holds secrets.
SETTINGS_FILE="$DOTDOT_ROOT/dot.json"
SETTINGS_DEFAULTS="$CORE_DIR/dot.defaults.json"
HOST_ENV_FILE="$BASE/.env"
LINK_MAP_SEPARATOR="->"

PLUGIN_MANIFEST="plugin.json"
PLUGIN_CONTEXT_DIR="context"
PLUGIN_STUBS_DIR="stubs"
PLUGIN_STUB_SUFFIX=".stub"

# The project's record folders, shipped with dotdot (each with a .gitkeep), and
# the prefix of their numbered files.
FEATURES_DIR="$DOTDOT_ROOT/Features"
FEATURE_PREFIX="f"
DECISIONS_DIR="$DOTDOT_ROOT/Decisions"
DECISION_PREFIX="d"
NOTES_DIR="$DOTDOT_ROOT/Notes"
NOTE_PREFIX="n"
XRAYS_DIR="$DOTDOT_ROOT/Xrays"
XRAY_PREFIX="x"
TASKS_DIR="$DOTDOT_ROOT/Tasks"
TASK_PREFIX="t"
PLUGINS_DIR="$DOTDOT_ROOT/.plugins"
PLUGINS_LOCK="$PLUGINS_DIR/plugins-lock.json"

USER_FILE="$DOTDOT_ROOT/USER.md"
USER_EXAMPLE_FILE="$DOTDOT_ROOT/USER.example.md"
ENTRY_LINK="$BASE/dot"

paths::in_dotdot() {
  local path="$1"
  case "$path" in
    /*) printf '%s\n' "$path"; return ;;
    "$DOTDOT_NAME") path="." ;;
    "$DOTDOT_NAME"/*) path="${path#*/}" ;;
  esac
  printf '%s\n' "$DOTDOT_ROOT/$path"
}

# The modules a feature flag turns off: each one dotdot's defaults list under
# featureFlags, unless the project turns its flag on. Read once per run
# (paths::read_flags), as every listing and lookup asks.
PATHS_DISABLED=""
PATHS_FLAGS_READ=false

paths::read_flags() {
  local module
  ! $PATHS_FLAGS_READ || return 0
  dot::use framework.helpers.json
  PATHS_DISABLED=""
  for module in $(framework.helpers.json::keys "$(cat -- "$SETTINGS_DEFAULTS")" .featureFlags); do
    dot::feature "$module" || PATHS_DISABLED="$PATHS_DISABLED$module"$'\n'
  done
  PATHS_FLAGS_READ=true
}

paths::disabled_modules() {
  paths::read_flags
  printf '%s' "$PATHS_DISABLED"
}

# Whether <module> is on: anything but a module a feature flag turns off.
paths::module_on() {
  paths::read_flags
  [[ $'\n'"$PATHS_DISABLED" != *$'\n'"$1"$'\n'* ]]
}

# dotdot's modules, but those a feature flag turns off; with --all, every one.
paths::core_modules() {
  local part disabled=" "
  [ "${1-}" = --all ] || disabled=" $(paths::disabled_modules | tr '\n' ' ')"
  for part in "${CORE_MODULES[@]}"; do
    [[ "$disabled" == *" $part "* ]] || printf '%s\n' "$part"
  done
}

# Every part of the system and every module on (with --all, every module):
# the directories commands and skills are found in, system first.
paths::modules() {
  local part
  for part in "${SYSTEM_PARTS[@]}"; do
    printf '%s\n' "$SYSTEM_DIR/$part"
  done
  while IFS= read -r part; do
    printf '%s\n' "$MODULES_DIR/$part"
  done < <(paths::core_modules "$@")
}

# Every installed plugin's directory, in the order they were added (the lock's
# order), so the first one added keeps whatever a later one would clash with.
paths::plugins() {
  local directory plugin
  dot::use framework.helpers.json
  {
    [ ! -f "$PLUGINS_LOCK" ] || framework.helpers.json::values "$(cat -- "$PLUGINS_LOCK")" '.plugins[].id' | while IFS= read -r plugin; do
      ! guards::plugin_id "$plugin" || printf '%s\n' "$plugin"
    done
    for directory in "$PLUGINS_DIR"/*/*/; do
      [ -d "$directory" ] || continue
      directory="${directory%/}"
      printf '%s\n' "${directory#"$PLUGINS_DIR"/}"
    done
  } | awk '!seen[$0]++' | while IFS= read -r plugin; do
    [ ! -d "$PLUGINS_DIR/$plugin" ] || printf '%s\n' "$PLUGINS_DIR/$plugin"
  done
}

# The links map (the project settings' links, or dotdot's default while they
# have none) as rows "<group>\t<kind>\t<origin>\t<destination>", one per
# destination: <group> is "." for the general ones (each "<origin>":
# [destinations] at the top, and the "append" and "remove" sections), +<owner>/<name>
# for an active plugin's group (the same shape, under "<owner>/<name>"), and
# <owner>/<name> for its inactive ones (under "inactive"), never applied; a
# leaf outside that structure is a row with "!" as its group. Fails when the settings file or its
# links is not a JSON object.
paths::links_rows() {
  local document="{}" links
  dot::use framework.helpers.json
  [ ! -f "$SETTINGS_FILE" ] || document=$(cat -- "$SETTINGS_FILE")
  case "$(framework.helpers.json::encoded "$document" .)" in
    "{"*) ;;
    *) return 1 ;;
  esac
  links=$(framework.helpers.json::encoded "$document" .links)
  [ "$links" != null ] || links=$(framework.helpers.json::encoded "$(cat -- "$SETTINGS_DEFAULTS")" .links)
  case "$links" in
    "{"*) document="$links" ;;
    *) return 1 ;;
  esac
  framework.helpers.json::leaves "$document" | awk -F '\t' -v OFS='\t' '
    function id(text) { return text ~ /^[a-z0-9][a-z0-9-]*\/[a-z0-9][a-z0-9-]*$/ }
    function section(text) { return text == "append" || text == "remove" }
    NF == 3 && !section($1) && $1 != "inactive" && !id($1) && $2 ~ /^[0-9]+$/ && $3 != "" { print ".", "link", $1, $3; next }
    NF == 4 && section($1) && $3 ~ /^[0-9]+$/ && $4 != "" { print ".", $1, $2, $4; next }
    NF == 4 && id($1) && !section($2) && $3 ~ /^[0-9]+$/ && $4 != "" { print "+" $1, "link", $2, $4; next }
    NF == 5 && id($1) && section($2) && $4 ~ /^[0-9]+$/ && $5 != "" { print "+" $1, $2, $3, $5; next }
    NF == 5 && $1 == "inactive" && id($2) && !section($3) && $4 ~ /^[0-9]+$/ && $5 != "" { print $2, "link", $3, $5; next }
    NF == 6 && $1 == "inactive" && id($2) && section($3) && $5 ~ /^[0-9]+$/ && $6 != "" { print $2, $3, $4, $6; next }
    { print "!", $0 }
  '
}
