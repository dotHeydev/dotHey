#!/usr/bin/env bash

dot::use framework.console.output framework.helpers.fs framework.helpers.json framework.helpers.text

PLUGIN_API=3
PLUGIN_ROOT="dotdot"
PLUGIN_REQUIRES_KEY="requires"
PLUGIN_DESCRIPTION_KEY="description"
PLUGIN_DEPENDS_KEY="depends"
PLUGIN_SETTINGS_KEY="settings"
PLUGIN_SETTING_KEY_PATTERN='^[a-z][A-Za-z0-9]*$'
PLUGIN_LINKED_DIRS=(skills agents)
PLUGIN_SCRIPT_PATTERN='^[a-z][a-z0-9-]*\.sh$'
PLUGIN_UNKNOWN_COMMIT="unknown"

core.system.plugins.manifest::id() {
  local id
  id=$(framework.helpers.text::lower "$1")
  id="${id%.git}"
  guards::plugin_id "$id" || return 1
  printf '%s\n' "$id"
}

core.system.plugins.manifest::owner() {
  printf '%s\n' "${1%%/*}"
}

core.system.plugins.manifest::directory() {
  printf '%s\n' "$PLUGINS_DIR/$1"
}

# A plugin's plugin.json, or nothing.
core.system.plugins.manifest::document() {
  [ ! -f "$1/$PLUGIN_MANIFEST" ] || cat -- "$1/$PLUGIN_MANIFEST"
}

# A plugin.json key's value (requires, description), or nothing.
core.system.plugins.manifest::value() {
  framework.helpers.json::field "$(core.system.plugins.manifest::document "$1")" ".$2"
}

# Each entry of a plugin.json list (depends, links), one per line.
core.system.plugins.manifest::list() {
  framework.helpers.json::values "$(core.system.plugins.manifest::document "$1")" ".$2[]"
}

# The lock's entries as "<owner>/<name> <origin> <ref> <commit>" lines, in
# the order the plugins were added.
core.system.plugins.manifest::entries() {
  local document entry
  [ -f "$PLUGINS_LOCK" ] || return 0
  document=$(cat -- "$PLUGINS_LOCK")
  while IFS= read -r entry; do
    printf '%s %s %s %s\n' "$(framework.helpers.json::field "$entry" .id)" "$(framework.helpers.json::field "$entry" .origin)" \
      "$(framework.helpers.json::field "$entry" .ref)" "$(framework.helpers.json::field "$entry" .commit)"
  done < <(framework.helpers.json::values "$document" '.plugins[]')
}

# Writes the lock from "<owner>/<name> <origin> <ref> <commit>" lines on stdin.
core.system.plugins.manifest::write_lock() {
  local id origin ref commit separator=""
  mkdir -p -- "$(dirname -- "$PLUGINS_LOCK")" || return 1
  {
    printf '{\n  "plugins": ['
    while read -r id origin ref commit; do
      printf '%s\n    {"id": %s, "origin": %s, "ref": %s, "commit": %s}' "$separator" "$(framework.helpers.json::string "$id")" \
        "$(framework.helpers.json::string "$origin")" "$(framework.helpers.json::string "$ref")" "$(framework.helpers.json::string "$commit")"
      separator=","
    done
    [ -z "$separator" ] || printf '\n  '
    printf ']\n}\n'
  } | framework.helpers.fs::write "$PLUGINS_LOCK"
}

core.system.plugins.manifest::installed() {
  core.system.plugins.manifest::entries | while read -r id _; do
    ! guards::plugin_id "$id" || printf '%s\n' "$id"
  done
}

core.system.plugins.manifest::lock_entry() {
  local id rest
  while read -r id rest; do
    [ "$id" = "$1" ] || continue
    printf '%s\n' "$rest"
    return 0
  done < <(core.system.plugins.manifest::entries)
  return 1
}

core.system.plugins.manifest::lock() {
  local entries
  guards::plugin_id "$1" || return 1
  entries=$(core.system.plugins.manifest::entries)
  {
    printf '%s\n' "$entries" | awk -v wanted="$1" -v entry="$1 $2" '
      $1 == wanted { if (!done) print entry; done = 1; next }
      NF { print }
      END { if (!done) print entry }
    '
  } | core.system.plugins.manifest::write_lock
}

core.system.plugins.manifest::unlock() {
  local entries
  core.system.plugins.manifest::lock_entry "$1" >/dev/null || return 1
  entries=$(core.system.plugins.manifest::entries)
  printf '%s\n' "$entries" | awk -v wanted="$1" 'NF && $1 != wanted' | core.system.plugins.manifest::write_lock
}

core.system.plugins.manifest::commands() {
  local source="$1" file name
  [ -d "$source/$MODULE_COMMANDS_DIR" ] || return 0
  while IFS= read -r file; do
    name="${file#"$source/$MODULE_COMMANDS_DIR"/}"
    name="${name%.sh}"
    printf '%s\n' "${name//\//:}"
  done < <(find "$source/$MODULE_COMMANDS_DIR" -mindepth 1 -maxdepth "$DOT_COMMAND_MAX_DEPTH" -type f -name '*.sh' | sort)
}

core.system.plugins.manifest::taken_commands() {
  local plugin="$1" source="$2"
  core.system.plugins.manifest::commands "$source" | sed "s|^|$(core.system.plugins.manifest::owner "$plugin"):|" \
    | grep -xF -f <(kernel::commands | cut -d'|' -f1) | grep -vxF -f <(core.system.plugins.manifest::own_commands "$plugin") || true
}

core.system.plugins.manifest::own_commands() {
  local directory
  directory=$(core.system.plugins.manifest::directory "$1")
  [ -d "$directory" ] || return 0
  core.system.plugins.manifest::commands "$directory" | sed "s|^|$(core.system.plugins.manifest::owner "$1"):|"
}

core.system.plugins.manifest::validate_commands() {
  local source="$1" entry relative depth
  [ -d "$source/$MODULE_COMMANDS_DIR" ] || return 0
  while IFS= read -r entry; do
    relative="${entry#"$source/$MODULE_COMMANDS_DIR"/}"
    depth=$(printf '%s' "$relative" | tr -cd '/' | wc -c | tr -d ' ')
    [ -d "$entry" ] && continue
    [[ "$(basename -- "$entry")" =~ $PLUGIN_SCRIPT_PATTERN ]] && [ "$depth" -lt "$DOT_COMMAND_MAX_DEPTH" ] \
      || { dot::raise "$MODULE_COMMANDS_DIR/$relative must be a <name>.sh command, at most $DOT_COMMAND_MAX_DEPTH levels deep."; return 1; }
  done < <(find "$source/$MODULE_COMMANDS_DIR" -mindepth 1 ! -name '.*')
}

core.system.plugins.manifest::validate_owner() {
  local owner
  owner=$(core.system.plugins.manifest::owner "$1")
  ! kernel::reserved_names | grep -xF -- "$owner" >/dev/null \
    || { dot::raise "$1 can't be added: its commands would run as $owner:<command>, but $owner is one of dotdot's own command names, so they would mix with dotdot's."; return 1; }
}

core.system.plugins.manifest::linked_entries() {
  local root="$1" directory entry
  for directory in "${PLUGIN_LINKED_DIRS[@]}"; do
    [ -d "$root/$directory" ] || continue
    while IFS= read -r entry; do
      printf '%s/%s\n' "$directory" "$(basename -- "$entry")"
    done < <(find "$root/$directory" -mindepth 1 -maxdepth 1 ! -name "$KEEP_FILE" | sort)
  done
}

# A skill or agent with the name of dotdot's or another plugin's is only
# reported: first come, first served wherever both are linked to one place.
core.system.plugins.manifest::validate_links() {
  local source="$1" plugin="$2" entry root
  while IFS= read -r entry; do
    while IFS= read -r root; do
      [ "$root" != "$PLUGINS_DIR/$plugin" ] || continue
      [ ! -e "$root/$entry" ] && [ ! -L "$root/$entry" ] \
        || framework.console.output::warn "$plugin's $entry has the name of $(dot::relative "$root")'s; wherever both are linked to one place, bash dot link keeps the first declared and reports the other."
    done < <({ paths::modules; paths::plugins; })
  done < <(core.system.plugins.manifest::linked_entries "$source")
}

# A plugin.json's link and append entries as "<kind>\t<origin>\t<destination>"
# rows; anything else under those keys as "!\t<leaf>".
core.system.plugins.manifest::entries_of() {
  framework.helpers.json::leaves "$(core.system.plugins.manifest::document "$1")" | awk -F '\t' -v OFS='\t' '
    ($1 == "link" || $1 == "append") && NF == 4 && $3 ~ /^[0-9]+$/ && $4 != "" { print $1, $2, $4; next }
    $1 == "link" || $1 == "append" { print "!", $0 }
  '
}

# A plugin's link destinations, as project paths.
core.system.plugins.manifest::link_destinations() {
  local kind destination
  while IFS="$(printf '\t')" read -r kind _ destination; do
    [ "$kind" != link ] || printf '%s\n' "$destination"
  done < <(core.system.plugins.manifest::entries_of "$1")
}

# What a plugin may suggest: origins within its own scope (guards::plugin_origin),
# link destinations project paths outside dotdot and .git, append
# destinations also @dot:<Doc>.md. A destination the user or another plugin
# links already, or one plugins.denyLinkOrigin or plugins.denyLinkDestination
# protects, is only reported: a suggestion never applies until activated,
# and a protected one not even then.
core.system.plugins.manifest::validate_declared_links() {
  local source="$1" plugin="$2" kind origin destination path root tab denied_origins denied_destinations list
  tab=$(printf '\t')
  list=$(dot::setting plugins.denyLinkOrigin "[]") && denied_origins=$(framework.helpers.json::values "$list" '.[]') || return 1
  list=$(dot::setting plugins.denyLinkDestination "[]") && denied_destinations=$(framework.helpers.json::values "$list" '.[]' | sed "s|^@dot:|$DOTDOT_NAME/|") || return 1
  while IFS="$tab" read -r kind origin destination; do
    [ "$kind" != "!" ] || { dot::raise "$plugin's $PLUGIN_MANIFEST: link and append are {origin: [destinations]}, not ${origin//$tab/ }."; return 1; }
    guards::plugin_origin "$origin" "$plugin" \
      || { dot::raise "$kind origin $origin must be a path in the plugin, @dot:<Doc>.md, @dotdotSkills, or @dotdotAgents."; return 1; }
    case "$origin" in
      @dot:* | @dotdotSkills | @dotdotAgents) ;;
      *)
        path="${origin#"@plugin:${plugin/\//.}:"}"
        path=$(framework.helpers.fs::pattern_path "$path")
        if [ "$kind" = append ]; then
          [ -f "$source/$path" ] || { dot::raise "append origin $origin must be a file in the plugin."; return 1; }
        else
          [ -e "$source/$path" ] || { dot::raise "link origin $origin is not in the plugin."; return 1; }
        fi
        ;;
    esac
    case "$destination" in
      @dot:*) destination="$DOTDOT_NAME/${destination#@dot:}" ;;
    esac
    path="$origin"
    case "$path" in
      @*) ;;
      *) path="@plugin:${plugin/\//.}:$path" ;;
    esac
    if printf '%s\n' "$denied_origins" | guards::denied "$path"; then
      framework.console.output::warn "$plugin suggests to $kind from $path, which plugins.denyLinkOrigin protects; it never applies, even once activated."
    elif printf '%s\n' "$denied_destinations" | guards::denied "$destination"; then
      framework.console.output::warn "$plugin suggests to $kind to $destination, which plugins.denyLinkDestination protects; it never applies, even once activated."
    fi
    if [ "$kind" = append ]; then
      guards::plugin_append_destination "$destination" \
        || { dot::raise "append destination $destination must be a project file outside .git/ other than .env, or one of $DOTDOT_NAME/'s top-level docs."; return 1; }
      continue
    fi
    guards::plugin_destination "${destination%/}" \
      || { dot::raise "link destination $destination must be a project path outside $DOTDOT_NAME/ and .git/, other than .env."; return 1; }
    ! paths::links_rows 2>/dev/null | awk -F '\t' -v origin="$path" -v destination="$destination" \
      '($1 == "." || $1 ~ /^\+/) && $2 == "link" && $4 == destination && $3 != origin { found = 1 } END { exit !found }' \
      || framework.console.output::warn "$plugin suggests linking $destination, which $(dot::relative "$SETTINGS_FILE") already links elsewhere; yours stays, and the suggestion only applies if you take it."
    while IFS= read -r root; do
      [ "$root" != "$PLUGINS_DIR/$plugin" ] || continue
      ! core.system.plugins.manifest::link_destinations "$root" | grep -xF -- "$destination" >/dev/null \
        || framework.console.output::warn "$plugin suggests linking $destination, which $(dot::relative "$root") suggests too; both stay inactive until you activate one, and bash dot link keeps the first declared."
    done < <(paths::plugins)
  done < <(core.system.plugins.manifest::entries_of "$source")
}

# plugin.json is a JSON object; of its keys only the schema's are read, any
# other ignored: requires, description, depends (a list),
# link and append ({origin: [destinations]}), and settings (an object of
# defaults, each key camelCase, written into dot.json on install).
core.system.plugins.manifest::validate_document() {
  local document key value
  document=$(core.system.plugins.manifest::document "$1")
  case "$(framework.helpers.json::field "$document" .)" in
    "{"*) ;;
    *) dot::raise "$2's $PLUGIN_ROOT/$PLUGIN_MANIFEST is not a JSON object."; return 1 ;;
  esac
  value=$(framework.helpers.json::field "$document" ".$PLUGIN_DEPENDS_KEY")
  case "$value" in
    "" | "["*) ;;
    *) dot::raise "$2's $PLUGIN_ROOT/$PLUGIN_MANIFEST: $PLUGIN_DEPENDS_KEY must be a list."; return 1 ;;
  esac
  for key in link append; do
    value=$(framework.helpers.json::field "$document" ".$key")
    case "$value" in
      "" | "{"*) ;;
      *) dot::raise "$2's $PLUGIN_ROOT/$PLUGIN_MANIFEST: $key must be {origin: [destinations]}."; return 1 ;;
    esac
  done
  case "$(framework.helpers.json::encoded "$document" ".$PLUGIN_SETTINGS_KEY")" in
    null | "{"*) ;;
    *) dot::raise "$2's $PLUGIN_ROOT/$PLUGIN_MANIFEST: $PLUGIN_SETTINGS_KEY must be an object."; return 1 ;;
  esac
  key=$(framework.helpers.json::keys "$document" ".$PLUGIN_SETTINGS_KEY" | grep -vxE "$PLUGIN_SETTING_KEY_PATTERN" | head -n 1)
  [ -z "$key" ] || { dot::raise "$2's $PLUGIN_ROOT/$PLUGIN_MANIFEST: setting $key must be camelCase (letters and digits, a lowercase first)."; return 1; }
  [[ "$(framework.helpers.json::encoded "$document" ".$PLUGIN_SETTINGS_KEY")" != *'"@env:'* ]] \
    || { dot::raise "$2's $PLUGIN_ROOT/$PLUGIN_MANIFEST: setting defaults may not refer to .env; only $(dot::relative "$SETTINGS_FILE") does."; return 1; }
}

core.system.plugins.manifest::validate() {
  local source="$1" plugin="$2" requires entry taken
  [ -f "$source/$PLUGIN_MANIFEST" ] || { dot::raise "$plugin has no $PLUGIN_ROOT/$PLUGIN_MANIFEST, which needs at least a \"$PLUGIN_DESCRIPTION_KEY\"."; return 1; }
  core.system.plugins.manifest::validate_document "$source" "$plugin" || return 1
  [ -n "$(core.system.plugins.manifest::value "$source" "$PLUGIN_DESCRIPTION_KEY")" ] \
    || { dot::raise "$plugin's $PLUGIN_ROOT/$PLUGIN_MANIFEST needs a \"$PLUGIN_DESCRIPTION_KEY\", the one key it must have."; return 1; }
  requires=$(core.system.plugins.manifest::value "$source" "$PLUGIN_REQUIRES_KEY")
  [ -z "$requires" ] || [ "$requires" = "$PLUGIN_API" ] \
    || { dot::raise "$plugin needs plugin API $requires; this dotdot has $PLUGIN_API. Update the plugin or dotdot."; return 1; }
  [ -z "$(find "$source" -type l -print -quit)" ] || { dot::raise "$plugin holds symlinks."; return 1; }
  [ -z "$(find "$source/$PLUGIN_STUBS_DIR" -name .git -print -quit 2>/dev/null)" ] \
    || { dot::raise "$plugin has stubs under .git/; a plugin may not seed git's own files."; return 1; }
  core.system.plugins.manifest::validate_owner "$plugin" || return 1
  core.system.plugins.manifest::validate_commands "$source" || return 1
  taken=$(core.system.plugins.manifest::taken_commands "$plugin" "$source")
  [ -z "$taken" ] || { dot::raise "$plugin's commands are already taken: $(printf '%s' "$taken" | paste -sd ' ' -)"; return 1; }
  core.system.plugins.manifest::validate_links "$source" "$plugin" || return 1
  core.system.plugins.manifest::validate_declared_links "$source" "$plugin" || return 1
  for entry in "$source/$PLUGIN_CONTEXT_DIR"/*; do
    [ -e "$entry" ] || continue
    [ -f "$entry" ] && guards::document "$(basename -- "$entry")" \
      || { dot::raise "$PLUGIN_CONTEXT_DIR/$(basename -- "$entry") must be a .md file."; return 1; }
  done
}

core.system.plugins.manifest::missing_dependencies() {
  local dependency
  while IFS= read -r dependency; do
    case "$dependency" in
      framework.integrations.*) [ -d "$FRAMEWORK_DIR/integrations/${dependency#framework.integrations.}" ] || printf '%s\n' "$dependency" ;;
      *) command -v "$dependency" >/dev/null || printf '%s\n' "$dependency" ;;
    esac
  done < <(core.system.plugins.manifest::list "$1" "$PLUGIN_DEPENDS_KEY")
}
