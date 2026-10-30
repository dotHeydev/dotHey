# shellcheck shell=bash

# Agents: dotHey's and the ones it owns (Agents/), in Claude's Markdown
# format, ported to a harness's agents directory. Data: .agents {dir, file,
# port}: port "link" (the default) links them as they are; with a file name
# other than {name}.md, each is linked under that name; port "render" writes
# each through the harness's agents_render <id> <name> <source> instead, and
# owning one of the project's takes it back through agents_import <id> <name>
# <file>. Renaming and rendering are the transform's (harnesses/transform.sh):
# rows only say what goes where.

hey::use core.harnesses.harness

HARNESS_AGENTS_DEFAULT_FILE="{name}.md"

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

# The agent name a file of <id>'s agents directory holds, when dotHey can
# own it: in its format, or in one the harness can import; fails for any
# other.
core.harnesses.capabilities.agents::name_of() {
  local id="$1" file="$2" pattern prefix suffix name
  hey::use "core.harnesses.$id.harness"
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

# import <id> <name> <file>: the agent at <file> in dotHey's format, as it is
# or through the harness's agents_import.
core.harnesses.capabilities.agents::import() {
  hey::use "core.harnesses.$1.harness"
  if [ "$(core.harnesses.capabilities.agents::port "$1")" = render ]; then
    "core.harnesses.$1.harness::agents_import" "$1" "$2" "$3"
  else
    cat -- "$3"
  fi
}

core.harnesses.capabilities.agents::rows() {
  local path
  path=$(core.harnesses.harness::dir "$1" agents)
  [ -n "$path" ] || return 0
  printf 'link\t@dotheyAgents\t%s\n' "$path"
  printf 'link\t@hey:Agents/*\t%s\n' "$path"
}

core.harnesses.capabilities.agents::destinations() {
  core.harnesses.harness::dir "$1" agents
}

core.harnesses.capabilities.agents::scan() {
  local path
  path=$(core.harnesses.harness::dir "$1" agents)
  [ -z "$path" ] || core.harnesses.harness::scan_path agent "$path"
}
