#!/usr/bin/env bash

DESCRIPTION="Scaffold a new plugin repo, ready to fill and publish."

dot::use framework.console.args framework.console.output core.system.plugins.console core.system.plugins.manifest core.system.plugins.service framework.helpers.fs

usage() {
  cat <<USAGE
bash dot plugins:new — scaffold a plugin repo for <owner>/<name>, with one
example of each part to replace with your own. Everything dotdot installs
lives in the repo's $PLUGIN_ROOT/ folder; the rest of the repo is yours.

  $PLUGIN_ROOT/$PLUGIN_MANIFEST   "requires" (the plugin API, $PLUGIN_API), "description", "depends"
                    (binaries or framework.integrations.<name>, reported only),
                    "settings" (its own settings with their defaults, camelCase keys,
                    written into $(dot::relative "$SETTINGS_FILE") under plugins.<owner>/<name> on install,
                    keeping what is there, and read with dot::plugin_setting <key>; dotdot's
                    own with dot::setting; secrets are DOT_<OWNER>_<NAME>__<KEY> in .env,
                    read with dot::secret), and its suggestions,
                    "link" and "append", each {origin: [destinations]}: the origin a
                    plugin path (its own @plugin:<owner>.<name>:<path>), @dot:<Doc>.md,
                    @dotdotSkills, or @dotdotAgents; destinations in the project
                    outside $DOTDOT_NAME/ and .git/ (never .env), appends also @dot:<Doc>.md.
                    Written into the links under "inactive", applied once activated
  $PLUGIN_ROOT/commands/    commands, run as bash dot <owner>:<command>; each declares
                    DESCRIPTION, usage(), and handle()
  $PLUGIN_ROOT/context/     *.md suggested for appending to dotdot's top-level docs
  $PLUGIN_ROOT/skills/, agents/
                    suggested for linking into .agents/skills/
                    and .agents/agents/
  $PLUGIN_ROOT/stubs/       <path>.stub suggested for appending to <path>
                    (context, stubs, skills, agents: each folder only while no "link" or
                    "append" origin lies in it; one that does is placed by plugin.json alone)
  anything else     your code, loaded as plugins.<owner>.<name>.<path>

Code may load dotdot's framework.helpers.*, framework.console.*, and framework.integrations.<name>.service,
plus its own files; nothing else.

Usage:
  bash dot plugins:new <owner>/<name> [--path <directory>]
  bash dot plugins:new --help

The repo goes into <directory> (default: <name> in the project root), which
must not exist yet. Try it with bash dot plugins:add <owner>/<name> --from
./<directory>, then publish it as github.com/<owner>/<name>.
USAGE
}

handle() {
  local plugin="" path="" target
  while [ $# -gt 0 ]; do
    case "$1" in
      --path) framework.console.args::require_value "$@"; path="$2"; shift 2 ;;
      -*) framework.console.args::unexpected "$1" ;;
      *) [ -z "$plugin" ] || framework.console.args::unexpected "$1"; plugin="$1"; shift ;;
    esac
  done
  [ -n "$plugin" ] || framework.console.args::invalid "Which plugin? Please give it as <owner>/<name>."
  plugin=$(core.system.plugins.console::plugin "$plugin")
  target=$(framework.helpers.fs::within "${path:-${plugin#*/}}" "$BASE") || framework.console.output::fail "Plugins are created inside the project; please pick a --path in it."
  [ ! -e "$target" ] || framework.console.output::fail "$(dot::relative "$target") already exists; please pick another --path."
  core.system.plugins.service::scaffold "$plugin" "$target" || framework.console.output::fail "Couldn't create the plugin in $(dot::relative "$target")."
  framework.console.output::success "Created plugin $plugin."
  framework.console.output::detail "$(dot::relative "$target")"
  framework.console.output::next "Try it: bash dot plugins:add $plugin --from ./$(dot::relative "$target")"
}
