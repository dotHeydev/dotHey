#!/usr/bin/env bash

dot::use framework.helpers.date framework.helpers.frontmatter framework.helpers.fs framework.helpers.json

LINK_SEPARATOR="->"
LINK_TREE_SUFFIX="/*"
LINK_DOT_SHORTCUT="@dot:"
LINK_MODULE_SHORTCUT="@module:"
LINK_PLUGIN_SHORTCUT="@plugin:"
LINK_HARNESS_SHORTCUT="@harness:"
LINK_TAB=$'\t'
LINK_DOTDOT_LABEL="dotdot"
LINK_AGENTS_DIR=".agents"
LINK_NEW_FILE=" (new file)"
LINK_MANAGED_DIRS=("$CORE_DIR" "$PLUGINS_DIR" "$DOTDOT_ROOT/.harnesses" "$DOTDOT_ROOT/Skills" "$DOTDOT_ROOT/Agents")

LINK_ORIGINS=()
LINK_DESTINATIONS=()
LINK_LABELS=()
LINK_ACTIONS=()
LINK_TREE_DIRS=()
LINK_FAILURES=0
LINK_OVERRIDABLE=0
LINK_CHANGES=0
LINK_WARNINGS=()
LINK_ERRORS=()
LINK_LINKED=0
LINK_UNCHANGED=0
LINK_SKIPPED=0
LINK_REMOVED=0
LINK_SEED_USER=false
LINK_MAP_NOTES=()
LINK_REMOVALS=()
LINK_SWEPT_APPENDS=()
LINK_APPEND_ORIGINS=()
LINK_APPEND_PATHS=()
LINK_APPEND_LABELS=()
LINK_APPEND_MARKERS=()
LINK_APPEND_ACTIONS=()
LINK_APPEND_PLANNED=""
LINK_APPENDED=0
LINK_UNAPPENDED=0
LINK_ACTION=""
LINK_PLANNED=""
LINK_PLANNED_GROUP=""
LINK_GROUP=""
LINK_GROUPS=()
LINK_NOTICES=()
LINK_DENIED_ORIGINS=""
LINK_DENIAL=""
LINK_DENIED_DESTINATIONS=""
LINK_SHORTCUT=""
LINK_EFFECTIVE_MAP=""
LINK_WORK=""
LINK_DROPPED=" "
LINK_EDIT_IN_PLACE=false
LINK_EDITS=()
# Set to plan one plugin's links only (plugins:link, plugins:unlink): its
# waiting links as if active (LINK_ONLY_MODE=link), or its active links taken
# back (unlink); nothing else is planned or pruned.
LINK_ONLY_GROUP=""
LINK_ONLY_MODE=""

core.system.link.service::read_map() {
  paths::links_rows
}

# Whether dot.json holds the links map, rather than dotdot's default
# standing in for it.
core.system.link.service::has_map() {
  [ -f "$SETTINGS_FILE" ] && [ "$(framework.helpers.json::encoded "$(cat -- "$SETTINGS_FILE")" .links)" != null ]
}

# Rows on stdin as the links map, laid out as jq prints it: the general
# links, then each active plugin's group, then the inactive ones; an origin
# keeps its first place, its destinations in order.
core.system.link.service::write_map() {
  local rows
  rows=$(cat)
  framework.helpers.json::set null . "$(core.system.link.service::compact_map "$rows")"
}

core.system.link.service::compact_map() {
  paste -d '\t' <(printf '%s\n' "$1") <(printf '%s\n' "$1" | awk -F '\t' '{ sub(/^\+/, "", $1); print $1; print $3; print $4 }' | framework.helpers.json::lines | paste - - -) | awk -F '\t' '
    # The "<origin>": [destinations] members of the rows of <group> and <kind>.
    function entries(group, kind,   i, key, out, origins, seen_origin, count, j) {
      count = 0
      for (i = 1; i <= total; i++) {
        if (GROUP[i] != group || KIND[i] != kind) continue
        key = ORIGIN[i]
        if (!(key in seen_origin)) { seen_origin[key] = ++count; origins[count] = key; QUOTED[key] = QORIGIN[i]; DESTS[key] = "" }
        DESTS[key] = DESTS[key] (DESTS[key] == "" ? "" : ",") QDEST[i]
      }
      out = ""
      for (j = 1; j <= count; j++) out = out (j > 1 ? "," : "") QUOTED[origins[j]] ":[" DESTS[origins[j]] "]"
      return out
    }
    function join(a, b) { return a == "" ? b : b == "" ? a : a "," b }
    # A group: its links, then "append" (and "remove", for one that is applied).
    function group(id, applied,   out) {
      out = join(entries(id, "link"), "\"append\":{" entries(id, "append") "}")
      if (applied) out = out ",\"remove\":{" entries(id, "remove") "}"
      return out
    }
    NF >= 7 { total++; GROUP[total] = $1; KIND[total] = $2; ORIGIN[total] = $3; QGROUP[total] = $5; QORIGIN[total] = $6; QDEST[total] = $7 }
    END {
      out = group(".", 1)
      inactive = ""
      for (i = 1; i <= total; i++) {
        id = GROUP[i]
        if (id == "." || id in seen) continue
        seen[id] = 1
        if (id ~ /^\+/) out = out "," QGROUP[i] ":{" group(id, 1) "}"
        else inactive = join(inactive, QGROUP[i] ":{" group(id, 0) "}")
      }
      printf "{%s,\"inactive\":{%s}}\n", out, inactive
    }
  '
}

# A plugin's inactive links as their JSON value under inactive, laid out as
# jq prints it.
core.system.link.service::group_json() {
  local compact
  compact=$(awk -F '\t' -v OFS='\t' -v id="$1" '$1 == id' "$LINK_EFFECTIVE_MAP" | { rows=$(cat); core.system.link.service::compact_map "$rows"; })
  framework.helpers.json::set null . "$(framework.helpers.json::encoded "$compact" ".inactive[$(framework.helpers.json::string "$1")]")"
}

# Saves the map into dot.json, the rest of the file left as written:
# whole when the file has no links yet, else edited in place, only the
# suggestions added, refreshed, or dropped and the entries of removed plugins
# touched, the rest left as the user wrote it.
core.system.link.service::save() {
  local document="{}" edit
  [ ! -f "$SETTINGS_FILE" ] || document=$(cat -- "$SETTINGS_FILE")
  $LINK_EDIT_IN_PLACE || LINK_EDITS=("links")
  for edit in ${LINK_EDITS[@]+"${LINK_EDITS[@]}"}; do
    case "$edit" in
      set\|*) document=$(framework.helpers.json::set "$document" ".links.inactive[$(framework.helpers.json::string "${edit#set|}")]" "$(core.system.link.service::group_json "${edit#set|}")" --keep-format) || return 1 ;;
      delete\|*) document=$(framework.helpers.json::delete "$document" ".links${edit#delete|}" --keep-format) || return 1 ;;
      links) document=$(framework.helpers.json::set "$document" .links "$(core.system.link.service::write_map < "$LINK_EFFECTIVE_MAP")" --keep-format) || return 1 ;;
    esac
  done
  printf '%s\n' "$document" | framework.helpers.fs::write "$SETTINGS_FILE"
}

core.system.link.service::has_entries() {
  [ -d "$1" ] && [ -n "$(find "$1" -mindepth 1 -maxdepth 1 ! -name "$KEEP_FILE" -print -quit)" ]
}

# What a plugin's plugin.json declares under link and append, as rows of its
# group: a path in the plugin becomes @plugin:<owner>.<name>:<path>.
core.system.link.service::declared_suggestions() {
  local plugin="$1" shortcut="$LINK_PLUGIN_SHORTCUT${1/\//.}:" kind origin _ destination
  [ -f "$PLUGINS_DIR/$plugin/$PLUGIN_MANIFEST" ] || return 0
  while IFS="$LINK_TAB" read -r kind origin _ destination; do
    case "$kind" in
      link | append) ;;
      *) continue ;;
    esac
    case "$origin" in
      @*) ;;
      *) origin="$shortcut$origin" ;;
    esac
    printf '%s\t%s\t%s\t%s\n' "$plugin" "$kind" "$origin" "$destination"
  done < <(framework.helpers.json::leaves "$(cat -- "$PLUGINS_DIR/$plugin/$PLUGIN_MANIFEST")")
}

# Whether one of a plugin's rows (on stdin) takes an origin from its <kind>
# folder: skills, agents, context, or stubs.
core.system.link.service::suggests() {
  local shortcut="$1" kind="$2" _ origin
  while IFS="$LINK_TAB" read -r _ _ origin _; do
    case "$origin" in
      "$shortcut$kind" | "$shortcut$kind"/*) return 0 ;;
    esac
  done
  return 1
}

# What dotdot finds in a plugin's folders, for each kind it declares nothing
# of: its skills and agents linked into .agents/skills/ and .agents/agents/,
# its context/*.md appended to dotdot's doc of that name (created when
# missing), and each stubs/<path>.stub to <path>.
core.system.link.service::discovered_suggestions() {
  local plugin="$1" declared="$2" directory="$PLUGINS_DIR/$1" shortcut="$LINK_PLUGIN_SHORTCUT${1/\//.}:" kind destination file
  for kind in skills agents; do
    ! core.system.link.service::suggests "$shortcut" "$kind" <<< "$declared" || continue
    core.system.link.service::has_entries "$directory/$kind" || continue
    printf '%s\tlink\t%s%s%s\t%s/%s/\n' "$plugin" "$shortcut" "$kind" "$LINK_TREE_SUFFIX" "$LINK_AGENTS_DIR" "$kind"
  done
  if ! core.system.link.service::suggests "$shortcut" "$PLUGIN_CONTEXT_DIR" <<< "$declared"; then
    for file in "$directory/$PLUGIN_CONTEXT_DIR"/*.md; do
      [ -f "$file" ] || continue
      file="${file##*/}"
      printf '%s\tappend\t%s%s/%s\t%s%s\n' "$plugin" "$shortcut" "$PLUGIN_CONTEXT_DIR" "$file" "$LINK_DOT_SHORTCUT" "$file"
    done
  fi
  if ! core.system.link.service::suggests "$shortcut" "$PLUGIN_STUBS_DIR" <<< "$declared" && [ -d "$directory/$PLUGIN_STUBS_DIR" ]; then
    while IFS= read -r file; do
      destination="${file%"$PLUGIN_STUB_SUFFIX"}"
      printf '%s\tappend\t%s%s/%s\t%s\n' "$plugin" "$shortcut" "$PLUGIN_STUBS_DIR" "$file" "$destination"
    done < <(cd -- "$directory/$PLUGIN_STUBS_DIR" && find . -type f -name "*$PLUGIN_STUB_SUFFIX" | sed 's|^\./||' | sort)
  fi
}

# Everything a plugin suggests, as rows of its group, each once.
core.system.link.service::plugin_suggestions() {
  local declared
  declared=$(core.system.link.service::declared_suggestions "$1")
  {
    [ -z "$declared" ] || printf '%s\n' "$declared"
    core.system.link.service::discovered_suggestions "$1" "$declared"
  } | awk '!seen[$0]++'
}

# The plugin an origin belongs to, <owner>/<name>, or nothing.
core.system.link.service::origin_plugin() {
  local rest
  case "$1" in
    "$LINK_PLUGIN_SHORTCUT"*)
      rest="${1#"$LINK_PLUGIN_SHORTCUT"}"
      rest="${rest%%:*}"
      printf '%s/%s\n' "${rest%%.*}" "${rest#*.}"
      ;;
    "$LINK_DOT_SHORTCUT${PLUGINS_DIR#"$DOTDOT_ROOT"/}"/*/*/*)
      rest="${1#"$LINK_DOT_SHORTCUT${PLUGINS_DIR#"$DOTDOT_ROOT"/}"/}"
      printf '%s\n' "$rest" | cut -d/ -f1-2
      ;;
  esac
}

# Marks where a removed plugin's rows lay, so their broken links get pruned
# and what they appended gets removed.
core.system.link.service::sweep() {
  local plugin="$1" kind="$2" origin="$3" destination="$4"
  destination=$(core.system.link.service::destination_path "$destination")
  guards::stays_inside "$destination" || return 0
  case "$kind" in
    append) LINK_SWEPT_APPENDS+=("$plugin|$destination") ;;
    link)
      case "$origin" in
        @dotdotSkills | @pluginsSkills | @dotdotAgents | @pluginsAgents) LINK_TREE_DIRS+=("$BASE/${destination%/}") ;;
        *)
          if framework.helpers.fs::is_contents_pattern "$origin"; then
            LINK_TREE_DIRS+=("$BASE/${destination%/}")
          else
            destination="$BASE/${destination%/}"
            LINK_TREE_DIRS+=("${destination%/*}")
          fi
          ;;
      esac
      ;;
  esac
}

# The rows this run works from: the links in dot.json (or dotdot's
# default when it has none), less the groups and lines of plugins no longer
# installed (kept when only the map is written, so a full run can still sweep
# them) and the groups to refresh, plus the fresh suggestions of each
# installed plugin to refresh (only plugins:add and plugins:update ask). They
# are written back only when the run is applied.
core.system.link.service::prepare_map() {
  local refresh=" $1 " map_only="${2:-false}" rows group kind origin destination id plugin kept installed
  framework.helpers.fs::make_temp_dir LINK_WORK || { core.system.link.service::fail "Couldn't create a temporary directory; please check free space and \$TMPDIR."; return; }
  if ! rows=$(core.system.link.service::read_map); then
    core.system.link.service::fail "The links in $(dot::relative "$SETTINGS_FILE") can't be read (invalid JSON, or \"links\" isn't an object)." "Please fix it, then run bash dot link again."
    return 0
  elif core.system.link.service::has_map; then
    [[ "$(framework.helpers.json::encoded "$(cat -- "$SETTINGS_FILE")" .links)" != *'"@env:'* ]] \
      || { core.system.link.service::fail "The links can't come from .env; please set them in $(dot::relative "$SETTINGS_FILE") instead."; return 0; }
    core.system.link.service::note_duplicates
    LINK_EDIT_IN_PLACE=true
  else
    LINK_MAP_NOTES+=("add dotdot's default links")
  fi
  while IFS="$LINK_TAB" read -r group kind; do
    [ "$group" = "!" ] && core.system.link.service::fail "This entry in the links of $(dot::relative "$SETTINGS_FILE") doesn't fit their shape: ${kind//$LINK_TAB/ }" "See their shape: bash dot link --help"
  done <<< "$rows"
  [ "$LINK_FAILURES" -eq 0 ] || return 0
  installed=" $(paths::plugins | sed "s|^$PLUGINS_DIR/||" | tr '\n' ' ') "
  kept=""
  while IFS="$LINK_TAB" read -r group kind origin destination; do
    [ -n "$kind" ] || continue
    if [ -n "$LINK_ONLY_GROUP" ]; then
      case "$LINK_ONLY_MODE:$group" in
        link:"$LINK_ONLY_GROUP") group="+$LINK_ONLY_GROUP" ;;
        unlink:"+$LINK_ONLY_GROUP") kind=remove ;;
        *) continue ;;
      esac
      kept="$kept$group$LINK_TAB$kind$LINK_TAB$origin$LINK_TAB$destination"$'\n'
      continue
    fi
    plugin="${group#+}"
    [ "$plugin" != "." ] || plugin=$(core.system.link.service::origin_plugin "$origin")
    if [ -n "$plugin" ] && [[ "$installed" != *" $plugin "* ]] && ! $map_only; then
      case "$group" in
        .)
          core.system.link.service::sweep "$plugin" "$kind" "$origin" "$destination"
          if [ "$kind" = link ]; then
            core.system.link.service::add_edit "delete|[$(framework.helpers.json::string "$origin")]"
          else
            core.system.link.service::add_edit "delete|.${kind}[$(framework.helpers.json::string "$origin")]"
          fi
          ;;
        +*)
          core.system.link.service::sweep "$plugin" "$kind" "$origin" "$destination"
          core.system.link.service::add_edit "delete|[$(framework.helpers.json::string "$plugin")]"
          ;;
        *) core.system.link.service::add_edit "delete|.inactive[$(framework.helpers.json::string "$group")]" ;;
      esac
      [[ "$LINK_DROPPED" == *" $plugin "* ]] || { LINK_DROPPED="$LINK_DROPPED$plugin "; LINK_MAP_NOTES+=("remove the links of $plugin, no longer installed"); }
      continue
    fi
    if [ "$group" = "$plugin" ] && [[ "$refresh" == *" $group "* ]]; then
      core.system.link.service::add_edit "delete|.inactive[$(framework.helpers.json::string "$group")]"
      continue
    fi
    kept="$kept$group$LINK_TAB$kind$LINK_TAB$origin$LINK_TAB$destination"$'\n'
  done <<< "$rows"
  for id in $refresh; do
    [[ "$installed" == *" $id "* ]] || continue
    rows=$(core.system.link.service::plugin_suggestions "$id")
    [ -n "$rows" ] || continue
    kept="$kept$rows"$'\n'
    core.system.link.service::add_edit "set|$id"
    LINK_MAP_NOTES+=("write the links of $id, under \"inactive\"")
  done
  printf '%s' "$kept" > "$LINK_WORK/rows"
  LINK_EFFECTIVE_MAP="$LINK_WORK/rows"
}

# A key the links define twice: JSON keeps only the last, so the earlier
# destinations would be dropped without a word.
core.system.link.service::note_duplicates() {
  local steps key where
  while IFS= read -r steps; do
    [ "${steps%%$LINK_TAB*}" = links ] && [ "$steps" != links ] || continue
    steps="${steps#links$LINK_TAB}"
    key="${steps##*$LINK_TAB}"
    where=""
    [ "$key" = "$steps" ] || where=" under \"${steps%$LINK_TAB*}\""
    where="${where//$LINK_TAB/\" → \"}"
    LINK_NOTICES+=("\"$key\" appears twice in the links of $(dot::relative "$SETTINGS_FILE")$where, so only the last one counts. Please merge them into one list: \"$key\": [\"<first>\", \"<second>\"]")
  done < <(framework.helpers.json::duplicate_keys "$(cat -- "$SETTINGS_FILE")")
}

# Queues an in-place edit of the map, once.
core.system.link.service::add_edit() {
  local edit
  for edit in ${LINK_EDITS[@]+"${LINK_EDITS[@]}"}; do
    [ "$edit" != "$1" ] || return 0
  done
  LINK_EDITS+=("$1")
}

# The applied rows of one kind: the general ones, then each active plugin
# group's, in the map's order.
core.system.link.service::rows() {
  awk -F '\t' -v kind="$1" '$1 == "." && $2 == kind' "$LINK_EFFECTIVE_MAP"
  awk -F '\t' -v kind="$1" '$1 ~ /^\+/ && $2 == kind' "$LINK_EFFECTIVE_MAP"
}

# A destination as a project path: @dot:<path> is in dotdot.
core.system.link.service::destination_path() {
  case "$1" in
    "$LINK_DOT_SHORTCUT"*) printf '%s/%s\n' "$DOTDOT_NAME" "${1#"$LINK_DOT_SHORTCUT"}" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

# The dotdot-relative path an origin names, keeping a "/*" ending, into
# LINK_SHORTCUT: @dot:<path>, @module:<name>:<path>, @harness:<name>:<path>,
# or @plugin:<owner>.<name>:<path>.
core.system.link.service::shortcut_path() {
  local origin="$1" suffix="" rest name base owner path
  case "$origin" in
    */\*) suffix="$LINK_TREE_SUFFIX"; origin="${origin%"$LINK_TREE_SUFFIX"}" ;;
  esac
  case "$origin" in
    "$LINK_DOT_SHORTCUT"*)
      path="${origin#"$LINK_DOT_SHORTCUT"}"
      [ -n "$path" ] || return 1
      LINK_SHORTCUT="$path$suffix"
      return 0
      ;;
    "$LINK_MODULE_SHORTCUT"*)
      rest="${origin#"$LINK_MODULE_SHORTCUT"}"
      name="${rest%%:*}"
      [[ "$name" =~ ^[a-z][a-z0-9-]*$ ]] && paths::module_on "$name" || return 1
      base="$MODULES_DIR/$name"
      [ -d "$base" ] || base="$SYSTEM_DIR/$name"
      ;;
    "$LINK_HARNESS_SHORTCUT"*)
      rest="${origin#"$LINK_HARNESS_SHORTCUT"}"
      name="${rest%%:*}"
      [[ "$name" =~ ^[a-z][a-z0-9-]*$ ]] || return 1
      base="$CORE_DIR/harnesses/$name"
      ;;
    "$LINK_PLUGIN_SHORTCUT"*)
      rest="${origin#"$LINK_PLUGIN_SHORTCUT"}"
      name="${rest%%:*}"
      owner="${name%%.*}"
      [ "$owner" != "$name" ] && guards::plugin_id "$owner/${name#*.}" || return 1
      base="$PLUGINS_DIR/$owner/${name#*.}"
      ;;
    *) return 1 ;;
  esac
  path=""
  [ "$rest" = "$name" ] || path="${rest#*:}"
  base="${base#"$DOTDOT_ROOT"/}"
  LINK_SHORTCUT="$base${path:+/$path}$suffix"
}

# The directories a set's skills or agents are found in: every system part
# and module for dotdot (discovered, not listed), but a module a feature flag
# turns off; every plugin for plugins.
core.system.link.service::set_roots() {
  local root
  case "$1" in
    dotdot)
      for root in "$SYSTEM_DIR"/*/ "$MODULES_DIR"/*/; do
        root="${root%/}"
        [ -d "$root" ] || continue
        [ "${root%/*}" != "$MODULES_DIR" ] || paths::module_on "${root##*/}" || continue
        printf '%s\n' "$root"
      done
      ;;
    plugins) paths::plugins ;;
  esac
}

# Each skill (skills/<name>/SKILL.md) or agent (agents/<name>.md) under a set's
# roots, as "<origin>-><destination>/<name>".
core.system.link.service::set_links() {
  local set="$1" kind="$2" destination="${3%/}" root entry
  while IFS= read -r root; do
    case "$kind" in
      skills)
        for entry in "$root/skills"/*/SKILL.md; do
          [ -f "$entry" ] || continue
          entry="${entry%/SKILL.md}"
          printf '%s%s%s/%s\n' "${entry#"$DOTDOT_ROOT"/}" "$LINK_SEPARATOR" "$destination" "${entry##*/}"
        done
        ;;
      agents)
        for entry in "$root/agents"/*.md; do
          [ -f "$entry" ] || continue
          printf '%s%s%s/%s\n' "${entry#"$DOTDOT_ROOT"/}" "$LINK_SEPARATOR" "$destination" "${entry##*/}"
        done
        ;;
    esac
  done < <(core.system.link.service::set_roots "$set")
}

# An origin and destination as "<dotdot-relative origin>-><project path>"
# lines (a set gives one per skill or agent); an origin no shortcut names
# fails.
core.system.link.service::map_link() {
  local origin="$1" destination set kind module
  destination=$(core.system.link.service::destination_path "$2")
  case "$origin" in
    @dotdotSkills | @pluginsSkills | @dotdotAgents | @pluginsAgents)
      set=plugins
      [ "${origin#@dotdot}" = "$origin" ] || set=dotdot
      kind=agents
      [ "${origin%Skills}" = "$origin" ] || kind=skills
      core.system.link.service::set_links "$set" "$kind" "$destination"
      ;;
    *)
      if core.system.link.service::shortcut_path "$origin"; then
        # A destination folder (ending in /) takes a single origin inside it,
        # under its own name; one origin's contents (/*) go inside it anyway.
        case "$destination" in
          */) framework.helpers.fs::is_contents_pattern "$LINK_SHORTCUT" || destination="$destination$(basename -- "${LINK_SHORTCUT%/}")" ;;
        esac
        printf '%s%s%s\n' "$LINK_SHORTCUT" "$LINK_SEPARATOR" "$destination"
      elif module=$(core.system.link.service::disabled_module_of "$origin"); then
        printf '!Origin %s in %s is in the module %s, which the feature flag featureFlags.%s turns off; not linked.\n' "'$origin'" "$(dot::relative "$SETTINGS_FILE")" "$module" "$module"
      else
        printf '!Origin %s in %s is not @dot:<path>, @module:<name>:<path>, @harness:<name>:<path>, @plugin:<owner>.<name>:<path>, or a skill or agent set; not linked.\n' "'$origin'" "$(dot::relative "$SETTINGS_FILE")"
      fi
      ;;
  esac
}

# The module an @module: origin names, when a feature flag turns it off.
core.system.link.service::disabled_module_of() {
  local name="${1#"$LINK_MODULE_SHORTCUT"}"
  [ "$name" != "$1" ] || return 1
  name="${name%%:*}"
  ! paths::module_on "$name" && printf '%s\n' "$name"
}

# Every remove entry, resolved: that origin is never linked to that
# destination, and a link from it already there is removed.
core.system.link.service::plan_removals() {
  local origin destination entry path child
  while IFS="$LINK_TAB" read -r _ _ origin destination; do
    while IFS= read -r entry; do
      [ "${entry#!}" = "$entry" ] || continue
      path="${entry%%"$LINK_SEPARATOR"*}"
      destination="${entry#*"$LINK_SEPARATOR"}"
      if ! framework.helpers.fs::is_contents_pattern "$path"; then
        core.system.link.service::plan_removal "$path" "$destination"
        continue
      fi
      path="${path%"$LINK_TREE_SUFFIX"}"
      [ -d "$DOTDOT_ROOT/$path" ] || continue
      while IFS= read -r -d '' child; do
        core.system.link.service::plan_removal "$path/${child##*/}" "${destination%/}/${child##*/}"
      done < <(find "$DOTDOT_ROOT/$path" -mindepth 1 -maxdepth 1 ! -name "$KEEP_FILE" -print0 | sort -z)
    done < <(core.system.link.service::map_link "$origin" "$destination")
  done < <(core.system.link.service::rows remove)
}

core.system.link.service::plan_removal() {
  local origin_absolute destination_absolute target source
  guards::stays_inside "$1" && guards::stays_inside "$2" || return 0
  core.system.link.service::resolve_under "$1" "$DOTDOT_ROOT" origin_absolute || return 0
  core.system.link.service::resolve_under "$2" "$BASE" destination_absolute || return 0
  guards::link_destination "$destination_absolute" || return 0
  LINK_REMOVALS+=("$destination_absolute|$origin_absolute")
  [ -L "$destination_absolute" ] || return 0
  framework.helpers.fs::resolve_to target "$destination_absolute" && framework.helpers.fs::resolve_to source "$origin_absolute" || return 0
  [ "$target" = "$source" ] || return 0
  core.system.link.service::add "" "$destination_absolute" "$2" unlink
}

core.system.link.service::is_removed() {
  local removal
  for removal in ${LINK_REMOVALS[@]+"${LINK_REMOVALS[@]}"}; do
    [ "$removal" != "$1|$2" ] || return 0
  done
  return 1
}

# Whether a plugin group's entry (+<owner>/<name>) is one the user protects
# against, in plugins.denyLinkOrigin or plugins.denyLinkDestination, with
# why into LINK_DENIAL; the general links are the user's own and never are.
core.system.link.service::is_denied() {
  local group="$1" kind="$2" origin="$3" destination setting
  [ "${group#+}" != "$group" ] || return 1
  destination=$(core.system.link.service::destination_path "$4")
  if printf '%s\n' "$LINK_DENIED_ORIGINS" | guards::denied "$origin"; then
    setting=plugins.denyLinkOrigin
  elif printf '%s\n' "$LINK_DENIED_DESTINATIONS" | guards::denied "$destination"; then
    setting=plugins.denyLinkDestination
  else
    return 1
  fi
  [ "$kind" = append ] && kind="append to" || kind="link to"
  LINK_DENIAL="Skipped ${group#+}'s $kind $destination: $setting protects it."
}

# The paths plugins.denyLinkOrigin and plugins.denyLinkDestination protect,
# into LINK_DENIED_ORIGINS and LINK_DENIED_DESTINATIONS, one per line
# (destinations as project paths).
core.system.link.service::load_denied() {
  local list entry
  list=$(dot::setting plugins.denyLinkOrigin "[]") || return 1
  LINK_DENIED_ORIGINS=$(framework.helpers.json::values "$list" '.[]')
  list=$(dot::setting plugins.denyLinkDestination "[]") || return 1
  LINK_DENIED_DESTINATIONS=$(framework.helpers.json::values "$list" '.[]' | while IFS= read -r entry; do
    core.system.link.service::destination_path "$entry"
  done)
}

# Every applied link as "<group>\t<mapping>", the general ones first: a
# destination keeps its first origin.
core.system.link.service::mappings() {
  local group origin destination entry
  while IFS="$LINK_TAB" read -r group _ origin destination; do
    ! core.system.link.service::is_denied "$group" link "$origin" "$destination" || { printf '?\t%s\n' "$LINK_DENIAL"; continue; }
    while IFS= read -r entry; do
      printf '%s\t%s\n' "$group" "$entry"
    done < <(core.system.link.service::map_link "$origin" "$destination")
  done < <(core.system.link.service::rows link)
}

# A failure, with its next step, when it has one, after a tab.
core.system.link.service::fail() {
  LINK_ERRORS+=("$1${2:+$LINK_TAB$2}")
  LINK_FAILURES=$((LINK_FAILURES + 1))
}

# Whether <path> is inside any of the <directories> given.
core.system.link.service::is_inside_any() {
  local path="$1" directory
  shift
  for directory in "$@"; do
    framework.helpers.fs::is_inside "$path" "$directory" && return 0
  done
  return 1
}

# Rebuilds what the harnesses set up (setup.harnesses) link from dotdot, so
# renamed and rendered files follow the agents and skills they come from.
core.system.link.service::build_harnesses() {
  local list id
  list=$(dot::setting setup.harnesses "[]" 2>/dev/null) || return 0
  dot::use core.harnesses.harness
  for id in $(framework.helpers.json::values "$list" '.[]'); do
    core.harnesses.harness::valid "$id" || continue
    core.harnesses.harness::call "$id" build \
      || core.system.link.service::fail "Couldn't rebuild what $(core.harnesses.harness::data "$id" .name) reads from dotdot."
  done
}

# dotdot's former place, after a move: its links there count as dotdot's own,
# so they are relinked (or pruned) rather than left as someone else's.
core.system.link.service::relink_from() {
  guards::stays_inside "$1" && [ -n "${1%/}" ] && [[ "$1" != /* ]] || return 1
  LINK_MANAGED_DIRS+=("$BASE/${1%/}")
}

core.system.link.service::is_managed() {
  local directory
  for directory in "${LINK_MANAGED_DIRS[@]}"; do
    framework.helpers.fs::is_inside "$1" "$directory" && [ "$1" != "$directory" ] && return 0
  done
  return 1
}

# <relative> under <anchor>, its directory resolved but not its last part
# (a link stays a link), into the variable named $3; fails outside <anchor>.
core.system.link.service::resolve_under() {
  local relative="${1%/}" anchor="$2" target="$3" parent name path
  path="$anchor/$relative"
  name="${path##*/}"
  case "$name" in
    '' | . | ..) return 1 ;;
  esac
  framework.helpers.fs::resolve_to parent "${path%/*}" || return 1
  [ "$parent" != / ] || parent=""
  [ "$parent/$name" != "$anchor" ] && framework.helpers.fs::is_inside "$parent/$name" "$anchor" || return 1
  printf -v "$target" '%s' "$parent/$name"
}

core.system.link.service::add() {
  LINK_GROUPS+=("$LINK_GROUP")
  LINK_ORIGINS+=("$1")
  LINK_DESTINATIONS+=("$2")
  LINK_LABELS+=("$3")
  LINK_ACTIONS+=("$4")
}

# What to do with a destination, into LINK_ACTION.
core.system.link.service::classify() {
  local origin="$1" destination="$2" override="$3" target="" source=""
  if [ -L "$destination" ]; then
    framework.helpers.fs::resolve_to target "$destination" || target=""
    framework.helpers.fs::resolve_to source "$origin" || source=""
  fi
  if [ ! -e "$destination" ] && [ ! -L "$destination" ]; then
    LINK_ACTION="link"
  elif [ -L "$destination" ] && [ "$target" = "$source" ]; then
    LINK_ACTION="ok"
  elif [ -L "$destination" ] && core.system.link.service::is_managed "$target"; then
    LINK_ACTION="move"
  elif [ -d "$destination" ] && [ ! -L "$destination" ]; then
    LINK_ACTION="skip"
  elif ! $override; then
    LINK_ACTION="overridable"
  elif [ -L "$destination" ]; then
    LINK_ACTION="relink"
  else
    LINK_ACTION="backup"
  fi
}


core.system.link.service::plan_link() {
  local action
  ! core.system.link.service::is_removed "$2" "$1" || return 0
  if core.system.link.service::planned_origin "$2"; then
    [ "$LINK_PLANNED" != "$1" ] || return 0
    if [ "$LINK_PLANNED_GROUP" = . ] && [ "$LINK_GROUP" != . ]; then
      LINK_NOTICES+=("Skipped ${LINK_GROUP#+}'s link to $3: your own links already link it to $(dot::relative "$LINK_PLANNED").")
    else
      LINK_NOTICES+=("Skipped $(dot::relative "$1") → $3: an earlier entry already links it to $(dot::relative "$LINK_PLANNED").")
    fi
    return
  fi
  core.system.link.service::classify "$1" "$2" "$4"
  action="$LINK_ACTION"
  if [ "$action" = overridable ]; then
    action=skip
    LINK_OVERRIDABLE=$((LINK_OVERRIDABLE + 1))
  fi
  core.system.link.service::add "$1" "$2" "$3" "$action"
}

# The origin already planned for a destination, into LINK_PLANNED, and the
# group it came from into LINK_PLANNED_GROUP.
core.system.link.service::planned_origin() {
  local index
  for index in ${LINK_DESTINATIONS[@]+"${!LINK_DESTINATIONS[@]}"}; do
    if [ "${LINK_DESTINATIONS[$index]}" = "$1" ]; then
      LINK_PLANNED="${LINK_ORIGINS[$index]}"
      LINK_PLANNED_GROUP="${LINK_GROUPS[$index]}"
      return 0
    fi
  done
  return 1
}

core.system.link.service::is_planned() {
  core.system.link.service::planned_origin "$1"
}

core.system.link.service::plan_mapping() {
  local entry="$1" override="$2" origin destination origin_path tree=false origin_absolute destination_absolute child name
  origin="${entry%%"$LINK_SEPARATOR"*}"
  destination="${entry#*"$LINK_SEPARATOR"}"
  origin_path="$origin"
  if framework.helpers.fs::is_contents_pattern "$origin"; then
    tree=true
    origin_path="${origin%"$LINK_TREE_SUFFIX"}"
  fi
  if ! guards::stays_inside "$origin_path" || ! guards::stays_inside "$destination"; then
    core.system.link.service::fail "Skipped $entry: it uses \"..\", which dotdot doesn't follow."
    return
  fi
  core.system.link.service::resolve_under "$origin_path" "$DOTDOT_ROOT" origin_absolute \
    || { core.system.link.service::fail "Skipped $origin_path: it's outside $DOTDOT_NAME/."; return; }
  core.system.link.service::resolve_under "$destination" "$BASE" destination_absolute \
    || { core.system.link.service::fail "Skipped $destination: it's outside the project."; return; }
  guards::link_origin "$origin_absolute" \
    || { core.system.link.service::fail "Skipped $origin_path: it's outside $DOTDOT_NAME/."; return; }
  guards::link_destination "$destination_absolute" \
    || { core.system.link.service::fail "Skipped $destination: it's a protected place ($DOTDOT_NAME/, .git/, the dot entry point, or .env)."; return; }
  if [ ! -e "$origin_absolute" ] && ! { $LINK_SEED_USER && [ "$origin_absolute" = "$USER_FILE" ]; }; then
    core.system.link.service::fail "Skipped $origin_path: it doesn't exist."
    return
  fi
  if $tree && [ ! -d "$origin_absolute" ]; then
    core.system.link.service::fail "Skipped $origin: it ends in $LINK_TREE_SUFFIX but isn't a directory."
    return
  fi
  if $tree && [ -L "$destination_absolute" ]; then
    core.system.link.service::fail "Skipped $destination: it's a link to a directory. Please remove it if dotdot should link there."
    return
  fi
  if ! $tree; then
    core.system.link.service::plan_link "$origin_absolute" "$destination_absolute" "$destination" "$override"
    return
  fi
  LINK_TREE_DIRS+=("$destination_absolute")
  while IFS= read -r -d '' child; do
    name="${child##*/}"
    [ "$name" != "$KEEP_FILE" ] || continue
    core.system.link.service::plan_link "$child" "$destination_absolute/$name" "${destination%/}/$name" "$override"
  done < <(find "$origin_absolute" -mindepth 1 -maxdepth 1 -print0 | sort -z)
}

# How a destination's appended regions are marked: html comments in Markdown,
# none in JSON (which has no comments; it is only created when missing), and
# # everywhere else.
core.system.link.service::marker_style() {
  case "$1" in
    # Markdown, and the Markdown rules files agents read under their own names.
    *.md | .rules | */.rules | *.cursorrules | *.windsurfrules | *.clinerules) printf 'html\n' ;;
    *.json) printf 'none\n' ;;
    *) printf 'hash\n' ;;
  esac
}

# A region's marker: open, close, or new (the open marker of a region that
# created its file, so removing it may delete the file again).
core.system.link.service::marker() {
  local label="$3"
  case "$2" in
    close) label="/$label" ;;
    new) label="$label$LINK_NEW_FILE" ;;
  esac
  case "$1" in
    html) printf '<!-- %s -->\n' "$label" ;;
    *) printf '# %s\n' "$label" ;;
  esac
}

core.system.link.service::has_region() {
  [ -f "$1" ] && grep -qxF -e "$(core.system.link.service::marker "$2" open "$3")" -e "$(core.system.link.service::marker "$2" new "$3")" -- "$1"
}

# An append destination, resolved through its links into the variable named
# $2, that guards::append_destination allows for <owner> ($3).
core.system.link.service::append_destination() {
  local destination="$1" target="$2" owner="$3" link_destination physical
  guards::stays_inside "$destination" \
    && core.system.link.service::resolve_under "$destination" "$BASE" link_destination \
    && [ "$link_destination" != "$ENTRY_LINK" ] \
    && framework.helpers.fs::resolve_to physical "$link_destination" \
    && guards::append_destination "$physical" "$owner" || return 1
  printf -v "$target" '%s' "$physical"
}

# The file an append origin names, into the variable named $2.
core.system.link.service::append_origin() {
  local origin="$1" target="$2" link_origin
  core.system.link.service::shortcut_path "$origin" && ! framework.helpers.fs::is_contents_pattern "$LINK_SHORTCUT" \
    && guards::stays_inside "$LINK_SHORTCUT" \
    && core.system.link.service::resolve_under "$LINK_SHORTCUT" "$DOTDOT_ROOT" link_origin \
    && guards::link_origin "$link_origin" && [ -f "$link_origin" ] || return 1
  printf -v "$target" '%s' "$link_origin"
}

core.system.link.service::add_append() {
  LINK_APPEND_ORIGINS+=("$1")
  LINK_APPEND_PATHS+=("$2")
  LINK_APPEND_LABELS+=("$3")
  LINK_APPEND_MARKERS+=("$4")
  LINK_APPEND_ACTIONS+=("$5")
}

# The origin already planned for <path>'s <label> region, into
# LINK_APPEND_PLANNED (empty for a removal).
core.system.link.service::is_append_planned() {
  local index
  for index in ${LINK_APPEND_PATHS[@]+"${!LINK_APPEND_PATHS[@]}"}; do
    if [ "${LINK_APPEND_PATHS[$index]}" = "$1" ] && [ "${LINK_APPEND_MARKERS[$index]}" = "$2" ]; then
      LINK_APPEND_PLANNED="${LINK_APPEND_ORIGINS[$index]}"
      return 0
    fi
  done
  return 1
}

# Whose region an append writes, the label of its markers: the plugin its
# origin is in, else dotdot.
core.system.link.service::append_label() {
  local plugin
  plugin=$(core.system.link.service::origin_plugin "$1")
  printf '%s\n' "${plugin:-$LINK_DOTDOT_LABEL}"
}

# What to do for one append; a removal takes its region out, quietly when
# there is none. <label> overrides the origin's (a removed plugin's sweep).
core.system.link.service::plan_append() {
  local origin="$1" destination="$2" removal="$3" label="${4-}" path style absolute action module
  destination=$(core.system.link.service::destination_path "$destination")
  [ -n "$label" ] || label=$(core.system.link.service::append_label "$origin")
  if ! core.system.link.service::append_destination "$destination" path "$label"; then
    $removal && return 0
    core.system.link.service::fail "Skipped appending to $destination: appends go to project files (not in .git/, not .env) or to dotdot's top-level docs."
    return
  fi
  style=$(core.system.link.service::marker_style "$path")
  if $removal; then
    ! core.system.link.service::is_append_planned "$path" "$label" || return 0
    [ "$style" != none ] && core.system.link.service::has_region "$path" "$style" "$label" || return 0
    core.system.link.service::add_append "" "$path" "$destination" "$label" unappend
    return
  fi
  if ! core.system.link.service::append_origin "$origin" absolute; then
    if module=$(core.system.link.service::disabled_module_of "$origin"); then
      core.system.link.service::fail "Skipped appending $origin: the feature flag featureFlags.$module turns its module off."
    else
      core.system.link.service::fail "Skipped appending $origin: it isn't a file @dot:, @module:, @harness: or @plugin: names."
    fi
    return
  fi
  if core.system.link.service::is_append_planned "$path" "$label"; then
    [ -z "$LINK_APPEND_PLANNED" ] || [ "$LINK_APPEND_PLANNED" = "$absolute" ] \
      || core.system.link.service::fail "Skipped appending $origin: $label already appends another file to $destination."
    return
  fi
  if [ "$style" = none ]; then
    action=create
    [ ! -e "$path" ] || action=exists
  else
    action=append
    ! core.system.link.service::has_region "$path" "$style" "$label" || action=appended
  fi
  core.system.link.service::add_append "$absolute" "$path" "$destination" "$label" "$action"
}

# Every append, removals first so they win, then what removed plugins
# appended.
core.system.link.service::plan_appends() {
  local group origin destination
  while IFS="$LINK_TAB" read -r _ _ origin destination; do
    core.system.link.service::plan_append "$origin" "$destination" true
  done < <(core.system.link.service::rows remove)
  while IFS="$LINK_TAB" read -r group _ origin destination; do
    ! core.system.link.service::is_denied "$group" append "$origin" "$destination" || { LINK_NOTICES+=("$LINK_DENIAL"); continue; }
    core.system.link.service::plan_append "$origin" "$destination" false
  done < <(core.system.link.service::rows append)
  core.system.link.service::plan_swept_appends
}

core.system.link.service::plan_swept_appends() {
  local entry
  for entry in ${LINK_SWEPT_APPENDS[@]+"${LINK_SWEPT_APPENDS[@]}"}; do
    core.system.link.service::plan_append "" "${entry#*|}" true "${entry%%|*}"
  done
}

core.system.link.service::swept_directories() {
  local destination directory
  {
    for destination in ${LINK_DESTINATIONS[@]+"${LINK_DESTINATIONS[@]}"}; do
      printf '%s\0' "${destination%/*}"
    done
    for directory in ${LINK_TREE_DIRS[@]+"${LINK_TREE_DIRS[@]}"}; do
      printf '%s\0' "$directory"
    done
  } | sort -zu
}

# Prunes dotdot's broken links, and its links into a module a feature flag
# turns off.
core.system.link.service::plan_pruning() {
  local directory link target module off=()
  while IFS= read -r module; do
    framework.helpers.fs::resolve_to directory "$MODULES_DIR/$module" && off+=("$directory")
  done < <(paths::disabled_modules)
  while IFS= read -r -d '' directory; do
    [ -d "$directory" ] && [ ! -L "$directory" ] || continue
    while IFS= read -r -d '' link; do
      [ "$link" != "$ENTRY_LINK" ] || continue
      framework.helpers.fs::resolve_to target "$link" && core.system.link.service::is_managed "$target" || continue
      [ ! -e "$link" ] || core.system.link.service::is_inside_any "$target" ${off[@]+"${off[@]}"} || continue
      ! core.system.link.service::is_planned "$link" || continue
      core.system.link.service::add "" "$link" "$(dot::relative "$link")" prune
    done < <(find "$directory" -mindepth 1 -maxdepth 1 -type l -print0 | sort -z)
  done < <(core.system.link.service::swept_directories)
}

core.system.link.service::plan() {
  local override="$1" refresh="${2-}" entry
  core.system.link.service::prepare_map "$refresh"
  [ -n "$LINK_EFFECTIVE_MAP" ] || return 0
  core.system.link.service::load_denied || { core.system.link.service::fail "plugins.denyLinkOrigin or plugins.denyLinkDestination in $(dot::relative "$SETTINGS_FILE") can't be read, so nothing was linked."; return 0; }
  core.system.link.service::plan_removals
  if [ ! -e "$USER_FILE" ] && [ ! -L "$USER_FILE" ] && [ -f "$USER_EXAMPLE_FILE" ]; then
    LINK_SEED_USER=true
  fi
  while IFS="$LINK_TAB" read -r LINK_GROUP entry; do
    [ "$LINK_GROUP" != "?" ] || { LINK_NOTICES+=("$entry"); continue; }
    case "$entry" in
      '!'*) core.system.link.service::fail "${entry#!}" ;;
      *) core.system.link.service::plan_mapping "$entry" "$override" ;;
    esac
  done < <(core.system.link.service::mappings)
  LINK_GROUP=""
  [ -n "$LINK_ONLY_GROUP" ] || core.system.link.service::plan_pruning
  core.system.link.service::plan_appends
}

# Only what plugins no longer installed leave behind: their entries dropped
# from the links, their broken links removed (those of @pluginsSkills and
# @pluginsAgents too), and what they appended taken out. Nothing without a
# links map, which then holds none of theirs.
core.system.link.service::plan_sweep() {
  local origin destination
  core.system.link.service::has_map || return 0
  core.system.link.service::prepare_map ""
  [ -n "$LINK_EFFECTIVE_MAP" ] || return 0
  while IFS="$LINK_TAB" read -r _ _ origin destination; do
    case "$origin" in
      @pluginsSkills | @pluginsAgents) core.system.link.service::sweep "" link "$origin" "$destination" ;;
    esac
  done < <(core.system.link.service::rows link)
  core.system.link.service::plan_pruning
  core.system.link.service::plan_swept_appends
}

core.system.link.service::is_change() {
  case "$1" in
    link | move | prune | unlink | relink | backup | append | unappend | create) return 0 ;;
  esac
  return 1
}

core.system.link.service::count_changes() {
  local action
  LINK_CHANGES=0
  ! $LINK_SEED_USER || LINK_CHANGES=$((LINK_CHANGES + 1))
  LINK_CHANGES=$((LINK_CHANGES + ${#LINK_MAP_NOTES[@]}))
  for action in ${LINK_ACTIONS[@]+"${LINK_ACTIONS[@]}"} ${LINK_APPEND_ACTIONS[@]+"${LINK_APPEND_ACTIONS[@]}"}; do
    ! core.system.link.service::is_change "$action" || LINK_CHANGES=$((LINK_CHANGES + 1))
  done
}

core.system.link.service::user_state() {
  if $LINK_SEED_USER; then
    printf 'create\n'
  elif [ -e "$USER_FILE" ]; then
    printf 'existing\n'
  fi
}

core.system.link.service::seed() {
  if [ ${#LINK_MAP_NOTES[@]} -gt 0 ]; then
    core.system.link.service::save || core.system.link.service::fail "Couldn't write $(dot::relative "$SETTINGS_FILE"); please check that it's writable."
  fi
  if $LINK_SEED_USER; then
    sed '/^ignore: true$/d' "$USER_EXAMPLE_FILE" > "$USER_FILE" || core.system.link.service::fail "Couldn't create $DOTDOT_NAME/USER.md."
  fi
}

core.system.link.service::apply() {
  local index origin destination label stamp
  stamp=$(framework.helpers.date::stamp)
  core.system.link.service::seed
  for index in ${LINK_ACTIONS[@]+"${!LINK_ACTIONS[@]}"}; do
    origin="${LINK_ORIGINS[$index]}"
    destination="${LINK_DESTINATIONS[$index]}"
    label="${LINK_LABELS[$index]}"
    case "${LINK_ACTIONS[$index]}" in
      ok) LINK_UNCHANGED=$((LINK_UNCHANGED + 1)); continue ;;
      skip) LINK_SKIPPED=$((LINK_SKIPPED + 1)); continue ;;
      prune | unlink)
        if rm -f -- "$destination"; then LINK_REMOVED=$((LINK_REMOVED + 1)); else core.system.link.service::fail "Couldn't remove $label."; fi
        continue
        ;;
      move) rm -f -- "$destination" ;;
      relink)
        LINK_WARNINGS+=("Replaced $label (it pointed to $(readlink -- "$destination")).")
        rm -f -- "$destination"
        ;;
      backup)
        mv -- "$destination" "$destination.bak-$stamp"
        LINK_WARNINGS+=("Backed up $label as $label.bak-$stamp.")
        ;;
    esac
    if framework.helpers.fs::link "$origin" "$destination"; then
      LINK_LINKED=$((LINK_LINKED + 1))
    else
      core.system.link.service::fail "Couldn't link $label. On Windows, symlinks need Developer Mode turned on."
    fi
  done
  core.system.link.service::apply_appends
}

# What an append writes between its markers: the origin as it is, or into
# Markdown under a rule and a heading naming <label>, its frontmatter's
# description quoted below it, then its body.
core.system.link.service::region_body() {
  local origin="$1" path="$2" style="$3" label="$4" description=""
  if [ "$style" != html ]; then
    awk 1 "$origin"
    return
  fi
  printf -- '---\n## %s\n' "$label"
  if framework.helpers.frontmatter::exists "$origin"; then
    description=$(framework.helpers.frontmatter::field "$origin" description)
    [ -z "$description" ] || printf '> description: %s\n' "$description"
    printf '\n'
    framework.helpers.frontmatter::body "$origin" | awk 'NF { started = 1 } started'
  else
    printf '\n'
    awk 'NF { started = 1 } started' "$origin"
  fi
}

# Appends <origin> to <path> between markers; a missing Markdown file gets
# the origin's description as its frontmatter.
core.system.link.service::append() {
  local origin="$1" path="$2" label="$3" style body opening=open
  style=$(core.system.link.service::marker_style "$path")
  mkdir -p -- "${path%/*}" || return 1
  body=$(core.system.link.service::region_body "$origin" "$path" "$style" "$label") || return 1
  if [ ! -e "$path" ]; then
    opening=new
    if [ "$style" = html ] && framework.helpers.frontmatter::exists "$origin"; then
      printf -- '---\nname: %s\ndescription: %s\n---\n' "${path##*/}" "$(framework.helpers.frontmatter::field "$origin" description)" > "$path" || return 1
    fi
  fi
  {
    [ ! -s "$path" ] || [ -z "$(tail -n 1 -- "$path")" ] || printf '\n'
    core.system.link.service::marker "$style" "$opening" "$label"
    [ -z "$body" ] || printf '%s\n' "$body"
    core.system.link.service::marker "$style" close "$label"
  } >> "$path"
}

# Removes an appended region, with the blank lines that set it apart, and the
# file when the region created it and nothing else is left in it.
core.system.link.service::unappend() {
  local path="$1" label="$2" style rest created=false
  style=$(core.system.link.service::marker_style "$path")
  ! grep -qxF -- "$(core.system.link.service::marker "$style" new "$label")" "$path" || created=true
  awk -v open="$(core.system.link.service::marker "$style" open "$label")" -v new="$(core.system.link.service::marker "$style" new "$label")" -v closer="$(core.system.link.service::marker "$style" close "$label")" '
    function flush() { while (blanks > 0) { print ""; blanks-- } }
    !skip && ($0 == open || $0 == new) { skip = 1; blanks = 0; next }
    skip { if ($0 == closer) skip = 0; next }
    /^[ \t]*$/ { blanks++; next }
    { flush(); print }
    END { flush() }
  ' "$path" | framework.helpers.fs::replace "$path" || return 1
  if [ "$style" = html ]; then
    rest=$(framework.helpers.frontmatter::body "$path")
  else
    rest=$(cat -- "$path")
  fi
  ! $created || [ -n "$(printf '%s' "$rest" | tr -d '[:space:]')" ] || rm -f -- "$path"
}

core.system.link.service::apply_appends() {
  local index origin path label marker physical
  for index in ${LINK_APPEND_ACTIONS[@]+"${!LINK_APPEND_ACTIONS[@]}"}; do
    origin="${LINK_APPEND_ORIGINS[$index]}"
    path="${LINK_APPEND_PATHS[$index]}"
    label="${LINK_APPEND_LABELS[$index]}"
    marker="${LINK_APPEND_MARKERS[$index]}"
    # Checked again as written: a link made earlier in this run may now lead
    # the destination somewhere the plan never allowed.
    if ! framework.helpers.fs::resolve_to physical "$path" || [ "$physical" != "$path" ] || ! guards::append_destination "$physical" "$marker"; then
      core.system.link.service::fail "Skipped appending to $label: it changed after the preview (it now leads to $(dot::relative "${physical:-?}"))."
      continue
    fi
    case "${LINK_APPEND_ACTIONS[$index]}" in
      append)
        if core.system.link.service::append "$origin" "$path" "$marker"; then LINK_APPENDED=$((LINK_APPENDED + 1)); else core.system.link.service::fail "Couldn't append to $label."; fi
        ;;
      create)
        if mkdir -p -- "${path%/*}" && cp -- "$origin" "$path"; then LINK_APPENDED=$((LINK_APPENDED + 1)); else core.system.link.service::fail "Couldn't create $label."; fi
        ;;
      unappend)
        if core.system.link.service::unappend "$path" "$marker"; then LINK_UNAPPENDED=$((LINK_UNAPPENDED + 1)); else core.system.link.service::fail "Couldn't take back what was appended to $label."; fi
        ;;
      appended | exists) LINK_UNCHANGED=$((LINK_UNCHANGED + 1)) ;;
    esac
  done
}

# Moves a plugin's group between "inactive" and the active links in
# dot.json, the rest of the file left as written: <to> active places it right
# before "inactive", <to> inactive at the end of "inactive". With <replace>,
# it takes the place of a group already there.
# Where <plugin>'s links are in the links map: active, inactive, both, or none.
core.system.link.service::group_state() {
  local document key active inactive
  document=$(cat -- "$SETTINGS_FILE" 2>/dev/null) || { printf 'none\n'; return; }
  key=$(framework.helpers.json::string "$1")
  active=$(framework.helpers.json::encoded "$document" ".links[$key]")
  inactive=$(framework.helpers.json::encoded "$document" ".links.inactive[$key]")
  case "${active:0:1}${inactive:0:1}" in
    "{{") printf 'both\n' ;;
    "{"*) printf 'active\n' ;;
    *"{") printf 'inactive\n' ;;
    *) printf 'none\n' ;;
  esac
}

core.system.link.service::move_group() {
  local plugin="$1" to="$2" replace="$3" document key from_path to_path group placement=()
  core.system.link.service::has_map || { core.system.link.service::fail "$(dot::relative "$SETTINGS_FILE") has no links yet." "Please run bash dot link first."; return; }
  document=$(cat -- "$SETTINGS_FILE")
  key=$(framework.helpers.json::string "$plugin")
  if [ "$to" = active ]; then
    from_path=".links.inactive[$key]" to_path=".links[$key]" placement=(--before inactive)
  else
    from_path=".links[$key]" to_path=".links.inactive[$key]"
  fi
  group=$(framework.helpers.json::encoded "$document" "$from_path")
  case "$group" in
    "{"*) ;;
    "") core.system.link.service::fail "$(dot::relative "$SETTINGS_FILE") isn't valid JSON. Please fix it and run the command again."; return ;;
    *)
      if [ "$to" = active ]; then
        core.system.link.service::fail "$plugin has no links waiting under \"inactive\"."
      else
        core.system.link.service::fail "$plugin has no active links."
      fi
      return
      ;;
  esac
  if [ "$(framework.helpers.json::encoded "$document" "$to_path")" != null ] && ! $replace; then
    core.system.link.service::fail "$plugin's links are already $to. Please edit them in $(dot::relative "$SETTINGS_FILE"), or add --overwrite to take the new ones."
    return
  fi
  document=$(framework.helpers.json::set "$document" "$to_path" "$(framework.helpers.json::set null . "$group")" --keep-format ${placement[@]+"${placement[@]}"}) \
    && document=$(framework.helpers.json::delete "$document" "$from_path" --keep-format) \
    && printf '%s\n' "$document" | framework.helpers.fs::write "$SETTINGS_FILE" \
    || core.system.link.service::fail "Couldn't write $(dot::relative "$SETTINGS_FILE"); please check that it's writable."
}

# Writes the map alone, for plugin commands: no link, no append.
core.system.link.service::save_map() {
  [ ${#LINK_MAP_NOTES[@]} -gt 0 ] || return 0
  core.system.link.service::save || core.system.link.service::fail "Couldn't write $(dot::relative "$SETTINGS_FILE"); please check that it's writable."
}
