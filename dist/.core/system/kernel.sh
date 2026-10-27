#!/usr/bin/env bash

dot::use framework.console.output

KERNEL_COLUMN_WIDTH=18
KERNEL_FILE=""
KERNEL_UNPREFIXED_SETTING="plugins.unprefixedCommandOwners"
KERNEL_UNPREFIXED=""
KERNEL_UNPREFIXED_READ=false

# Each command in <directory> as "<prefix><name>|<file>|<fallback><name>":
# the fallback is the name it takes when the first one is already taken.
kernel::commands_in() {
  local directory="$1" prefix="$2" fallback="${3-}" file name
  [ -d "$directory" ] || return 0
  while IFS= read -r file; do
    name="${file#"$directory"/}"
    name="${name%.sh}"
    name="${name//\//:}"
    [[ "$prefix$name" =~ $DOT_COMMAND_PATTERN ]] || continue
    printf '%s|%s|%s\n' "$prefix$name" "$file" "${fallback:+$fallback$name}"
  done < <(find "$directory" -mindepth 1 -maxdepth "$DOT_COMMAND_MAX_DEPTH" -type f -name '*.sh' | sort)
}

# dotdot's own commands, found with a single find over every module.
kernel::core_commands() {
  local module directories=() file name
  while IFS= read -r module; do
    [ ! -d "$module/$MODULE_COMMANDS_DIR" ] || directories+=("$module/$MODULE_COMMANDS_DIR")
  done < <(paths::modules)
  while IFS= read -r file; do
    name="${file#"$CORE_DIR"/*/*/"$MODULE_COMMANDS_DIR"/}"
    name="${name%.sh}"
    name="${name//\//:}"
    [[ "$name" =~ $DOT_COMMAND_PATTERN ]] && printf '%s|%s\n' "$name" "$file"
  done < <(find "${directories[@]}" -mindepth 1 -maxdepth "$DOT_COMMAND_MAX_DEPTH" -type f -name '*.sh' | sort)
}

# The plugin owners the plugins.unprefixedCommandOwners setting lists, into
# KERNEL_UNPREFIXED as " a b ", read once.
kernel::load_unprefixed() {
  local owner owners
  ! $KERNEL_UNPREFIXED_READ || return 0
  KERNEL_UNPREFIXED_READ=true
  KERNEL_UNPREFIXED=" "
  dot::use framework.helpers.json
  owners=$(dot::setting "$KERNEL_UNPREFIXED_SETTING" "[]" 2>/dev/null) || owners="[]"
  for owner in $(framework.helpers.json::values "$owners" '.[]'); do
    [[ "$owner" =~ ^[a-z0-9][a-z0-9-]*$ ]] && KERNEL_UNPREFIXED="$KERNEL_UNPREFIXED$owner "
  done
  return 0
}

kernel::is_unprefixed() {
  kernel::load_unprefixed
  [[ "$KERNEL_UNPREFIXED" == *" $1 "* ]]
}

# Every command as "<name>|<file>": dotdot's own first, then each plugin's
# under its owner (or none); a name already taken keeps its first owner, and
# an unprefixed command whose name is taken (by dotdot or an earlier plugin)
# keeps its "<owner>:" prefix.
kernel::commands() {
  local plugin owner
  kernel::load_unprefixed
  {
    kernel::core_commands
    while IFS= read -r plugin; do
      owner=$(basename -- "$(dirname -- "$plugin")")
      if kernel::is_unprefixed "$owner"; then
        kernel::commands_in "$plugin/$MODULE_COMMANDS_DIR" "" "$owner:"
      else
        kernel::commands_in "$plugin/$MODULE_COMMANDS_DIR" "$owner:"
      fi
    done < <(paths::plugins)
  } | awk -F'|' '
    !seen[$1]++ { print $1 "|" $2; next }
    $3 != "" && !seen[$3]++ { print $3 "|" $2 }
  '
}

# The first parts of dotdot's own command names, and the names bash dot
# itself answers to: no plugin owner may take one.
kernel::reserved_names() {
  kernel::core_commands | cut -d'|' -f1 | cut -d: -f1 | sort -u
  printf '%s\n' "${DOT_RESERVED_COMMANDS[@]}"
}

# The file a command runs, into KERNEL_FILE: dotdot's own first, looked up
# directly; then, when some owners run unprefixed, whatever bash dot lists
# under that name; then each plugin's under its owner, directly.
kernel::find() {
  local name="$1" path part owner plugin
  kernel::load_unprefixed
  path="${name//://}.sh"
  for part in "${SYSTEM_PARTS[@]}"; do
    KERNEL_FILE="$SYSTEM_DIR/$part/$MODULE_COMMANDS_DIR/$path"
    [ ! -f "$KERNEL_FILE" ] || return 0
  done
  for part in "${CORE_MODULES[@]}"; do
    KERNEL_FILE="$MODULES_DIR/$part/$MODULE_COMMANDS_DIR/$path"
    [ ! -f "$KERNEL_FILE" ] || return 0
  done
  if [ "$KERNEL_UNPREFIXED" != " " ]; then
    KERNEL_FILE=$(kernel::commands | awk -F'|' -v wanted="$name" '$1 == wanted { print $2; exit }')
    [ -z "$KERNEL_FILE" ] || return 0
  fi
  owner="${name%%:*}"
  [ "$owner" != "$name" ] || return 1
  for plugin in "$PLUGINS_DIR/$owner"/*/; do
    KERNEL_FILE="${plugin%/}/$MODULE_COMMANDS_DIR/${path#*/}"
    [ ! -f "$KERNEL_FILE" ] || return 0
  done
  return 1
}

# Every migration not yet applied, in order: each file under migrations/
# whose name the state.migrations setting does not list.
kernel::pending_migrations() {
  local file applied
  dot::use framework.helpers.json
  applied=$(dot::setting state.migrations "[]" 2>/dev/null) || applied="[]"
  applied=" $(framework.helpers.json::values "$applied" '.[]' | tr '\n' ' ') "
  for file in "$MIGRATIONS_DIR"/*.sh; do
    [ -f "$file" ] || continue
    file="${file##*/}"
    [[ "$applied" == *" ${file%.sh} "* ]] || printf '%s\n' "$MIGRATIONS_DIR/$file"
  done
}

kernel::description() {
  sed -n 's/^DESCRIPTION="\(.*\)"$/\1/p' "$1" | head -n 1
}

# Every command with its description, grouped by namespace.
kernel::list() {
  local name file namespace previous=""
  {
    cat <<EOF
dotdot: the context, rules, and tools your coding agents work by.

Usage:
  bash dot <command> [arguments]
  bash dot <command> --help

Commands:
EOF
    while IFS='|' read -r name file; do
      namespace="${name%%:*}"
      [ "$name" = "$namespace" ] || [ "$namespace" = "$previous" ] || printf '\n'
      previous="$namespace"
      printf '  %s %s\n' "$(framework.console.output::paint green "$(printf '%-*s' "$KERNEL_COLUMN_WIDTH" "$name")")" "$(kernel::description "$file")"
    done < <(kernel::commands | awk -F'|' '{ print ($1 ~ /:/ ? 1 : 0) "|" $0 }' | sort | cut -d'|' -f2-)
    cat <<EOF

Options:
  --agent   Plain output for AI agents (automatic under AI_AGENT or CLAUDECODE).
EOF
  } | framework.console.output::help
}

# The command closest to <name> (at most 2 edits away), or nothing.
kernel::closest() {
  kernel::commands | cut -d'|' -f1 | awk -v typed="$1" '
    function distance(a, b,   i, j, m, n, cost, d) {
      m = length(a); n = length(b)
      for (i = 0; i <= m; i++) d[i, 0] = i
      for (j = 0; j <= n; j++) d[0, j] = j
      for (i = 1; i <= m; i++)
        for (j = 1; j <= n; j++) {
          cost = substr(a, i, 1) == substr(b, j, 1) ? 0 : 1
          d[i, j] = d[i - 1, j] + 1
          if (d[i, j - 1] + 1 < d[i, j]) d[i, j] = d[i, j - 1] + 1
          if (d[i - 1, j - 1] + cost < d[i, j]) d[i, j] = d[i - 1, j - 1] + cost
        }
      return d[m, n]
    }
    { score = distance(typed, $0); if (best == "" || score < low) { best = $0; low = score } }
    END { if (best != "" && low <= 2) print best }
  '
}

kernel::run() {
  local name="${1-}" file
  if ! { [[ "$name" =~ $DOT_COMMAND_PATTERN ]] && kernel::find "$name"; }; then
    local closest
    closest=$(kernel::closest "$name")
    [ -z "$closest" ] || framework.console.output::fail "There's no command $name. Did you mean $closest?" "To list all available commands, run: bash dot"
    framework.console.output::fail "There's no command $name." "To list all available commands, run: bash dot"
  fi
  file="$KERNEL_FILE"
  shift
  case "$name:${1-}" in
    migrate:* | update:* | *:-h | *:--help) ;;
    *)
      [ -z "$(kernel::pending_migrations)" ] \
        || framework.console.output::fail "dotdot's files need a quick upgrade first." "Please run: bash dot migrate"
      ;;
  esac
  DOT_COMMAND="$name"
  DOT_PLUGIN=""
  case "$file" in
    "$PLUGINS_DIR"/*)
      DOT_PLUGIN="${file#"$PLUGINS_DIR"/}"
      DOT_PLUGIN="${DOT_PLUGIN%%/"$MODULE_COMMANDS_DIR"/*}"
      ;;
  esac
  # Who is running is fixed before the command's code loads.
  readonly DOT_COMMAND DOT_PLUGIN
  . "$file"
  # --<flag>=<value> is the same as --<flag> <value>.
  local arguments=() argument
  for argument in "$@"; do
    case "$argument" in
      --[a-z]*=*) arguments+=("${argument%%=*}" "${argument#*=}") ;;
      *) arguments+=("$argument") ;;
    esac
  done
  set -- ${arguments[@]+"${arguments[@]}"}
  case "${1-}" in
    -h | --help)
      usage | framework.console.output::help
      return 0
      ;;
  esac
  handle "$@"
}

kernel::handle() {
  case "${1-}" in
    '' | list | -h | --help) kernel::list ;;
    help)
      shift
      [ $# -gt 0 ] || { kernel::list; return 0; }
      kernel::run "$1" --help
      ;;
    *) kernel::run "$@" ;;
  esac
}
