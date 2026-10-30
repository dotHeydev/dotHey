#!/usr/bin/env bash

# Transforms: what a harness reads in another format than dotdot's. A format
# belongs to the folder a harness reads, not to the harness: every harness's
# .agents data gives its folder one (as they are, renamed, or rendered), so
# whatever links agents into that folder gets them in its format, whoever
# wrote the row. Built files go to .harnesses/<id>/agents/ in dotdot, which
# link links from. Rows are tab-separated.

dot::use core.harnesses.harness core.harnesses.capabilities.agents framework.helpers.fs

TRANSFORM_BUILD_DIR=".harnesses"
TRANSFORM_TAB=$'\t'
# "<folder>\t<id>" for each folder read in a format other than dotdot's, and
# "<folder>\t<ids>" for each folder harnesses give different formats.
TRANSFORM_FOLDERS=""
TRANSFORM_CONFLICTS=""
# The build files this run uses, dotdot-relative, space-separated.
TRANSFORM_KEPT=" "
TRANSFORM_HARNESS=""
TRANSFORM_CLAIMS=""

# A harness's agents format: its port and file name pattern.
core.harnesses.transform::format() {
  printf '%s %s\n' "$(core.harnesses.capabilities.agents::port "$1")" "$(core.harnesses.capabilities.agents::file "$1" '{name}')"
}

# Reads every harness's agents folder once, into TRANSFORM_FOLDERS and
# TRANSFORM_CONFLICTS.
core.harnesses.transform::load() {
  local id folder rows=""
  while IFS= read -r id; do
    core.harnesses.harness::valid "$id" || continue
    folder=$(core.harnesses.harness::dir "$id" agents) || continue
    [ -n "$folder" ] || continue
    rows="$rows${folder%/}$TRANSFORM_TAB$id$TRANSFORM_TAB$(core.harnesses.transform::format "$id")"$'\n'
  done < <(core.harnesses.harness::ids)
  TRANSFORM_FOLDERS=$(printf '%s' "$rows" | awk -F '\t' -v OFS='\t' '
    { if (!($1 in format)) { format[$1] = $3; owner[$1] = $2; order[++n] = $1 } else if (format[$1] != $3) conflict[$1] = 1 }
    END { for (i = 1; i <= n; i++) if (!(order[i] in conflict) && format[order[i]] !~ /^link /) print order[i], owner[order[i]] }')
  TRANSFORM_CONFLICTS=$(printf '%s' "$rows" | awk -F '\t' -v OFS='\t' '
    { if (!($1 in format)) { format[$1] = $3; ids[$1] = $2; order[++n] = $1 } else { if (format[$1] != $3) conflict[$1] = 1; ids[$1] = ids[$1] ", " $2 } }
    END { for (i = 1; i <= n; i++) if (order[i] in conflict) print order[i], ids[order[i]] }')
}

# The harness whose format <folder> (a project path) is read in, into
# TRANSFORM_HARNESS: status 1 when it's read as dotdot writes it, 2 when
# harnesses give it different formats (their ids into TRANSFORM_CLAIMS).
core.harnesses.transform::harness_of() {
  local folder="${1%/}" row
  while IFS= read -r row; do
    [ "${row%%"$TRANSFORM_TAB"*}" != "$folder" ] || { TRANSFORM_CLAIMS="${row#*"$TRANSFORM_TAB"}"; return 2; }
  done <<< "$TRANSFORM_CONFLICTS"
  while IFS= read -r row; do
    [ "${row%%"$TRANSFORM_TAB"*}" != "$folder" ] || { TRANSFORM_HARNESS="${row#*"$TRANSFORM_TAB"}"; return 0; }
  done <<< "$TRANSFORM_FOLDERS"
  return 1
}

# Whether <path> (dotdot-relative) is an agent: a Markdown file in an agents/
# or Agents/ folder.
core.harnesses.transform::is_agent() {
  case "$1" in
    *.md) ;;
    *) return 1 ;;
  esac
  case "${1%/*}" in
    agents | */agents | Agents | */Agents) return 0 ;;
  esac
  return 1
}

# The build file, dotdot-relative, of agent <name> for harness <id>.
core.harnesses.transform::built() {
  printf '%s/%s/agents/%s\n' "$TRANSFORM_BUILD_DIR" "$1" "$(core.harnesses.capabilities.agents::file "$1" "$2")"
}

# Writes the build file <built> (dotdot-relative) of agent <name> at <source>
# (dotdot-relative) for harness <id>: renamed, a link to it; rendered, the
# harness's agents_render. A failure leaves the previous build in place.
core.harnesses.transform::build() {
  local id="$1" name="$2" source="$DOTDOT_ROOT/$3" file="$DOTDOT_ROOT/$4" partial
  partial="$file.dot-build-$$"
  mkdir -p -- "${file%/*}" || return 1
  if [ "$(core.harnesses.capabilities.agents::port "$id")" = rename ]; then
    ln -s -- "$(framework.helpers.fs::relative "$source" "${file%/*}")" "$partial"
  else
    dot::use "core.harnesses.$id.harness"
    "core.harnesses.$id.harness::agents_render" "$id" "$name" "$source" > "$partial"
  fi && mv -f -- "$partial" "$file" && return 0
  rm -f -- "$partial"
  return 1
}

# Marks <built> (dotdot-relative) as used by this run, so clean keeps it.
core.harnesses.transform::keep() {
  [[ "$TRANSFORM_KEPT" == *" $1 "* ]] || TRANSFORM_KEPT="$TRANSFORM_KEPT$1 "
}

core.harnesses.transform::is_kept() {
  [[ "$TRANSFORM_KEPT" == *" $1 "* ]]
}

# Deletes every build file this run didn't use, and the folders left empty.
core.harnesses.transform::clean() {
  local file relative
  [ -d "$DOTDOT_ROOT/$TRANSFORM_BUILD_DIR" ] || return 0
  while IFS= read -r -d '' file; do
    relative="${file#"$DOTDOT_ROOT"/}"
    core.harnesses.transform::is_kept "$relative" || rm -f -- "$file" || return 1
  done < <(find "$DOTDOT_ROOT/$TRANSFORM_BUILD_DIR" \( -type f -o -type l \) -print0)
  find "$DOTDOT_ROOT/$TRANSFORM_BUILD_DIR" -depth -type d -exec rmdir -- {} \; 2>/dev/null || true
}

core.harnesses.transform::load
