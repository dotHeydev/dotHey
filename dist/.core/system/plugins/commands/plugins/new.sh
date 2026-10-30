# shellcheck shell=bash

DESCRIPTION="Create a new plugin repo to build on."
DOCS="using-plugins"

dot::use framework.console.args framework.console.output core.system.plugins.console core.system.plugins.manifest core.system.plugins.service framework.helpers.fs

usage() {
  cat <<USAGE
Creates a plugin repo with one example of each part, ready to fill and
publish as github.com/<owner>/<name>.

Usage:
  bash dot plugins:new <owner>/<name> [--into <directory>]

Arguments:
  <owner>/<name>       The plugin's future GitHub repo.

Options:
  --into <directory>   Where to create it, inside the project (default:
                       <name>). It must not exist yet.
  -h, --help           Show this help.

Examples:
  bash dot plugins:new acme/widgets
  bash dot plugins:new acme/widgets --into packages/widgets

Layout:
  Everything below lives under $PLUGIN_ROOT/; the rest of the repo is yours.

  plugin.json   "requires" (plugin API $PLUGIN_API), "description", "depends",
                "settings" (camelCase keys, with defaults), and its suggested
                "link" and "append" ({"<origin>": ["<destination>"]})
  commands/     <name>.sh, each with DESCRIPTION, usage() and handle()
  context/      *.md appended to dotdot's docs of the same name
  skills/       linked into .agents/skills/
  agents/       linked into .agents/agents/
  stubs/        <path>.stub appended to <path> in the project

Notes:
  - Try it with bash dot plugins:add <owner>/<name> --from ./<directory>.
  - Code may use framework.helpers.*, framework.console.* and
    framework.integrations.<name>.service, plus its own files.
  - Settings: dot::plugin_setting <key>. Secrets: dot::secret, named
    DOT_<OWNER>_<NAME>__<KEY> in $(dot::relative "$HOST_ENV_FILE").
USAGE
}

handle() {
  local plugin="" path="" target
  while [ $# -gt 0 ]; do
    case "$1" in
      --into)
        framework.console.args::require_value "$@"
        [ -z "$path" ] || framework.console.args::invalid "Please give one directory."
        path="$2"
        shift 2
        ;;
      -*) framework.console.args::unexpected "$1" ;;
      *)
        if [ -z "$plugin" ]; then
          plugin="$1"
        elif [ -z "$path" ]; then
          path="$1"
        else
          framework.console.args::unexpected "$1"
        fi
        shift
        ;;
    esac
  done
  [ -n "$plugin" ] || framework.console.args::invalid "Which plugin? Please give it as <owner>/<name>."
  plugin=$(core.system.plugins.console::plugin "$plugin")
  target=$(framework.helpers.fs::within "${path:-${plugin#*/}}" "$BASE") || framework.console.output::fail "Plugins are created inside the project; please pick an --into <directory> in it."
  [ ! -e "$target" ] || framework.console.output::fail "$(dot::relative "$target") already exists; please pick another --into <directory>."
  core.system.plugins.service::scaffold "$plugin" "$target" || framework.console.output::fail "Couldn't create the plugin in $(dot::relative "$target")."
  framework.console.output::success "Created plugin $plugin."
  framework.console.output::detail "$(dot::relative "$target")"
  framework.console.output::next "Try it: bash dot plugins:add $plugin --from ./$(dot::relative "$target")"
}
