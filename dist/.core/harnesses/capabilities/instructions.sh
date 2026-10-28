#!/usr/bin/env bash

# Instructions: dotdot's AGENTS.md where a harness reads instructions. Its
# own instructions file, when the project has one, gets an import of
# AGENTS.md appended in the harness's syntax; else AGENTS.md is linked where
# it reads one. Data: .instructions {link, existing[], imports{}}.

dot::use core.harnesses.harness

# The instructions file of <id>'s that already exists as the project's own
# file, the first one listed.
core.harnesses.capabilities.instructions::existing() {
  local path absolute
  while IFS= read -r path; do
    absolute=$(core.harnesses.harness::project_path "$path") || continue
    [ -f "$absolute" ] && [ ! -L "$absolute" ] && { printf '%s\n' "$path"; return 0; }
  done < <(core.harnesses.harness::data "$1" '.instructions.existing[]')
  return 1
}

core.harnesses.capabilities.instructions::rows() {
  local id="$1" path import
  if path=$(core.harnesses.capabilities.instructions::existing "$id"); then
    import=$(core.harnesses.harness::data "$id" ".instructions.imports.\"$path\"")
    [ -z "$import" ] || printf 'append\t@harness:%s:%s\t%s\n' "$id" "$import" "$path"
  else
    path=$(core.harnesses.harness::data "$id" .instructions.link)
    [ -z "$path" ] || printf 'link\t@dot:AGENTS.md\t%s\n' "$path"
  fi
}

core.harnesses.capabilities.instructions::destinations() {
  core.harnesses.harness::data "$1" .instructions.link
  core.harnesses.harness::data "$1" '.instructions.existing[]'
}

core.harnesses.capabilities.instructions::scan() {
  local path
  while IFS= read -r path; do
    core.harnesses.harness::scan_path instructions "$path"
  done < <(core.harnesses.harness::data "$1" '.instructions.existing[]')
}
