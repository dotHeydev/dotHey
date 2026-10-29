#!/usr/bin/env bash

# The shared, data-driven handler behind every harness's interface: what a
# harness is, how it is found, and where it reads dotdot all come from its
# harness.json, so a change to the data needs no change to the code. Rows are
# tab-separated.

dot::use framework.helpers.fs framework.helpers.json

HARNESS_DIR="$CORE_DIR/harnesses"
HARNESS_FILE="harness.json"
HARNESS_INTERFACE="harness.sh"
HARNESS_ID_PATTERN='^[a-z][a-z0-9-]*$'
# What a harness can be given, each a module in capabilities/ with the same
# calls (rows, destinations, scan, and build where something is generated),
# used for every harness whose data declares it.
HARNESS_CAPABILITIES=(instructions skills agents)

# Every harness folder holding the interface and its data, by id.
core.harnesses.harness::ids() {
  local directory id
  for directory in "$HARNESS_DIR"/*/; do
    id="${directory%/}"
    id="${id##*/}"
    [[ "$id" =~ $HARNESS_ID_PATTERN ]] && [ -f "$directory$HARNESS_FILE" ] && [ -f "$directory$HARNESS_INTERFACE" ] || continue
    printf '%s\n' "$id"
  done
}

# Whether <id> is a harness folder.
core.harnesses.harness::exists() {
  [[ "$1" =~ $HARNESS_ID_PATTERN ]] && [ -f "$HARNESS_DIR/$1/$HARNESS_FILE" ] && [ -f "$HARNESS_DIR/$1/$HARNESS_INTERFACE" ]
}

# The variable holding <id>'s data, read once, as json::leaves rows.
core.harnesses.harness::store() {
  printf 'HARNESS_LEAVES_%s\n' "${1//-/_}"
}

# Reads every harness's data once, as the module loads, so lookups run in
# the shell (and the subshells after it) without parsing JSON again.
core.harnesses.harness::load() {
  local id leaves
  while IFS= read -r id; do
    leaves=$(framework.helpers.json::leaves "$(cat -- "$HARNESS_DIR/$id/$HARNESS_FILE")" 2>/dev/null) || leaves=""
    printf -v "$(core.harnesses.harness::store "$id")" '%s' "$leaves"
  done < <(core.harnesses.harness::ids)
}

# The rows of <id>'s data, into HARNESS_ROWS.
core.harnesses.harness::rows_of() {
  local store
  store=$(core.harnesses.harness::store "$1")
  HARNESS_ROWS="${!store-}"
}

# Whether <id>'s harness.json is valid JSON naming the harness.
core.harnesses.harness::valid() {
  core.harnesses.harness::exists "$1" || return 1
  core.harnesses.harness::rows_of "$1"
  [[ $'\n'"$HARNESS_ROWS" == *$'\n'"name"$'\t'?* ]]
}

# What <path> selects in <id>'s data, one value per line: a chain of .key,
# ."key", and [] (each element), as json::values reads it, for scalars only.
core.harnesses.harness::data() {
  local path="$2" steps=() step row value i match
  core.harnesses.harness::valid "$1" || return 1
  while [ -n "$path" ]; do
    case "$path" in
      .\"*)
        path="${path#.\"}"
        steps+=("${path%%\"*}")
        path="${path#*\"}"
        ;;
      \[\]*) steps+=("[]"); path="${path#\[\]}" ;;
      .*)
        path="${path#.}"
        step="${path%%[.[]*}"
        steps+=("$step")
        path="${path#"$step"}"
        ;;
      *) return 1 ;;
    esac
  done
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    IFS=$'\t' read -r -a fields <<< "$row"
    [ "${#fields[@]}" -eq $((${#steps[@]} + 1)) ] || continue
    match=true
    for i in "${!steps[@]}"; do
      if [ "${steps[$i]}" = "[]" ]; then
        [[ "${fields[$i]}" =~ ^[0-9]+$ ]] || { match=false; break; }
      else
        [ "${fields[$i]}" = "${steps[$i]}" ] || { match=false; break; }
      fi
    done
    $match || continue
    value="${fields[${#steps[@]}]}"
    printf '%s\n' "$value"
  done <<< "$HARNESS_ROWS"
}

# Whether <id>'s data has anything under its top-level <key>.
core.harnesses.harness::declares() {
  core.harnesses.harness::valid "$1" || return 1
  [[ $'\n'"$HARNESS_ROWS" == *$'\n'"$2"$'\t'* ]]
}

# Runs <function> of <id>'s interface, its id first, then the rest.
core.harnesses.harness::call() {
  local id="$1" function="$2"
  shift 2
  core.harnesses.harness::exists "$id" || return 1
  dot::use "core.harnesses.$id.harness"
  "core.harnesses.$id.harness::$function" "$id" "$@"
}

# A project path, as a harness names it, made absolute; fails for anything
# outside the project, in .git/, .env, or dotdot.
core.harnesses.harness::project_path() {
  local path="${1%/}"
  [ -n "$path" ] && [[ "$path" != /* ]] && guards::stays_inside "$path" || return 1
  case "/$path/" in
    */.git/* | "/${HOST_ENV_FILE##*/}/" | "/$DOTDOT_NAME/"*) return 1 ;;
  esac
  printf '%s\n' "$BASE/$path"
}

# Whether <path> leads outside the project once its links are followed.
core.harnesses.harness::leaves_project() {
  local physical
  framework.helpers.fs::resolve_to physical "$1" || return 0
  ! framework.helpers.fs::is_inside "$physical" "$BASE"
}

# Whether <path> is dotdot's own: a link into dotdot, or a file link made
# only to hold dotdot's section (its marker says new file).
core.harnesses.harness::is_dotdots() {
  local physical
  if [ -L "$1" ]; then
    framework.helpers.fs::resolve_to physical "$1" && framework.helpers.fs::is_inside "$physical" "$DOTDOT_ROOT"
    return
  fi
  [ -f "$1" ] && grep -qF -- '<!-- dotdot (new file) -->' "$1" 2>/dev/null
}

# Whether <path> is the project's own: a file that isn't dotdot's, an empty
# folder, or a folder holding one of those within <depth> levels (deeper is
# taken as the project's). Folders holding only dotdot's links, or dotdot
# itself, are not.
core.harnesses.harness::holds_own() {
  local path="$1" depth="${2:-3}" entry empty=true
  ! core.harnesses.harness::is_dotdots "$path" && ! framework.helpers.fs::is_inside "$path" "$DOTDOT_ROOT" || return 1
  [ -d "$path" ] && [ ! -L "$path" ] && [ "$depth" -gt 0 ] || return 0
  for entry in "$path"/* "$path"/.[!.]*; do
    [ -e "$entry" ] || [ -L "$entry" ] || continue
    empty=false
    core.harnesses.harness::holds_own "$entry" $((depth - 1)) && return 0
  done
  $empty
}

# detect <id>: whether any of its detection paths holds something of the
# project's own. Detection paths are the harness's alone: never a place
# other harnesses read too, like AGENTS.md or .agents/skills/.
core.harnesses.harness::detect() {
  local path absolute
  while IFS= read -r path; do
    absolute=$(core.harnesses.harness::project_path "$path") || continue
    [ -e "$absolute" ] && core.harnesses.harness::holds_own "$absolute" && return 0
  done < <(core.harnesses.harness::data "$1" '.detect[]')
  return 1
}

# The size of <path> in bytes: a file's, or the files' inside a directory.
core.harnesses.harness::size() {
  if [ -d "$1" ]; then
    find "$1" -type f -exec cat {} + 2>/dev/null | wc -c | tr -d ' '
  else
    wc -c < "$1" | tr -d ' '
  fi
}

# "<kind>\t<path>\t<size>" for <path> (a file) or each entry in it (a
# directory, ending in /), the project's own only: never dotdot's links, nor
# anything a link leads outside the project.
core.harnesses.harness::scan_path() {
  local kind="$1" path="$2" absolute entry
  absolute=$(core.harnesses.harness::project_path "$path") || return 0
  [ -e "$absolute" ] && ! core.harnesses.harness::leaves_project "$absolute" || return 0
  core.harnesses.harness::is_dotdots "$absolute" && return 0
  if [ "${path%/}" = "$path" ]; then
    [ -f "$absolute" ] && printf '%s\t%s\t%s\n' "$kind" "${path}" "$(core.harnesses.harness::size "$absolute")"
    return 0
  fi
  [ -d "$absolute" ] || return 0
  for entry in "$absolute"/*; do
    [ -e "$entry" ] || [ -L "$entry" ] || continue
    core.harnesses.harness::is_dotdots "$entry" && continue
    if core.harnesses.harness::leaves_project "$entry"; then
      printf '%s\t%s\t0\n' "$kind" "${path%/}/${entry##*/}"
    else
      printf '%s\t%s\t%s\n' "$kind" "${path%/}/${entry##*/}" "$(core.harnesses.harness::size "$entry")"
    fi
  done
}

# The capabilities <id>'s data declares.
core.harnesses.harness::capabilities() {
  local capability
  for capability in "${HARNESS_CAPABILITIES[@]}"; do
    ! core.harnesses.harness::declares "$1" "$capability" || printf '%s\n' "$capability"
  done
  return 0
}

# Runs <call> of each capability <id> declares, with <id>.
core.harnesses.harness::each() {
  local id="$1" call="$2" capability
  while IFS= read -r capability; do
    dot::use "core.harnesses.capabilities.$capability"
    ! declare -F "core.harnesses.capabilities.$capability::$call" >/dev/null \
      || "core.harnesses.capabilities.$capability::$call" "$id" || return 1
  done < <(core.harnesses.harness::capabilities "$id")
}

# The directory of <capability> in <id>'s data: its "dir", or the value itself.
core.harnesses.harness::dir() {
  local value
  value=$(core.harnesses.harness::data "$1" ".$2.dir")
  [ -n "$value" ] || value=$(core.harnesses.harness::data "$1" ".$2")
  [ -z "$value" ] || printf '%s\n' "$value"
}

# scan <id>: what the project already holds for it, as scan_path rows: each
# capability's places, then its other context.
core.harnesses.harness::scan() {
  local id="$1" path kind
  core.harnesses.harness::each "$id" scan
  while IFS= read -r kind; do
    while IFS= read -r path; do
      core.harnesses.harness::scan_path "$kind" "$path"
    done < <(core.harnesses.harness::data "$id" ".context.\"$kind\"[]")
  done < <(core.harnesses.harness::valid "$id" && printf '%s\n' "$HARNESS_ROWS" | awk -F '\t' '$1 == "context" && NF == 4 && !seen[$2]++ { print $2 }')
}

# rows <id>: "<link|append>\t<origin>\t<destination>" for the links map,
# from each capability.
core.harnesses.harness::rows() {
  core.harnesses.harness::each "$1" rows
}

# destinations <id>: every place it may link or append to.
core.harnesses.harness::destinations() {
  core.harnesses.harness::each "$1" destinations
}

# build <id>: generates what its capabilities link from dotdot (renamed or
# rendered files), before linking.
core.harnesses.harness::build() {
  core.harnesses.harness::each "$1" build
}

core.harnesses.harness::load
