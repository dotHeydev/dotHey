# shellcheck shell=bash

hey::use core.system.plugins.manifest framework.helpers.fs framework.helpers.kv framework.integrations.github.service

PLUGIN_STUB_DIR="$SYSTEM_DIR/plugins/stubs/plugin"
PLUGIN_STUB_OWNER="__OWNER__"
PLUGIN_STUB_NAME="__NAME__"
PLUGIN_STUB_API="__API__"
PLUGIN_PATH_SOURCE="path:"
PLUGIN_GITHUB_SOURCE="github:"
PLUGIN_DEFAULT_REF="main"
PLUGIN_LOCAL_REF="-"
PLUGINS_WORKSPACE=""

core.system.plugins.service::prepare_workspace() {
  [ -n "${PLUGINS_WORKSPACE-}" ] || framework.helpers.fs::make_temp_dir PLUGINS_WORKSPACE || hey::abort "Couldn't create a temporary directory; please check free space and \$TMPDIR."
  rm -rf -- "${PLUGINS_WORKSPACE:?}"/*
}

core.system.plugins.service::download() {
  local repository="$1" ref="$2" file="$3"
  framework.integrations.github.service::download "$repository" "$ref" "$file"
}

core.system.plugins.service::plugin_root() {
  local repository_root="$1" plugin="$2"
  [ -d "$repository_root/$PLUGIN_ROOT" ] || { hey::raise "$plugin isn't a dotHey plugin: it has no $PLUGIN_ROOT/ directory."; return 1; }
  printf '%s\n' "$repository_root/$PLUGIN_ROOT"
}

core.system.plugins.service::fetch_github() {
  local plugin="$1" ref="$2" repository="${3:-$1}" top
  framework.integrations.github.service::is_ref "$ref" || { hey::raise "\"$ref\" isn't a valid branch, tag or commit."; return 1; }
  core.system.plugins.service::download "$repository" "$ref" "$PLUGINS_WORKSPACE/plugin.tar.gz" || return 1
  mkdir -p -- "$PLUGINS_WORKSPACE/tree"
  guards::archive "$PLUGINS_WORKSPACE/plugin.tar.gz" || { hey::raise "$plugin@$ref contains paths outside its own directory, so it wasn't installed."; return 1; }
  tar -xzf "$PLUGINS_WORKSPACE/plugin.tar.gz" -C "$PLUGINS_WORKSPACE/tree" || { hey::raise "Couldn't unpack $plugin@$ref."; return 1; }
  top=$(find "$PLUGINS_WORKSPACE/tree" -mindepth 1 -maxdepth 1 -type d | head -n 1)
  [ -n "$top" ] || { hey::raise "$plugin@$ref is empty."; return 1; }
  PLUGIN_SOURCE=$(core.system.plugins.service::plugin_root "$top" "$plugin") || return 1
  PLUGIN_COMMIT=$(framework.integrations.github.service::tarball_commit "$PLUGINS_WORKSPACE/plugin.tar.gz")
  PLUGIN_ORIGIN="$PLUGIN_GITHUB_SOURCE$repository"
  PLUGIN_REF="$ref"
}

# Whether <directory> is the top of a git repo of its own (not a folder of the
# project's repo).
core.system.plugins.service::is_repository() {
  local top
  top=$(git -C "$1" rev-parse --show-toplevel 2>/dev/null) && [ "$(cd -- "$top" && pwd -P)" = "$(cd -- "$1" && pwd -P)" ]
}

# A local plugin: a repo of its own is taken as GitHub's is, its dothey/
# folder at <ref> (its current branch by default) as committed, with the
# commit recorded; any other folder as it is on disk, with no ref or commit.
core.system.plugins.service::fetch_path() {
  local plugin="$1" path="$2" ref="$3" root
  root=$(framework.helpers.fs::within "$path" "$BASE") || { hey::raise "--from must be a directory inside the project (got $path)."; return 1; }
  [ -d "$root" ] || { hey::raise "--from must be a directory inside the project (got $path)."; return 1; }
  PLUGIN_ORIGIN="$PLUGIN_PATH_SOURCE$(hey::relative "$root")"
  if ! core.system.plugins.service::is_repository "$root"; then
    [ -z "$ref" ] || { hey::raise "$path isn't a git repo of its own, so @$ref can't apply."; return 1; }
    PLUGIN_SOURCE=$(core.system.plugins.service::plugin_root "$root" "$plugin") || return 1
    PLUGIN_COMMIT="$PLUGIN_LOCAL_REF"
    PLUGIN_REF="$PLUGIN_LOCAL_REF"
    return 0
  fi
  [ -n "$ref" ] || ref=$(git -C "$root" symbolic-ref -q --short HEAD) || ref=$(git -C "$root" rev-parse HEAD) || return 1
  framework.integrations.github.service::is_ref "$ref" || { hey::raise "\"$ref\" isn't a valid branch, tag or commit."; return 1; }
  PLUGIN_COMMIT=$(git -C "$root" rev-parse -q --verify "$ref^{commit}") || { hey::raise "$path has no $ref."; return 1; }
  mkdir -p -- "$PLUGINS_WORKSPACE/tree"
  git -C "$root" archive --format=tar "$PLUGIN_COMMIT" -- "$PLUGIN_ROOT" 2>/dev/null | tar -x -C "$PLUGINS_WORKSPACE/tree" \
    || { hey::raise "$plugin isn't a dotHey plugin: it has no $PLUGIN_ROOT/ directory at $ref."; return 1; }
  PLUGIN_SOURCE=$(core.system.plugins.service::plugin_root "$PLUGINS_WORKSPACE/tree" "$plugin") || return 1
  PLUGIN_REF="$ref"
}

core.system.plugins.service::fetch() {
  local plugin="$1" ref="$2" path="${3-}" repository="${4:-$1}"
  core.system.plugins.service::prepare_workspace
  if [ -n "$path" ]; then
    core.system.plugins.service::fetch_path "$plugin" "$path" "$ref"
  else
    core.system.plugins.service::fetch_github "$plugin" "${ref:-$PLUGIN_DEFAULT_REF}" "$repository"
  fi
}

core.system.plugins.service::files() {
  (cd -- "$1" && find . -type f | sed 's|^\./||' | sort)
}

core.system.plugins.service::changed_files() {
  local plugin="$1" source="$2" installed file
  installed=$(core.system.plugins.manifest::directory "$plugin")
  while IFS= read -r file; do
    if [ ! -e "$installed/$file" ]; then
      printf 'added\t%s\n' "$file"
    elif ! cmp -s -- "$source/$file" "$installed/$file"; then
      printf 'changed\t%s\n' "$file"
    fi
  done < <(core.system.plugins.service::files "$source")
  [ -d "$installed" ] || return 0
  while IFS= read -r file; do
    [ -e "$source/$file" ] || printf 'removed\t%s\n' "$file"
  done < <(core.system.plugins.service::files "$installed")
}

core.system.plugins.service::preview() {
  local plugin="$1" source="$2" state entry
  while IFS=$'\t' read -r state entry; do
    printf 'file\t%s\t%s\n' "$entry" "$state"
  done < <(core.system.plugins.service::changed_files "$plugin" "$source")
  while IFS= read -r entry; do
    printf 'missing\t%s\n' "$entry"
  done < <(core.system.plugins.manifest::missing_dependencies "$source")
}

core.system.plugins.service::install() {
  local plugin="$1" source="$2" destination
  destination=$(core.system.plugins.manifest::directory "$plugin")
  rm -rf -- "$destination"
  mkdir -p -- "$destination"
  (cd -- "$source" && tar -cf - .) | (cd -- "$destination" && tar -xf -) \
    || { hey::raise "Couldn't copy $plugin into $(hey::relative "$destination")."; return 1; }
}

# Writes a plugin's plugin.json settings into hey.json under
# plugins.<owner>/<name>, each key it lacks with its default; a key already
# there, set by the user, stays as it is. Prints the keys added.
core.system.plugins.service::register_settings() {
  local plugin="$1" defaults document key path
  defaults=$(framework.helpers.json::encoded "$(core.system.plugins.manifest::document "$(core.system.plugins.manifest::directory "$plugin")")" ".$PLUGIN_SETTINGS_KEY")
  case "$defaults" in
    "{"*) ;;
    *) return 0 ;;
  esac
  document="{}"
  [ ! -f "$SETTINGS_FILE" ] || document=$(cat -- "$SETTINGS_FILE")
  while IFS= read -r key; do
    path=".plugins[$(framework.helpers.json::string "$plugin")][$(framework.helpers.json::string "$key")]"
    [ "$(framework.helpers.json::encoded "$document" "$path")" = null ] || continue
    document=$(framework.helpers.json::set "$document" "$path" "$(framework.helpers.json::encoded "$defaults" ".[$(framework.helpers.json::string "$key")]")" --keep-format) \
      || { hey::raise "Couldn't add $plugin's settings to $(hey::relative "$SETTINGS_FILE")."; return 1; }
    printf '%s\n' "$key"
  done < <(framework.helpers.json::keys "$defaults" .)
  printf '%s\n' "$document" | framework.helpers.fs::write "$SETTINGS_FILE"
}

# Removes <plugin>'s folder and its settings in hey.json; its secrets in .env
# are listed as left for the user, never removed.
core.system.plugins.service::uninstall() {
  local plugin="$1" directory document path prefix
  directory=$(core.system.plugins.manifest::directory "$plugin")
  prefix=$(hey::env_prefix "$(hey::plugin_key "$plugin")")
  ! framework.helpers.kv::keys "$HOST_ENV_FILE" | grep "^$prefix" >/dev/null \
    || printf 'left\t%s\t%s\n' "$(hey::relative "$HOST_ENV_FILE")" "$prefix* secrets"
  path=".plugins[$(framework.helpers.json::string "$plugin")]"
  if [ -f "$SETTINGS_FILE" ] && [ "$(framework.helpers.json::encoded "$(cat -- "$SETTINGS_FILE")" "$path")" != null ]; then
    document=$(framework.helpers.json::delete "$(cat -- "$SETTINGS_FILE")" "$path" --keep-format) \
      && printf '%s\n' "$document" | framework.helpers.fs::write "$SETTINGS_FILE" \
      || printf 'left\t%s\t%s\n' "$(hey::relative "$SETTINGS_FILE")" "plugins[\"$plugin\"] settings"
  fi
  rm -rf -- "${directory:?}"
  rmdir -- "$(dirname -- "$directory")" 2>/dev/null || true
}

core.system.plugins.service::scaffold() {
  local plugin="$1" directory="$2" path file owner name
  owner=$(core.system.plugins.manifest::owner "$plugin")
  name="${plugin#*/}"
  mkdir -p -- "$directory" && cp -R -- "$PLUGIN_STUB_DIR" "$directory/$PLUGIN_ROOT" || return 1
  while IFS= read -r path; do
    mv -- "$path" "$(dirname -- "$path")/$(basename -- "$path" | sed "s/$PLUGIN_STUB_OWNER/$owner/g; s/$PLUGIN_STUB_NAME/$name/g")"
  done < <(find "$directory" -depth \( -name "*$PLUGIN_STUB_OWNER*" -o -name "*$PLUGIN_STUB_NAME*" \))
  while IFS= read -r file; do
    sed "s/$PLUGIN_STUB_OWNER/$owner/g; s/$PLUGIN_STUB_NAME/$name/g; s/$PLUGIN_STUB_API/$PLUGIN_API/g" "$file" | framework.helpers.fs::replace "$file"
  done < <(find "$directory" -type f)
}
