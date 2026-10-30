# shellcheck shell=bash

# dotHey's guards: the policy every action dotHey takes is checked against.
# Each is a predicate (0 allowed, 1 refused) that never prints, prompts, or
# exits; callers say why. Loaded right after paths.sh and sealed read-only at
# boot with the rest of the runtime, so no plugin or edited file can switch one
# off during a run.

GUARDS_DOCUMENT_PATTERN='^[A-Za-z0-9][A-Za-z0-9._-]*\.md$'
GUARDS_SEGMENT_PATTERN='^[a-z0-9][a-z0-9-]*$'
GUARDS_OWNER_PATTERN='^[a-z0-9]([a-z0-9]|-[a-z0-9])*$'
GUARDS_REPOSITORY_PATTERN='^[a-z0-9._-]+$'
GUARDS_SETTING_PATTERN='^[a-z][A-Za-z0-9]*(\.[a-z][A-Za-z0-9]*)*$'
# The .env keys dotHey reserves for secrets: HEY_GH_TOKEN, each
# HEY_RELEASE_TOKEN_<REMOTE>, and each plugin's HEY_<OWNER>_<NAME>__<KEY>.
GUARDS_RESERVED_ENV_PATTERN='^HEY_(GH_TOKEN|RELEASE_TOKEN_[A-Z0-9_]+|[A-Z0-9_]+__[A-Z0-9_]+)$'
GUARDS_ENV_KEY_PATTERN='^[A-Za-z_][A-Za-z0-9_]*$'
# The settings only hey.json holds, each with all it contains: no "@env:"
# reference may stand for them or anything in them.
GUARDS_JSON_ONLY_SETTINGS=" links state "
GUARDS_DOTHEY="dothey"

guards::is_inside() {
  case "$1/" in
    "$2"/*) return 0 ;;
  esac
  return 1
}

# A relative path that never climbs out with "..".
guards::stays_inside() {
  case "/$1/" in
    */../*) return 1 ;;
  esac
}

# <owner>/<name>, each lowercase letters, digits, and -.
# A plugin's name, its GitHub <owner>/<repository> in lowercase: an owner of
# letters, digits, and single inner hyphens; a repository of letters, digits,
# ., _, and -, never . or .. alone.
guards::plugin_name() {
  local owner="${1%%/*}" name="${1#*/}"
  [ "$owner" != "$1" ] && [[ "$owner" =~ $GUARDS_OWNER_PATTERN ]] && [[ "$name" =~ $GUARDS_REPOSITORY_PATTERN ]] \
    && [ "$name" != . ] && [ "$name" != .. ]
}

# A plugin's key, <owner>/<directory>: the folder it lives in under .plugins/,
# and the part of its module names, link origins, and .env prefix.
guards::plugin_id() {
  local owner="${1%%/*}" name="${1#*/}"
  [ "$owner" != "$1" ] && [[ "$owner" =~ $GUARDS_SEGMENT_PATTERN ]] && [[ "$name" =~ $GUARDS_SEGMENT_PATTERN ]]
}

guards::document() {
  [[ "$1" =~ $GUARDS_DOCUMENT_PATTERN ]]
}

# A settings path: camelCase keys joined by dots, e.g. tasks.githubRepo.
guards::setting() {
  [[ "$1" =~ $GUARDS_SETTING_PATTERN ]]
}

# A setting an "@env:" reference may stand for: any outside those only JSON holds.
guards::env_setting() {
  local setting
  for setting in $GUARDS_JSON_ONLY_SETTINGS; do
    case "$1" in
      "$setting" | "$setting".*) return 1 ;;
    esac
  done
}

guards::env_key() {
  [[ "$1" =~ $GUARDS_ENV_KEY_PATTERN ]]
}

# A .env key dotHey reserves for a secret, which no setting may refer to.
guards::reserved_env_key() {
  [[ "$1" =~ $GUARDS_RESERVED_ENV_PATTERN ]]
}

# A secret's name in .env: one of the keys dotHey reserves.
guards::secret() {
  guards::reserved_env_key "$1"
}

# A secret <owner>/<name> may read or write: one carrying its .env prefix.
guards::plugin_secret() {
  local prefix
  guards::secret "$2" || return 1
  prefix=$(hey::env_prefix "$1")
  [ "${2#"$prefix"}" != "$2" ]
}

# Whether the host project's .env may hold a secret: git-ignored wherever
# the project is a git work tree, so a secret is never one commit away.
guards::secrets_file() {
  git -C "$BASE" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  git -C "$BASE" check-ignore -q -- "$HOST_ENV_FILE"
}

# What may be linked or appended out: anything inside dotHey.
guards::link_origin() {
  guards::is_inside "$1" "$DOTHEY_ROOT" && [ "$1" != "$DOTHEY_ROOT" ]
}

# An origin a plugin's plugin.json may declare, written as there: a path in
# the plugin, the plugin's own @plugin:<owner>.<name>:<path>, one of dotHey's
# top-level docs as @hey:<Doc>.md, or dotHey's own skills or agents.
guards::plugin_origin() {
  local origin="$1" plugin="$2"
  case "$origin" in
    @dotheySkills | @dotheyAgents) return 0 ;;
    @hey:*) guards::document "${origin#@hey:}" ;;
    "@plugin:${plugin/\//.}:"*) guards::plugin_path "${origin#"@plugin:${plugin/\//.}:"}" ;;
    @*) return 1 ;;
    *) guards::plugin_path "$origin" ;;
  esac
}

# Where a link may land: inside the project, outside dotHey and git's own
# files, never the hey entry point or the project's .env.
guards::link_destination() {
  guards::is_inside "$1" "$BASE" && [ "$1" != "$BASE" ] || return 1
  case "/${1#"$BASE"/}/" in
    */.git/*) return 1 ;;
  esac
  [ "$1" != "$ENTRY_LINK" ] && [ "$1" != "$HOST_ENV_FILE" ] && ! guards::is_inside "$1" "$DOTHEY_ROOT"
}

# Where <owner>/<name> (or dotHey) may append, given the file's resolved path:
# a project file outside git's own files, never the entry point, the
# project's .env, or a directory; inside dotHey only a top-level doc.
guards::append_destination() {
  local path="$1"
  guards::is_inside "$path" "$BASE" && [ "$path" != "$BASE" ] || return 1
  case "/${path#"$BASE"/}/" in
    */.git/*) return 1 ;;
  esac
  [ "$path" != "$ENTRY_LINK" ] && [ "$path" != "$HOST_ENV_FILE" ] && [ ! -d "$path" ] || return 1
  guards::is_inside "$path" "$DOTHEY_ROOT" || return 0
  [ "${path%/*}" = "$DOTHEY_ROOT" ] && guards::document "${path##*/}"
}

# Whether <path> is one the user protects: one an entry of the list on stdin
# takes, read as framework.helpers.fs::pattern_matches reads a pattern (its
# callers load framework.helpers.fs).
guards::denied() {
  local path="$1" entry
  while IFS= read -r entry; do
    [ -z "$entry" ] || ! framework.helpers.fs::pattern_matches "$path" "$entry" || return 0
  done
  return 1
}

# A path a plugin's plugin.json names inside the plugin.
guards::plugin_path() {
  case "/$1/" in
    //* | */../*) return 1 ;;
  esac
}

# A project path a plugin may suggest linking to: relative, never climbing
# out, never inside dotHey or .git, never the hey entry point or the .env.
guards::plugin_destination() {
  case "/$1/" in
    //* | */../* | */./* | */.git/* | "/$DOTHEY_NAME/"* | "/${ENTRY_LINK##*/}/" | "/${HOST_ENV_FILE##*/}/") return 1 ;;
  esac
}

# A project path a plugin may suggest appending to: as for a link, or one of
# dotHey's top-level docs.
guards::plugin_append_destination() {
  case "$1" in
    "$DOTHEY_NAME"/*) guards::document "${1#"$DOTHEY_NAME"/}" ;;
    *) guards::plugin_destination "$1" ;;
  esac
}

# A plugin archive whose members all stay inside where it is unpacked.
guards::archive() {
  local member
  while IFS= read -r member; do
    case "/$member/" in
      //* | */../*) return 1 ;;
    esac
  done < <(tar -tzf "$1" 2>/dev/null || printf '/\n')
}

# Whether -y may apply changes unseen: only with a person at a terminal, or
# when dotHey itself (hey::call outside a plugin, the installer) made this call.
guards::skip_confirmation() {
  { [ -t 0 ] && ! guards::is_unattended; } || $HEY_INTERNAL
}

# Whether no person is there to answer: an AI agent, --no-input, or CI.
guards::is_unattended() {
  [ -n "${AI_AGENT-}" ] || [ "${CLAUDECODE-}" = 1 ] || [ "${HEY_NO_INPUT-}" = 1 ]
}
