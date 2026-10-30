# shellcheck shell=bash

# Skills: dotHey's and the ones it owns (Skills/), linked as they are into a
# harness's skills directory. Data: .skills, the directory.

hey::use core.harnesses.harness

core.harnesses.capabilities.skills::rows() {
  local path
  path=$(core.harnesses.harness::dir "$1" skills)
  [ -n "$path" ] || return 0
  printf 'link\t@dotheySkills\t%s\n' "$path"
  printf 'link\t@hey:Skills/*\t%s\n' "$path"
}

core.harnesses.capabilities.skills::destinations() {
  core.harnesses.harness::dir "$1" skills
}

core.harnesses.capabilities.skills::scan() {
  local path
  path=$(core.harnesses.harness::dir "$1" skills)
  [ -z "$path" ] || core.harnesses.harness::scan_path skill "$path"
}
