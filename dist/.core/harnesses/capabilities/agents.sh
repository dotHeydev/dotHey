#!/usr/bin/env bash

# Agents: dotdot's and the ones it owns (Agents/), in Claude's Markdown
# format, ported to a harness's agents directory. Data: .agents {dir, file,
# port}: port "link" (the default) links them as they are; with a file name
# other than {name}.md, each is linked under that name; port "render" writes
# each through the harness's agents_render <id> <name> <source> instead, and
# owning one of the project's takes it back through agents_import <id> <name>
# <file>. Renamed and
# rendered agents are built into .harnesses/<id>/agents/ in dotdot, and that
# folder is linked.

dot::use core.harnesses.harness framework.helpers.fs

HARNESS_AGENTS_DEFAULT_FILE="{name}.md"
HARNESS_BUILD_DIR=".harnesses"

# Every agent dotdot has, as "<name>\t<path>": its own, then the ones it owns.
core.harnesses.capabilities.agents::sources() {
  local root file
  {
    while IFS= read -r root; do
      printf '%s\n' "$root"/agents/*.md
    done < <(paths::modules)
    printf '%s\n' "$DOTDOT_ROOT/Agents"/*.md
  } | while IFS= read -r file; do
    [ -f "$file" ] || continue
    file="${file%.md}"
    printf '%s\t%s.md\n' "${file##*/}" "$file"
  done
}

core.harnesses.capabilities.agents::file() {
  local pattern
  pattern=$(core.harnesses.harness::data "$1" .agents.file)
  pattern="${pattern:-$HARNESS_AGENTS_DEFAULT_FILE}"
  printf '%s\n' "${pattern//\{name\}/$2}"
}

# link, rename, or render.
core.harnesses.capabilities.agents::port() {
  local port
  port=$(core.harnesses.harness::data "$1" .agents.port)
  [ "$port" != render ] || { printf 'render\n'; return; }
  [ "$(core.harnesses.capabilities.agents::file "$1" x)" = "x.md" ] && printf 'link\n' || printf 'rename\n'
}

# The agent name a file of <id>'s agents directory holds, when dotdot can
# own it: in its format, or in one the harness can import; fails for any
# other.
core.harnesses.capabilities.agents::name_of() {
  local id="$1" file="$2" pattern prefix suffix name
  dot::use "core.harnesses.$id.harness"
  [ "$(core.harnesses.capabilities.agents::port "$id")" != render ] \
    || declare -F "core.harnesses.$id.harness::agents_import" >/dev/null || return 1
  pattern=$(core.harnesses.capabilities.agents::file "$id" '{name}')
  prefix="${pattern%%\{name\}*}"
  suffix="${pattern#*\{name\}}"
  name="${file#"$prefix"}"
  [ "$name" != "${name%"$suffix"}" ] || return 1
  name="${name%"$suffix"}"
  [ -n "$name" ] && printf '%s\n' "$name"
}

# import <id> <name> <file>: the agent at <file> in dotdot's format, as it is
# or through the harness's agents_import.
core.harnesses.capabilities.agents::import() {
  dot::use "core.harnesses.$1.harness"
  if [ "$(core.harnesses.capabilities.agents::port "$1")" = render ]; then
    "core.harnesses.$1.harness::agents_import" "$1" "$2" "$3"
  else
    cat -- "$3"
  fi
}

core.harnesses.capabilities.agents::build_dir() {
  printf '%s/%s/%s/agents\n' "$DOTDOT_ROOT" "$HARNESS_BUILD_DIR" "$1"
}

core.harnesses.capabilities.agents::rows() {
  local id="$1" path
  path=$(core.harnesses.harness::dir "$id" agents)
  [ -n "$path" ] || return 0
  if [ "$(core.harnesses.capabilities.agents::port "$id")" = link ]; then
    printf 'link\t@dotdotAgents\t%s\n' "$path"
    printf 'link\t@dot:Agents/*\t%s\n' "$path"
  else
    printf 'link\t@dot:%s/%s/agents/*\t%s\n' "$HARNESS_BUILD_DIR" "$id" "$path"
  fi
}

# build <id>: rebuilds .harnesses/<id>/agents/ from every agent, for a
# harness that doesn't read them as they are: each linked under its file
# name, or rendered.
core.harnesses.capabilities.agents::build() {
  local id="$1" port directory name source file
  port=$(core.harnesses.capabilities.agents::port "$id")
  [ "$port" != link ] || return 0
  directory=$(core.harnesses.capabilities.agents::build_dir "$id")
  rm -rf -- "$directory" && mkdir -p -- "$directory" && : > "$directory/$KEEP_FILE" || return 1
  while IFS="$(printf '\t')" read -r name source; do
    file="$directory/$(core.harnesses.capabilities.agents::file "$id" "$name")"
    if [ "$port" = rename ]; then
      ln -s -- "$(framework.helpers.fs::relative "$source" "$directory")" "$file" || return 1
    else
      "core.harnesses.$id.harness::agents_render" "$id" "$name" "$source" > "$file" || return 1
    fi
  done < <(core.harnesses.capabilities.agents::sources)
}

core.harnesses.capabilities.agents::destinations() {
  core.harnesses.harness::dir "$1" agents
}

core.harnesses.capabilities.agents::scan() {
  local path
  path=$(core.harnesses.harness::dir "$1" agents)
  [ -z "$path" ] || core.harnesses.harness::scan_path agent "$path"
}
