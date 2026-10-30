# shellcheck shell=bash

dot::use framework.console.output framework.ui.screen framework.ui.banner framework.ui.box framework.ui.message \
  framework.ui.list framework.ui.rule framework.ui.select framework.ui.checkbox framework.ui.confirm \
  framework.ui.progress framework.ui.steps framework.ui.spinner

TUI_COMPONENTS=(banner box message list rule select checkbox confirm progress steps spinner)
TUI_PROGRESS_STYLES=(thin fat count)
TUI_PROGRESS_TOTAL=20
TUI_FRAME_PAUSE=0.04
TUI_STEP_PAUSE=0.4
TUI_LOADER_PAUSE=1.5
TUI_WORK_SECONDS=0
TUI_SPINNER_SECONDS=1.5
TUI_HARNESSES=("Claude Code" Cursor Codex)
TUI_SKILLS=(review deploy release)
TUI_STEPS=("Read the settings" "Link the skills" "Link the agents" "Check every link")

core.modules.tui.console::is_component() {
  [[ " ${TUI_COMPONENTS[*]} " == *" $1 "* ]]
}

# <component>'s name as a heading, a blank line above it.
core.modules.tui.console::heading() {
  printf '\n'
  framework.console.output::line "$(framework.console.output::heading "$1")"
}

# Every component once, as it looks, waiting on no one.
core.modules.tui.console::gallery() {
  local component
  for component in "${TUI_COMPONENTS[@]}"; do
    core.modules.tui.console::heading "$component"
    core.modules.tui.console::still "$component"
  done
}

# Each <component> in action, one after the other.
core.modules.tui.console::demo() {
  local component
  for component in "$@"; do
    core.modules.tui.console::heading "$component"
    core.modules.tui.console::live "$component"
  done
}

# <component> drawn once, inputs as their first frame.
core.modules.tui.console::still() {
  local style
  case "$1" in
    select) framework.ui.screen::settle "$(framework.ui.select::frame "Which harness do you use most?" 1 "${TUI_HARNESSES[@]}")" ;;
    checkbox) framework.ui.screen::settle "$(framework.ui.checkbox::frame "Which skills should we link?" 2 " 1 3 " "${TUI_SKILLS[@]}")" ;;
    confirm) framework.ui.screen::settle "$(framework.ui.confirm::frame "Link Cursor too?" true)" ;;
    progress)
      if ! framework.ui.screen::is_rich; then
        framework.ui.progress::show "$TUI_PROGRESS_TOTAL" "$TUI_PROGRESS_TOTAL" "Linking"
        return
      fi
      for style in "${TUI_PROGRESS_STYLES[@]}"; do
        UI_PROGRESS_STYLE="$style" framework.ui.progress::show $((TUI_PROGRESS_TOTAL / 2)) "$TUI_PROGRESS_TOTAL" "Linking"
        printf '\n' >&2
      done
      ;;
    steps)
      framework.ui.steps::show 3 "Linking" "${TUI_STEPS[@]}"
      # Kept as it is: the next component draws under it, not over it.
      UI_FRAME_LINES=0
      ;;
    spinner)
      if framework.ui.screen::is_rich; then
        framework.console.output::emit 2 "Working on it…${UI_SPINNER_FRAMES[0]}"
      else
        framework.console.output::emit 2 "Working on it…"
      fi
      ;;
    *) core.modules.tui.console::live "$1" ;;
  esac
}

# <component> doing what it does: inputs ask, bars fill, steps run.
core.modules.tui.console::live() {
  local answer style step
  case "$1" in
    banner) framework.ui.banner::show "dotdot" "The context, rules, and tools your agents work by." ;;
    box) framework.ui.box::show "WHAT'S LINKED" "Claude Code: 12 skills" "Cursor: 12 skills" ;;
    message)
      framework.ui.message::success "Linked dotdot to Claude Code." "Your skills show up there now."
      framework.ui.message::info "Cursor reads the same skills."
      framework.ui.message::warning "Codex has no agents folder yet."
      framework.ui.message::error "Couldn't read .dot/dot.json." "Check that the file is valid JSON."
      ;;
    list)
      framework.ui.list::item "Claude Code" "detected"
      framework.ui.list::show Cursor Codex
      ;;
    rule) framework.ui.rule::show ;;
    select)
      answer=$(framework.ui.select::ask "Which harness do you use most?" "${TUI_HARNESSES[@]}") || { core.modules.tui.console::unanswered; return 0; }
      framework.ui.message::success "You picked $answer."
      ;;
    checkbox)
      answer=$(framework.ui.box::wrap "SELECT ANY" framework.ui.checkbox::ask "Which skills should we link?" "${TUI_SKILLS[@]}") || { core.modules.tui.console::unanswered; return 0; }
      framework.ui.message::success "You picked ${answer:-none}."
      ;;
    confirm)
      if framework.ui.confirm::ask "Link Cursor too?" y; then
        framework.ui.message::success "You said yes."
      else
        framework.ui.message::info "You said no, or no one was there to answer."
      fi
      ;;
    progress)
      for style in "${TUI_PROGRESS_STYLES[@]}"; do
        for ((step = 0; step <= TUI_PROGRESS_TOTAL; step++)); do
          UI_PROGRESS_STYLE="$style" framework.ui.progress::show "$step" "$TUI_PROGRESS_TOTAL" "Linking"
          core.modules.tui.console::pause "$TUI_FRAME_PAUSE"
        done
      done
      ;;
    steps)
      for ((step = 1; step <= ${#TUI_STEPS[@]} + 1; step++)); do
        framework.ui.steps::show "$step" "Linking" "${TUI_STEPS[@]}"
        [ "$step" -gt "${#TUI_STEPS[@]}" ] || core.modules.tui.console::pause "$TUI_STEP_PAUSE"
      done
      # Decided here: the work runs with its output captured, off the terminal.
      ! framework.ui.screen::is_rich || TUI_WORK_SECONDS=$TUI_LOADER_PAUSE
      UI_STEPS_CURRENT=loader framework.ui.steps::run "Checking" core.modules.tui.console::work "${TUI_STEPS[@]}"
      ;;
    spinner) framework.ui.spinner::run "Working on it…" sleep "$TUI_SPINNER_SECONDS" ;;
  esac
}

# A step's work in the demo: a wait, as long as live sets.
core.modules.tui.console::work() {
  sleep "$TUI_WORK_SECONDS"
}

# A wait of <seconds> between two frames, only where they're drawn.
core.modules.tui.console::pause() {
  ! framework.ui.screen::is_rich || sleep "$1"
}

core.modules.tui.console::unanswered() {
  framework.ui.message::info "Skipped: this one needs a person at a terminal."
}

# Every component in one run, as a command would use them: a harness picked,
# skills chosen in a box, a yes or no (either goes on), then the work and
# what came of it. Without a
# person, the first harness and every skill.
core.modules.tui.console::tour() {
  local harness skills count
  framework.ui.banner::show "dotdot tour" "Every component, in one run."
  framework.ui.screen::on_cancel "Run bash dot tui:view all to start over."
  harness=$(framework.ui.select::ask "Which harness do you use most?" "${TUI_HARNESSES[@]}") || harness="${TUI_HARNESSES[0]}"
  skills=$(framework.ui.box::wrap "SELECT ANY" framework.ui.checkbox::ask "Which skills should we link?" "${TUI_SKILLS[@]}") \
    || skills=$(printf '%s\n' "${TUI_SKILLS[@]}")
  # A demo: no stops the tour no more than yes does.
  framework.ui.confirm::ask "Link them to $harness now?" y || true
  core.modules.tui.console::live steps
  core.modules.tui.console::live progress
  core.modules.tui.console::live spinner
  count=$(printf '%s' "$skills" | grep -c . || true)
  framework.ui.message::success "Linked $count skills to $harness." "They show up there the next time it starts."
  framework.ui.message::warning "Codex has no agents folder yet."
  # shellcheck disable=SC2086 # skill names, one word each
  [ "$count" -eq 0 ] || framework.ui.list::show $skills
  framework.ui.rule::show
  framework.ui.box::show "NEXT" "Run bash dot tui:view select to try one alone."
}
