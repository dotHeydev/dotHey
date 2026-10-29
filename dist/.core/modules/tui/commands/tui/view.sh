#!/usr/bin/env bash

DESCRIPTION="Preview the UI components, still or in action."
HIDDEN=true

dot::use framework.console.args framework.ui.screen framework.ui.select framework.ui.checkbox core.modules.tui.console

usage() {
  cat <<EOF
Shows the framework.ui components as they look at your terminal, or as
plain text where there is none.

Usage:
  bash dot tui:view [<components> | all]

Arguments:
  <components>  The components to see in action, separated by commas:
                ${TUI_COMPONENTS[*]}.
  all           Every component in one run, as a command would use them.
                Without an argument: at a terminal, you pick what to see;
                anywhere else, every component, still.

Options:
  -h, --help    Show this help.

Examples:
  bash dot tui:view
  bash dot tui:view select,progress
  bash dot tui:view all
EOF
}

handle() {
  local component components=() choice picked
  case "${1-}" in
    -*) framework.console.args::unexpected "$1" ;;
  esac
  [ $# -le 1 ] || framework.console.args::unexpected "$2"
  case "${1-}" in
    '') ;;
    all) core.modules.tui.console::tour; return ;;
    *)
      while IFS= read -r component; do
        core.modules.tui.console::is_component "$component" \
          || framework.console.args::invalid "There's no $component component. Pick from: ${TUI_COMPONENTS[*]}."
        components+=("$component")
      done < <(framework.console.args::split "$1")
      [ ${#components[@]} -gt 0 ] || framework.console.args::invalid "Please name at least one component."
      core.modules.tui.console::demo "${components[@]}"
      return
      ;;
  esac
  if ! framework.ui.screen::reads_keys; then
    core.modules.tui.console::gallery
    return
  fi
  choice=$(framework.ui.select::ask "What would you like to see?" \
    "Every component, still" "Every component, in one run" "Some components, in action") || exit
  case "$choice" in
    "Every component, still") core.modules.tui.console::gallery ;;
    "Every component, in one run") core.modules.tui.console::tour ;;
    *)
      picked=$(framework.ui.checkbox::ask "Which ones?" "${TUI_COMPONENTS[@]}") || exit
      while IFS= read -r component; do
        [ -z "$component" ] || components+=("$component")
      done <<< "$picked"
      [ ${#components[@]} -eq 0 ] || core.modules.tui.console::demo "${components[@]}"
      ;;
  esac
}
