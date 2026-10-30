# shellcheck shell=bash

dot::use framework.console.output

KERNEL_COLUMN_WIDTH=20
# What the version reads as for a core no release stamped (a source checkout).
KERNEL_UNRELEASED="(unreleased)"
KERNEL_FILE=""
KERNEL_UNPREFIXED_SETTING="plugins.unprefixedCommandOwners"
KERNEL_FEATURE_FLAGS_DOCS="feature-flags"
KERNEL_UNPREFIXED=""
KERNEL_UNPREFIXED_READ=false
# Old names that still run a command, never listed: "<old>=<new>".
KERNEL_ALIASES=("scan:frontmatter=frontmatter:show")
# The commands that set dotdot up, or run before it is: no reminder to.
KERNEL_SETUP_COMMANDS=" setup setup:done adopt relocate migrate upgrade "

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

# dotdot's own commands, found with a single find over every module on (with
# --all, every module).
kernel::core_commands() {
  local module directories=() file name
  while IFS= read -r module; do
    [ ! -d "$module/$MODULE_COMMANDS_DIR" ] || directories+=("$module/$MODULE_COMMANDS_DIR")
  done < <(paths::modules "$@")
  while IFS= read -r file; do
    name="${file#"$CORE_DIR"/*/*/"$MODULE_COMMANDS_DIR"/}"
    name="${name%.sh}"
    name="${name//\//:}"
    [[ "$name" =~ $DOT_COMMAND_PATTERN ]] && printf '%s|%s\n' "$name" "$file"
  done < <(find "${directories[@]}" -mindepth 1 -maxdepth "$DOT_CORE_COMMAND_MAX_DEPTH" -type f -name '*.sh' | sort)
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

# The first parts of dotdot's own command names, those a feature flag turns
# off included, and the names bash dot itself answers to: no plugin owner may
# take one.
kernel::reserved_names() {
  kernel::core_commands --all | cut -d'|' -f1 | cut -d: -f1 | sort -u
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
  while IFS= read -r part; do
    KERNEL_FILE="$MODULES_DIR/$part/$MODULE_COMMANDS_DIR/$path"
    [ ! -f "$KERNEL_FILE" ] || return 0
  done < <(paths::core_modules)
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
# whose name state.migrations does not list.
kernel::pending_migrations() {
  local file applied
  dot::use framework.helpers.json
  applied=$(dot::state migrations "[]" 2>/dev/null) || applied="[]"
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

# Whether the command in <file> declares HIDDEN=true: it runs, but isn't listed.
kernel::is_hidden() {
  grep -q '^HIDDEN=true$' "$1"
}

# The installed commit (state.commit), or nothing when unknown.
kernel::commit() {
  dot::state commit "" 2>/dev/null || true
}

# <value> as a JSON string, or null when empty.
kernel::json_or_null() {
  if [ -n "$1" ]; then framework.helpers.json::string "$1"; else printf null; fi
}

kernel::print_version() {
  local version
  dot::use framework.helpers.json
  version=$(dot::version)
  if $DOT_JSON; then
    printf '{"version":%s,"commit":%s}\n' "$(kernel::json_or_null "$version")" "$(kernel::json_or_null "$(kernel::commit)")"
  else
    printf 'dotdot %s\n' "${version:-$KERNEL_UNRELEASED}"
  fi
}

# The docs at <anchor>, on the main branch: the docs aren't versioned.
kernel::docs_link() {
  # shellcheck disable=SC2059
  printf "$DOT_DOCS_URL#%s\n" main "${1:-$DOT_DOCS_DEFAULT}"
}

# The docs a core command's help ends with: its DOCS anchor (a full URL for a
# plugin's command), on the docs of the installed version.
kernel::docs() {
  local file="$1" anchor
  anchor=$(sed -n 's/^DOCS="\(.*\)"$/\1/p' "$file" | head -n 1)
  case "$anchor" in
    https://*) printf '%s\n' "$anchor"; return ;;
  esac
  case "$file" in "$PLUGINS_DIR"/*) return ;; esac
  kernel::docs_link "$anchor"
}

# The module, turned off by its feature flag, whose command <name> is.
kernel::disabled_module_of() {
  local path="${1//://}.sh" module
  while IFS= read -r module; do
    [ ! -f "$MODULES_DIR/$module/$MODULE_COMMANDS_DIR/$path" ] || { printf '%s\n' "$module"; return 0; }
  done < <(paths::disabled_modules)
  return 1
}

# A command's help (usage) as JSON: its name, description, usage lines,
# arguments, options, examples, and docs, read from the sections of the help.
# A help page on stdin (plain) as JSON fields, all it says: "about",
# "usage", "arguments", "options", "notes", "examples", and "sections" (any
# other, as {"title", "text"}).
kernel::help_fields() {
  local kind entry text usage="" arguments="" options="" notes="" examples="" sections="" about=""
  dot::use framework.helpers.json
  # A tab is whitespace to read, so an empty field collapses: about and note
  # rows carry their text in the second field.
  while IFS=$'\t' read -r kind entry text; do
    entry="${entry//$'\036'/$'\n'}"
    text="${text//$'\036'/$'\n'}"
    case "$kind" in
      about)
        while [ "${entry%$'\n'}" != "$entry" ]; do entry="${entry%$'\n'}"; done
        about="$entry"
        ;;
      usage) usage="$usage${usage:+,}$(framework.helpers.json::string "$entry")" ;;
      example) examples="$examples${examples:+,}$(framework.helpers.json::string "$entry")" ;;
      note) notes="$notes${notes:+,}$(framework.helpers.json::string "$entry")" ;;
      section)
        while [ "${text%$'\n'}" != "$text" ]; do text="${text%$'\n'}"; done
        sections="$sections${sections:+,}{\"title\":$(framework.helpers.json::string "$entry"),\"text\":$(framework.helpers.json::string "$text")}"
        ;;
      argument | option)
        entry=$(printf '{"name":%s,"description":%s}' "$(framework.helpers.json::string "$entry")" "$(framework.helpers.json::string "$text")")
        if [ "$kind" = argument ]; then arguments="$arguments${arguments:+,}$entry"; else options="$options${options:+,}$entry"; fi
        ;;
    esac
  done < <(awk -v styled=0 -f "$OUTPUT_RENDERER" | awk -f "$SYSTEM_DIR/help.awk")
  printf '"about":%s,"usage":[%s],"arguments":[%s],"options":[%s],"notes":[%s],"examples":[%s],"sections":[%s]' \
    "$(framework.helpers.json::string "$about")" "$usage" "$arguments" "$options" "$notes" "$examples" "$sections"
}

# A command's help as JSON: what its help page says, with its name,
# description, and docs.
kernel::help_json() {
  local name="$1" file="$2"
  dot::use framework.helpers.json
  printf '{"name":%s,"description":%s,%s,"docs":%s}\n' \
    "$(framework.helpers.json::string "$name")" "$(framework.helpers.json::string "$(kernel::description "$file")")" \
    "$(usage | kernel::help_fields)" "$(framework.helpers.json::string "$(kernel::docs "$file")")"
}

# Every command with its description, grouped by namespace.
# The listing's page around its commands: what dotdot is and how to run it,
# then (with "end") the options and exit statuses every command shares.
kernel::list_page() {
  local release
  if [ "${1-}" != end ]; then
    release=$(dot::version)
    cat <<PAGE
dotdot $([ -n "$release" ] && printf '(v%s)' "$release" || printf '%s' "$KERNEL_UNRELEASED")
The context, rules, and tools your coding agents work by.

Usage:
  bash dot <command> [arguments]
  bash dot <command> --help
PAGE
    return
  fi
  cat <<PAGE
Options:
  --agent         For AI agents: plain output, never a prompt (automatic under
                  AI_AGENT or CLAUDECODE).
  --no-input      Never prompt; what needs an answer fails instead (automatic
                  under CI).
  --json          JSON on stdout, errors as JSON on stderr, where a command
                  supports it; bash dot help <command> --json describes one.
  -v, --version   Show dotdot's version.
  -h, --help      Show this help.

Exit statuses:
  0 success · 1 failure · 2 wrong usage · 4 not found · 5 needs something
  first (a person at a terminal, a clean tree, ...) · 130 interrupted
PAGE
}

# Every command listed, as "<name>|<file>": hidden ones left out, dotdot's
# top-level ones first, then by name.
kernel::listed_commands() {
  local name file
  while IFS='|' read -r name file; do
    kernel::is_hidden "$file" || printf '%s|%s\n' "$name" "$file"
  done < <(kernel::commands | awk -F'|' '{ print ($1 ~ /:/ ? 1 : 0) "|" $0 }' | sort -t'|' -k1,1 -k2,2 | cut -d'|' -f2-)
}

kernel::list() {
  local name file namespace previous="" commands="" version
  if $DOT_JSON; then
    dot::use framework.helpers.json
    while IFS='|' read -r name file; do
      commands="$commands${commands:+,}{\"name\":$(framework.helpers.json::string "$name"),\"description\":$(framework.helpers.json::string "$(kernel::description "$file")")}"
    done < <(kernel::listed_commands)
    version=$(dot::version)
    printf '{"version":%s,%s,"commands":[%s]}\n' "$(kernel::json_or_null "$version")" \
      "$({ kernel::list_page; printf '\n'; kernel::list_page end; } | kernel::help_fields)" "$commands"
    return
  fi
  {
    kernel::list_page
    printf '\nCommands:\n'
    while IFS='|' read -r name file; do
      namespace="${name%%:*}"
      [ "$name" = "$namespace" ] || [ "$namespace" = "$previous" ] || printf '\n'
      previous="$namespace"
      printf '  %s %s\n' "$(framework.console.output::bold "$(printf '%-*s' "$KERNEL_COLUMN_WIDTH" "$name")")" "$(kernel::description "$file")"
    done < <(kernel::listed_commands)
    printf '\n'
    kernel::list_page end
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
  local name="${1-}" file alias
  paths::read_flags
  for alias in "${KERNEL_ALIASES[@]}"; do
    [ "$name" != "${alias%%=*}" ] || name="${alias#*=}"
  done
  if ! { [[ "$name" =~ $DOT_COMMAND_PATTERN ]] && kernel::find "$name"; }; then
    local closest module
    ! module=$(kernel::disabled_module_of "$name") \
      || framework.console.output::fail_as "$EXIT_PRECONDITION" "The $name feature is turned off by a feature flag." \
        "Turn it on in $(dot::relative "$SETTINGS_FILE"): \"featureFlags\": {\"$module\": true}" "To know more about feature flags visit: $(kernel::docs_link "$KERNEL_FEATURE_FLAGS_DOCS")"
    closest=$(kernel::closest "$name")
    [ -z "$closest" ] || framework.console.output::fail_as "$EXIT_USAGE" "There's no command $name. Did you mean $closest?" "To list all available commands, run: bash dot"
    framework.console.output::fail_as "$EXIT_USAGE" "There's no command $name." "To list all available commands, run: bash dot"
  fi
  file="$KERNEL_FILE"
  shift
  case "$name:${1-}" in
    migrate:* | upgrade:* | *:-h | *:--help) ;;
    *)
      [ -z "$(kernel::pending_migrations)" ] \
        || framework.console.output::fail_as "$EXIT_PRECONDITION" "dotdot's files need a quick upgrade first." "Please run: bash dot migrate"
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
  # --<flag>=<value> is the same as --<flag> <value>; --json is taken here
  # when the command supports it (JSON=true), and left as an unknown flag when
  # it doesn't. Everything after -- passes as is.
  local arguments=() argument ended=false
  for argument in "$@"; do
    if $ended; then
      arguments+=("$argument")
      continue
    fi
    case "$argument" in
      --) ended=true; arguments+=("$argument") ;;
      --json) [ "${JSON-}" = true ] || arguments+=("$argument") ;;
      --[a-z]*=*) arguments+=("${argument%%=*}" "${argument#*=}") ;;
      *) arguments+=("$argument") ;;
    esac
  done
  set -- ${arguments[@]+"${arguments[@]}"}
  case "${1-}" in
    -h | --help)
      if $DOT_JSON; then
        kernel::help_json "$name" "$file"
      else
        { usage; kernel::docs_section "$file"; } | framework.console.output::help
      fi
      return 0
      ;;
  esac
  kernel::suggest_setup "$name"
  handle "$@"
}

# Until setup has run (state.setup.harnesses is empty), anyone running any other
# <command> is told to: a line for a person, a notice on stderr under --json.
kernel::suggest_setup() {
  ! $DOT_INTERNAL || return 0
  [[ "$KERNEL_SETUP_COMMANDS" != *" $1 "* ]] || return 0
  [ "$(dot::state setup.harnesses "[]" 2>/dev/null)" = "[]" ] || return 0
  framework.console.output::info "dotdot isn't set up yet: run bash dot setup to link it where your agents read it." >&2
  $DOT_JSON || framework.console.output::newline >&2
}

kernel::docs_section() {
  local docs
  docs=$(kernel::docs "$1")
  [ -z "$docs" ] || printf '\nDocs:\n  %s\n' "$docs"
}

# Whether --json is among <arguments>, before any --.
kernel::wants_json() {
  local argument
  for argument in "$@"; do
    case "$argument" in
      --) return 1 ;;
      --json) return 0 ;;
    esac
  done
  return 1
}

kernel::handle() {
  ! kernel::wants_json "$@" || DOT_JSON=true
  case "${1-}" in
    '' | list | -h | --help | --json)
      kernel::suggest_setup list
      kernel::list
      ;;
    version | -v | --version) kernel::print_version ;;
    help)
      shift
      [ "${1-}" != --json ] || shift
      [ $# -gt 0 ] || { kernel::list; return 0; }
      kernel::run "$1" --help
      ;;
    *) kernel::run "$@" ;;
  esac
}
