# shellcheck shell=bash

HEY_LOADED_MODULES=" "
HEY_PACKAGES=" framework core plugins "
HEY_PRIVATE_SEGMENT="internal"
HEY_MODULE_PATTERN='^[a-z][a-z0-9-]*(\.[a-z0-9][a-z0-9-]*)+$'
HEY_COMMAND_PATTERN='^[a-z0-9][a-z0-9-]*(:[a-z][a-z0-9-]*){0,2}$'
HEY_COMMAND_MAX_DEPTH=2
# dotHey's own commands may go one level deeper (release:token:delete): a
# plugin's take their owner as the first part.
HEY_CORE_COMMAND_MAX_DEPTH=3
HEY_RESERVED_COMMANDS=(help list version)
# Where each core command's help points for more: its DOCS page in HEY_DOCS_URL,
# as <section>/<page>[#<anchor>].
HEY_DOCS_URL="https://github.com/dotHeydev/dotHey/blob/%s/docs/%s"
HEY_DOCS_DEFAULT="getting-started/cli"
# Was --json given (before --)? Set by the kernel; errors then print as JSON.
HEY_JSON=false
# Exit statuses, part of every command's contract: 0 is success, an empty
# result included; 130, 143 and 129 are an interrupt, a TERM and a hangup.
EXIT_FAILURE=1
EXIT_USAGE=2
EXIT_NOT_FOUND=4
EXIT_PRECONDITION=5
HEY_EXIT_TASKS=()
HEY_PLUGIN=""
HEY_COMMAND=""
HEY_MODULE_FILE=""
HEY_MODULE_HOME=""

SYSTEM_DIR=$(CDPATH='' cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
CORE_DIR=$(dirname -- "$SYSTEM_DIR")
FRAMEWORK_DIR="$CORE_DIR/framework"
# The fallback for temporary files (see FS_TEMP_FALLBACK below): .tmp/ in
# .core/ for most runs, in dotHey's own folder for an upgrade (which replaces
# .core/), and .dothey_tmp/ at the project's root for a run that moves dotHey.
HEY_TEMP_DIR=".tmp"
HEY_PROJECT_TEMP_DIR=".dothey_tmp"
MODULES_DIR="$CORE_DIR/modules"
DOTHEY_ROOT=$(dirname -- "$CORE_DIR")
# The project is the nearest directory above dotHey whose hey entry runs this
# dotHey (it may sit deeper, as .agents/.hey), else dotHey's parent; dotHey's
# name is its path from there.
BASE=$(CDPATH='' cd -P -- "$DOTHEY_ROOT/.." && pwd)
while [ "$BASE" != / ] && ! [ "$BASE/hey" -ef "$SYSTEM_DIR/bin/hey" ]; do
  BASE=$(dirname -- "$BASE")
done
[ "$BASE/hey" -ef "$SYSTEM_DIR/bin/hey" ] || BASE=$(CDPATH='' cd -P -- "$DOTHEY_ROOT/.." && pwd)
DOTHEY_NAME="${DOTHEY_ROOT#"$BASE"/}"

. "$SYSTEM_DIR/paths.sh"
. "$SYSTEM_DIR/guards.sh"

# Set when dotHey itself made this call (hey::call, the installer), read once
# and never passed on: it alone lets -y skip a confirmation off a terminal.
HEY_INTERNAL=false
[ "${HEY_INTERNAL_CALL-}" != 1 ] || HEY_INTERNAL=true
unset HEY_INTERNAL_CALL

# The file a module name loads, into HEY_MODULE_FILE.
hey::module_file() {
  local name="$1" path
  [[ "$name" =~ $HEY_MODULE_PATTERN ]] || return 1
  path="${name#*.}"
  path="${path//./\/}.sh"
  case "${name%%.*}" in
    framework) HEY_MODULE_FILE="$FRAMEWORK_DIR/$path" ;;
    core) HEY_MODULE_FILE="$CORE_DIR/$path" ;;
    plugins) HEY_MODULE_FILE="$PLUGINS_DIR/$path" ;;
    *) return 1 ;;
  esac
}

hey::plugin_of() {
  local file="$1" relative owner
  case "$file" in
    "$PLUGINS_DIR"/*/*/*)
      relative="${file#"$PLUGINS_DIR"/}"
      owner="${relative%%/*}"
      relative="${relative#*/}"
      printf '%s/%s\n' "$owner" "${relative%%/*}"
      ;;
  esac
}

# The directory a module's own code lives in, the only place that may load
# it, into HEY_MODULE_HOME: core.system.<part> and core.modules.<module>,
# plugins.<owner>.<name>, or, for a framework module with an internal/ part,
# the directory holding internal/; empty when anyone may load it. The
# harnesses (core.harnesses.*) are the core's to use, from anywhere in it.
hey::module_home() {
  local name="$1" path
  HEY_MODULE_HOME=""
  case "$name" in
    framework.*".$HEY_PRIVATE_SEGMENT."*)
      path="${name#framework.}"
      path="${path%%".$HEY_PRIVATE_SEGMENT."*}"
      HEY_MODULE_HOME="$FRAMEWORK_DIR/${path//./\/}"
      ;;
    core.harnesses.*) HEY_MODULE_HOME="$CORE_DIR" ;;
    core.* | plugins.*)
      path="${name#*.}"
      name="${path#*.}"
      case "$1" in
        core.*) HEY_MODULE_HOME="$CORE_DIR/${path%%.*}/${name%%.*}" ;;
        *) HEY_MODULE_HOME="$PLUGINS_DIR/${path%%.*}/${name%%.*}" ;;
      esac
      ;;
  esac
}

hey::is_allowed() {
  local name="$1" importer="$2" home
  case "$HEY_PACKAGES" in
    *" ${name%%.*} "*) ;;
    *) return 1 ;;
  esac
  [ -n "$importer" ] || return 0
  hey::module_home "$name"
  home="$HEY_MODULE_HOME"
  [ -z "$home" ] || [ "${importer#"$home"/}" != "$importer" ]
}

# A stop from before the output tool can load: the theme's error icon, bold
# and red on a terminal, as the output tool's.
hey::fail_early() {
  local icon
  [ -n "${UI_ICON_ERROR-}" ] || . "$FRAMEWORK_DIR/ui/theme.sh" 2>/dev/null || true
  icon="${UI_ICON_ERROR-}"
  [ ! -t 2 ] || [ -n "${NO_COLOR-}" ] || [ "${TERM-}" = dumb ] || icon=$'\033[1;31m'"$icon"$'\033[0m'
  printf '%s %s\n' "$icon" "$1" >&2
  exit 1
}

hey::use() {
  local importer name file
  hey::physical_to importer "${BASH_SOURCE[1]-}"
  for name in "$@"; do
    if ! hey::module_file "$name" || [ ! -f "$HEY_MODULE_FILE" ]; then
      hey::fail_early "Unknown dotHey module: $name (framework.*, core.system.*, core.modules.*)."
    fi
    if ! hey::is_allowed "$name" "$importer"; then
      hey::fail_early "$(hey::relative "${importer:-this script}") may not use $name: a system part or module only uses the framework and its own code; reach another one with hey::call."
    fi
    case "$HEY_LOADED_MODULES" in
      *" $name "*) continue ;;
    esac
    HEY_LOADED_MODULES="$HEY_LOADED_MODULES$name "
    file="$HEY_MODULE_FILE"
    . "$file"
    # dotHey's own modules are sealed as they load; a plugin's stay its own.
    case "$name" in
      core.* | framework.*) hey::seal_functions "$name::" ;;
    esac
  done
}

hey::relative() {
  case "$1" in
    "$BASE"/*) printf '%s\n' "${1#"$BASE"/}" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

hey::path() {
  case "$1" in
    project) printf '%s\n' "$BASE" ;;
    dothey) printf '%s\n' "$DOTHEY_ROOT" ;;
    plugin)
      [ -n "$HEY_PLUGIN" ] || return 1
      printf '%s\n' "$PLUGINS_DIR/$HEY_PLUGIN"
      ;;
    *) return 1 ;;
  esac
}

# A file's path with its directory's links resolved, into the variable named
# $1; dotHey's own files, already loaded by their real path, are taken as
# they are.
hey::physical_to() {
  local hey_physical_path="$2"
  if [ -n "$hey_physical_path" ]; then
    case "$hey_physical_path" in
      *"/./"* | *"/../"*) hey_physical_path="$(CDPATH='' cd -P -- "$(dirname -- "$hey_physical_path")" 2>/dev/null && pwd)/${hey_physical_path##*/}" ;;
      "$CORE_DIR"/* | "$PLUGINS_DIR"/*) ;;
      *) hey_physical_path="$(CDPATH='' cd -P -- "$(dirname -- "$hey_physical_path")" 2>/dev/null && pwd)/${hey_physical_path##*/}" ;;
    esac
  fi
  printf -v "$1" '%s' "$hey_physical_path"
}

# Each installed plugin as "<name> <key>": its GitHub name, and the key its
# folder gives it, <owner>/<directory> (the name's own when the lock records
# no directory).
hey::plugin_keys() {
  local entry name directory
  [ -f "$PLUGINS_LOCK" ] || return 0
  hey::use framework.helpers.json
  while IFS= read -r entry; do
    name=$(framework.helpers.json::field "$entry" .id)
    directory=$(framework.helpers.json::field "$entry" .directory)
    printf '%s %s/%s\n' "$name" "${name%%/*}" "${directory:-${name#*/}}"
  done < <(framework.helpers.json::values "$(cat -- "$PLUGINS_LOCK")" '.plugins[]')
}

# The key of the plugin named <name>; <name> itself when none is installed.
hey::plugin_key() {
  local name key
  while read -r name key; do
    [ "$name" != "$1" ] || { printf '%s\n' "$key"; return; }
  done < <(hey::plugin_keys)
  printf '%s\n' "$1"
}

# The name of the plugin whose key is <key>; <key> itself when none is.
hey::plugin_name() {
  local name key
  while read -r name key; do
    [ "$key" != "$1" ] || { printf '%s\n' "$name"; return; }
  done < <(hey::plugin_keys)
  printf '%s\n' "$1"
}

# The .env prefix of a plugin's secrets, from its key: HEY_ACME_WIDGETS__ for
# acme/widgets.
hey::env_prefix() {
  printf 'HEY_%s_%s__' "${1%%/*}" "${1#*/}" | tr 'a-z-' 'A-Z_'
}

# The plugin whose code <file> is, <owner>/<name>, or nothing for dotHey's.
hey::plugin_of_caller() {
  local caller="$1"
  hey::physical_to caller "$caller"
  hey::plugin_of "$caller"
}

# Where a settings path lies in hey.json: a plugin's under
# plugins.<owner>/<name>.
hey::settings_json_path() {
  printf '%s.%s\n' "${2:+.plugins[\"$2\"]}" "$1"
}

# The value at <JSON path> in <file> as JSON: status 1 when the file is
# missing or the value null, 2 (said why) when the file is not valid JSON or
# the path does not fit it.
hey::json_value() {
  local file="$1" path="$2" value
  [ -f "$file" ] || return 1
  value=$(framework.helpers.json::encoded "$(cat -- "$file")" "$path")
  case "$value" in
    "") hey::raise "$(hey::relative "$file") isn't valid JSON, or ${path#.} has the wrong shape." "Please fix the file and run the command again."; return 2 ;;
    null) return 1 ;;
  esac
  printf '%s\n' "$value"
}

# A setting's default from dotHey's defaults as JSON; plugin settings have
# none here, theirs are written into hey.json on install. Defaults never
# refer to .env. Status 1 when there is none, 2 on an invalid file or a
# reference.
hey::default_value() {
  local path="$1" plugin="$2" value
  [ -z "$plugin" ] || return 1
  value=$(hey::json_value "$SETTINGS_DEFAULTS" ".$path") || return
  [[ "$value" != *'"@env:'* ]] \
    || { hey::raise "$path in $(hey::relative "$SETTINGS_DEFAULTS") reads from .env; only $(hey::relative "$SETTINGS_FILE") may."; return 2; }
  printf '%s\n' "$value"
}

# The string <key> stands for in the host project's .env, as env() reads it in
# any dotenv library: status 1 when .env has no <key> (a commented-out line
# counts as none), 2 when <key> is not a valid .env key or one dotHey reserves
# for a secret.
hey::env_value() {
  local key="$1" label="$2"
  guards::env_key "$key" || { hey::raise "\"$key\" isn't a valid .env key (in $label)." "Please use letters, digits and _, starting with a letter."; return 2; }
  ! guards::reserved_env_key "$key" \
    || { hey::raise "$key is reserved by dotHey; please pick another .env key for $label."; return 2; }
  framework.helpers.kv::value "$HOST_ENV_FILE" "$key" 2>/dev/null
}

# <key>'s value from .env as JSON, cast by its syntax alone: true, false,
# and numbers as written, valid JSON in [ ] or { } as that list or object,
# anything else, or anything written in quotes, as text. Status 1 for null,
# which counts as unset.
hey::cast_setting() {
  local text="$1" key="$2" json
  if framework.helpers.kv::is_quoted "$HOST_ENV_FILE" "$key"; then
    framework.helpers.json::string "$text"
    return
  fi
  case "$text" in
    null) return 1 ;;
    true | false) printf '%s\n' "$text"; return ;;
    "["* | "{"*)
      json=$(framework.helpers.json::encoded "$text" .)
      case "$json" in
        "["* | "{"*) printf '%s\n' "$json"; return ;;
      esac
      ;;
  esac
  if [[ "$text" =~ ^-?(0|[1-9][0-9]*)(\.[0-9]+)?$ ]]; then
    printf '%s\n' "$text"
  else
    framework.helpers.json::string "$text"
  fi
}

# The JSON path of a leaf row's steps (json::leaves, tab-separated): a key
# as ["key"], an index as [N] where its parent in <json> is a list.
hey::leaf_path() {
  local json="$1" steps="$2" step path=""
  while IFS= read -r step; do
    if [[ "$step" =~ ^[0-9]+$ ]] && [ "$(framework.helpers.json::encoded "$json" "${path:-.}" | cut -c1)" = "[" ]; then
      path="${path}[$step]"
    else
      path="${path}[$(framework.helpers.json::string "$step")]"
    fi
  done < <(printf '%s\n' "$steps" | tr '\t' '\n')
  printf '%s\n' "$path"
}

# <json>, the value of a setting in hey.json, with every "@env:<key>" string
# in it, the whole value or any value or element inside, replaced by what
# <key> stands for in .env (hey::env_value), cast by its syntax
# (hey::cast_setting). A missing key, or null, leaves the whole value unset
# (status 1, so the default applies) and anything inside it null. The
# settings only JSON holds take no reference at all.
hey::resolve_setting() {
  local json="$1" path="$2" plugin="$3" label="$4" row steps text key leaf value status
  [[ "$json" == *'"@env:'* ]] || { printf '%s\n' "$json"; return 0; }
  [ -n "$plugin" ] || guards::env_setting "$path" \
    || { hey::raise "$label can't come from .env." "Please set it in $(hey::relative "$SETTINGS_FILE") instead."; return 2; }
  case "$json" in
    \"@env:*)
      key=$(framework.helpers.json::values "$json" .) && key="${key#@env:}"
      text=$(hey::env_value "$key" "$label") || return
      hey::cast_setting "$text" "$key"
      return
      ;;
  esac
  while IFS= read -r row; do
    text="${row##*$'\t'}"
    [ "${text#@env:}" != "$text" ] || continue
    key="${text#@env:}"
    steps="${row%$'\t'*}"
    leaf=$(hey::leaf_path "$json" "$steps")
    status=0
    text=$(hey::env_value "$key" "$label$leaf") || status=$?
    [ "$status" -ne 2 ] || return 2
    value=null
    [ "$status" -ne 0 ] || value=$(hey::cast_setting "$text" "$key") || value=null
    json=$(framework.helpers.json::set "$json" ".$leaf" "$value") || return 2
  done < <(framework.helpers.json::leaves "$json")
  printf '%s\n' "$json"
}

# A setting's value from hey.json, its .env references resolved
# (hey::resolve_setting), else from dotHey's defaults; with <plugin> one of
# that plugin's, under plugins.<owner>/<name> in hey.json only. Strings print
# raw, anything else as JSON. Status 1 when unset, 2 on an invalid path, file,
# or reference. Run in a subshell, so callers load the JSON and kv helpers
# first.
hey::read_setting() {
  local path="$1" plugin="$2" json_path value status=0
  guards::setting "$path" || { hey::raise "\"$path\" isn't a valid setting path."; return 2; }
  json_path=$(hey::settings_json_path "$path" "$plugin")
  value=$(hey::json_value "$SETTINGS_FILE" "$json_path") \
    && value=$(hey::resolve_setting "$value" "$path" "$plugin" "${json_path#.}") || status=$?
  [ "$status" -ne 2 ] || return 2
  [ "$status" -eq 0 ] || value=$(hey::default_value "$path" "$plugin") || return
  case "$value" in
    \"*) framework.helpers.json::values "$value" . ;;
    *) printf '%s\n' "$value" ;;
  esac
}

# One setting, read as env() does in any dotenv library: text prints raw,
# anything else (true, false, a number, a list, an object) as JSON. Unset or
# empty, it prints <default> when one is given, else stops with how to set
# it; status 1 too on an invalid path, file, or reference.
hey::get_setting() {
  local path="$1" plugin="$2" value status=0
  hey::use framework.helpers.json framework.helpers.kv
  value=$(hey::read_setting "$path" "$plugin") || status=$?
  [ "$status" -ne 2 ] || return 1
  if [ "$status" -eq 0 ] && [ -n "$value" ]; then
    printf '%s\n' "$value"
  elif [ $# -gt 2 ]; then
    printf '%s\n' "$3"
  else
    hey::raise "The setting $(hey::settings_json_path "$path" "$plugin" | cut -c2-) isn't set yet." "Please add it to $(hey::relative "$SETTINGS_FILE"), or set it to \"@env:<KEY>\" to read it from .env."
  fi
}

# The name of the plugin whose code called (<file>), or a stop: plugin settings are for
# plugin code only.
hey::calling_plugin() {
  local plugin
  plugin=$(hey::plugin_of_caller "$1")
  [ -n "$plugin" ] || { hey::raise "hey::plugin_setting and hey::save_plugin_setting only work from a plugin's own code."; return 1; }
  hey::plugin_name "$plugin"
}

# Whether <path> is in dotHey's own state rather than the user's settings,
# refused (said why) when so.
hey::is_state_path() {
  case "$1" in
    state | state.*) hey::raise "$1 is dotHey's own state, not a setting." "Please read it with hey::state, and write it with hey::save_state."; return 0 ;;
  esac
  return 1
}

# hey::setting <path> [default]: one of dotHey's settings (see
# hey::get_setting), for any code, a plugin's included.
hey::setting() {
  ! hey::is_state_path "$1" || return 1
  hey::get_setting "$1" "" "${@:2}"
}

# hey::state <path> [default]: one of the values dotHey keeps for itself under
# "state" in hey.json (the release and commit installed, the migrations
# applied, setup's record), as only dotHey writes them: no defaults, and a value pointing at
# .env is refused. Text prints raw, anything else as JSON; unset, <default>
# when given.
hey::state() {
  local path="$1" value status=0
  guards::setting "$path" || { hey::raise "\"$path\" isn't a valid state path."; return 1; }
  hey::use framework.helpers.json
  value=$(hey::json_value "$SETTINGS_FILE" ".state.$path") || status=$?
  [ "$status" -ne 2 ] || return 1
  [[ "$value" != *'"@env:'* ]] || { hey::raise "state.$path in $(hey::relative "$SETTINGS_FILE") reads from .env; dotHey's state never does." "Please remove it; dotHey records it again."; return 1; }
  if [ "$status" -eq 0 ]; then
    case "$value" in
      \"*) framework.helpers.json::values "$value" . ;;
      *) printf '%s\n' "$value" ;;
    esac
  elif [ $# -gt 1 ]; then
    printf '%s\n' "$2"
  else
    hey::raise "dotHey hasn't recorded state.$path yet."
    return 1
  fi
}

# hey::version: the release installed (state.version, N.N.N), for display
# only; nothing when unknown.
hey::version() {
  local version
  version=$(hey::state version "" 2>/dev/null) || version=""
  [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]] && printf '%s\n' "$version"
  return 0
}

# hey::feature <name>: whether the feature flag featureFlags.<name> is on, for
# conditionals; off unless set to true, and off when it can't be read.
hey::feature() {
  [ "$(hey::setting "featureFlags.$1" false 2>/dev/null)" = true ]
}

# hey::plugin_setting <key> [default]: one of the calling plugin's own
# settings, from plugins.<owner>/<name> in hey.json, where installing the
# plugin wrote its defaults.
hey::plugin_setting() {
  local plugin
  plugin=$(hey::calling_plugin "${BASH_SOURCE[1]-}") || return 1
  hey::get_setting "$1" "$plugin" "${@:2}"
}

# Saves <json> at a settings JSON path in hey.json, in place of the old
# value, the rest of the file left as written.
hey::write_setting() {
  local path="$1" json_path="$2" value="$3" document="{}" saved
  guards::setting "$path" || { hey::raise "\"$path\" isn't a valid setting path."; return 1; }
  [[ "$value" != *'"@env:'* ]] || { hey::raise "hey::save_setting can't write \"@env:\" values ($path); they're written in $(hey::relative "$SETTINGS_FILE") by hand only."; return 1; }
  hey::use framework.helpers.json framework.helpers.fs
  [ ! -f "$SETTINGS_FILE" ] || document=$(cat -- "$SETTINGS_FILE")
  saved=$(framework.helpers.json::set "$document" "$json_path" "$value" --keep-format) \
    && printf '%s\n' "$saved" | framework.helpers.fs::write "$SETTINGS_FILE" \
    || hey::raise "Couldn't save $path to $(hey::relative "$SETTINGS_FILE"); please check that it's writable."
}

# Saves one of dotHey's settings; dotHey's own code only, as plugins read
# them but never write them.
hey::save_setting() {
  [ -z "$(hey::plugin_of_caller "${BASH_SOURCE[1]-}")" ] \
    || { hey::raise "A plugin only saves its own settings, with hey::save_plugin_setting."; return 1; }
  ! hey::is_state_path "$1" || return 1
  hey::write_setting "$1" ".$1" "$2"
}

# Saves one of dotHey's own state values; dotHey's own code only.
hey::save_state() {
  [ -z "$(hey::plugin_of_caller "${BASH_SOURCE[1]-}")" ] \
    || { hey::raise "dotHey's state is dotHey's to write; a plugin keeps its own settings, with hey::save_plugin_setting."; return 1; }
  hey::write_setting "state.$1" ".state.$1" "$2"
}

# Saves one of the calling plugin's own settings.
hey::save_plugin_setting() {
  local plugin
  plugin=$(hey::calling_plugin "${BASH_SOURCE[1]-}") || return 1
  hey::write_setting "$1" "$(hey::settings_json_path "$1" "$plugin")" "$2"
}

# A secret is one of the .env keys dotHey reserves (guards::reserved_env_key);
# one a plugin reads or writes carries that plugin's prefix.
hey::check_secret() {
  local key="$1" plugin
  guards::secret "$key" || { hey::raise "\"$key\" isn't a valid secret name."; return 1; }
  plugin=$(hey::plugin_of_caller "$2")
  [ -z "$plugin" ] || guards::plugin_secret "$plugin" "$key" \
    || { hey::raise "$plugin's secrets must start with $(hey::env_prefix "$plugin") (got $key)."; return 1; }
}

# A secret's value, from the host project's .env alone: never from settings,
# so a missing one is never filled in from elsewhere. Status 1 when unset or
# empty.
hey::secret() {
  local value
  hey::check_secret "$1" "${BASH_SOURCE[1]-}" || return 2
  hey::use framework.helpers.kv
  value=$(framework.helpers.kv::value "$HOST_ENV_FILE" "$1" 2>/dev/null) && [ -n "$value" ] || return 1
  printf '%s\n' "$value"
}

# Saves a secret in the host project's .env, only while git ignores it; a
# .env it creates is readable by the user alone.
hey::save_secret() {
  local created=false
  hey::check_secret "$1" "${BASH_SOURCE[1]-}" || return 1
  guards::secrets_file || { hey::raise "$(hey::relative "$HOST_ENV_FILE") isn't git-ignored, so no secret was saved." "Please add it to .gitignore, then try again."; return 1; }
  hey::use framework.helpers.kv
  [ -e "$HOST_ENV_FILE" ] || created=true
  (umask 077 && framework.helpers.kv::write "$HOST_ENV_FILE" "$1" "$2") && { ! $created || chmod 600 "$HOST_ENV_FILE"; } \
    || hey::raise "Couldn't save $1 to $(hey::relative "$HOST_ENV_FILE"); please check that it's writable."
}

hey::remove_secret() {
  hey::check_secret "$1" "${BASH_SOURCE[1]-}" || return 1
  hey::use framework.helpers.kv
  framework.helpers.kv::remove "$HOST_ENV_FILE" "$1"
}

# Runs another dotHey command; one called from dotHey's own code (not a
# plugin's) counts as dotHey's call for guards::skip_confirmation.
hey::call() {
  local internal=""
  [ -n "$HEY_PLUGIN" ] || internal=1
  HEY_INTERNAL_CALL="$internal" bash "$HEY_BIN" "$@"
}

# hey::on_exit <command> [<argument>...]: runs it when the command ends. Each
# word is kept shell-quoted (printf %q), so whatever an argument holds (a
# path, text from a file or a person) stays one word and never runs as code.
hey::on_exit() {
  [ $# -gt 0 ] || return 0
  HEY_EXIT_TASKS+=("$(printf '%q ' "$@")")
}

# <message>, then each further argument as a next step under it (as is when
# it starts with a space, a detail).
hey::raise() {
  local step
  printf '%s\n' "$1" >> "$HEY_ERROR_FILE"
  shift
  for step in "$@"; do
    case "$step" in
      " "*) printf '%s\n' "$step" ;;
      *) printf '→ %s\n' "$step" ;;
    esac >> "$HEY_ERROR_FILE"
  done
  return 1
}

hey::abort() {
  hey::raise "$@" || exit 1
}

# hey::abort, exiting <status> (one of EXIT_*: 4 not found, 5 precondition).
hey::abort_as() {
  local status="$1"
  shift
  hey::raise "$@" || exit "$status"
}

# The errors raised, each with its next steps; under --json, each as one JSON
# error for exit <status>.
hey::report_errors() {
  local message status="${1:-1}" steps=() error=""
  [ -s "$HEY_ERROR_FILE" ] || return 0
  hey::use framework.console.output
  if $HEY_JSON; then
    while IFS= read -r message; do
      case "$message" in
        "→ "*) steps+=("${message#→ }") ;;
        " "*) steps+=("${message# }") ;;
        *)
          [ -z "$error" ] || framework.console.output::json_error "$status" "$error" ${steps[@]+"${steps[@]}"}
          error="$message"
          steps=()
          ;;
      esac
    done < "$HEY_ERROR_FILE"
    [ -z "$error" ] || framework.console.output::json_error "$status" "$error" ${steps[@]+"${steps[@]}"}
    return 0
  fi
  while IFS= read -r message; do
    case "$message" in
      "→ "*) framework.console.output::next "${message#→ }" >&2 ;;
      " "*) framework.console.output::emit 2 "$message" ;;
      *) framework.console.output::error "$message" ;;
    esac
  done < "$HEY_ERROR_FILE"
}

# Shows the errors raised so far, as the end of the command would, and
# clears them: for a command that goes on after one step failed.
hey::flush_errors() {
  hey::report_errors "${1:-1}"
  : > "$HEY_ERROR_FILE"
}

hey::finish() {
  local status=$? task
  [ "$status" -eq 0 ] || hey::report_errors "$status"
  rm -f -- "$HEY_ERROR_FILE"
  for task in ${HEY_EXIT_TASKS[@]+"${HEY_EXIT_TASKS[@]}"}; do
    # Safe: hey::on_exit quoted every word, so this only splits them back.
    eval "$task" || true
  done
  return "$status"
}

# Applies the project's timezone (general.timezone) to the dates dotHey
# prints; run as the date helper loads, so only commands that date pay for it.
hey::use_timezone() {
  local zone
  zone=$(hey::setting general.timezone "") && [ -n "$zone" ] || return 0
  framework.helpers.date::use_timezone "$zone" && return 0
  hey::use framework.console.output
  framework.console.output::warn "Unknown timezone \"$zone\" in $(hey::relative "$SETTINGS_FILE") settings (general.timezone); using the system's."
}

trap 'hey::finish' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

# Makes every function named <prefix>… read-only, for each prefix given;
# without compgen (a bash built without it) the full list is scanned instead.
hey::seal_functions() {
  local name prefix names
  for prefix in "$@"; do
    names=$(compgen -A function -- "$prefix" 2>/dev/null) \
      || names=$(declare -F | while read -r _ _ name; do case "$name" in "$prefix"*) printf '%s\n' "$name" ;; esac; done)
    for name in $names; do
      readonly -f "$name"
    done
  done
}

# Seals the runtime: dotHey's own functions and the variables that say where
# things are and what is allowed become read-only, so code loaded later (a
# plugin's included) can't redefine a guard or point dotHey elsewhere.
hey::seal() {
  hey::seal_functions hey:: paths:: guards:: kernel::
  readonly BASE DOTHEY_ROOT DOTHEY_NAME CORE_DIR SYSTEM_DIR FRAMEWORK_DIR MODULES_DIR BIN_DIR HEY_BIN \
    PLUGINS_DIR PLUGINS_LOCK SETTINGS_FILE SETTINGS_DEFAULTS HOST_ENV_FILE LINK_MAP_SEPARATOR USER_FILE USER_EXAMPLE_FILE ENTRY_LINK \
    EXIT_FAILURE EXIT_USAGE EXIT_NOT_FOUND EXIT_PRECONDITION HEY_PACKAGES HEY_PRIVATE_SEGMENT HEY_MODULE_PATTERN HEY_COMMAND_PATTERN HEY_COMMAND_MAX_DEPTH HEY_CORE_COMMAND_MAX_DEPTH HEY_INTERNAL \
    GUARDS_DOCUMENT_PATTERN GUARDS_SEGMENT_PATTERN GUARDS_OWNER_PATTERN GUARDS_REPOSITORY_PATTERN GUARDS_SETTING_PATTERN GUARDS_RESERVED_ENV_PATTERN GUARDS_ENV_KEY_PATTERN GUARDS_JSON_ONLY_SETTINGS \
    GUARDS_DOTHEY
  readonly -a SYSTEM_PARTS CORE_MODULES HEY_RESERVED_COMMANDS
}

# Temporary files fall back to .core/.tmp/ (git-ignored) when the system's
# temporary folder can't take them; a run that moves dotHey points it
# elsewhere.
FS_TEMP_FALLBACK="$CORE_DIR/$HEY_TEMP_DIR"
hey::use framework.helpers.fs
# The error log lives through every run, those that move dotHey included.
framework.helpers.fs::make_temp_file HEY_ERROR_FILE "$BASE/$HEY_PROJECT_TEMP_DIR" || hey::fail_early "Couldn't create a temporary file; please check free space and \$TMPDIR."
. "$SYSTEM_DIR/kernel.sh"
hey::seal
