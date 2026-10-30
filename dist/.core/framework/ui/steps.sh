# shellcheck shell=bash

hey::use framework.ui.screen framework.helpers.fs

UI_STEPS_SHOWN=-1

# The run through <item>... under <label>, redrawn in place on each call:
# those before <current> (1-based) done, <current> under way, the rest still
# to come, UI_STEPS_VISIBLE of them at most. A <current> past the last item
# shows them all done. Plain output prints each item once it's done.
framework.ui.steps::show() {
  local current="$1" label="$2" index
  shift 2
  if ! framework.ui.screen::is_rich; then
    framework.ui.steps::plain "$current" "$label" "$@"
    return 0
  fi
  if [ "$current" -gt $# ]; then
    framework.ui.screen::settle "$(framework.ui.steps::frame "$current" "" "$label" "$@")"
    return 0
  fi
  framework.ui.screen::draw "$(framework.ui.steps::frame "$current" "$(framework.ui.steps::marker 0)" "$label" "$@")"
}

# <function> called with each <item> in turn, under <label>: the current one
# marked as UI_STEPS_CURRENT says, a loader turning while it works. What the
# function prints shows once the steps are done. A step that fails is marked
# failed, ends the run, and its status is returned.
framework.ui.steps::run() {
  local label="$1" function="$2" output current process status=0 tick=0
  shift 2
  framework.helpers.fs::make_temp_file output || return 1
  for ((current = 1; current <= $#; current++)); do
    if ! framework.ui.screen::is_rich; then
      framework.ui.steps::plain "$current" "$label" "$@"
      "$function" "${!current}" >>"$output" 2>&1 || status=$?
    else
      "$function" "${!current}" >>"$output" 2>&1 &
      process=$!
      while kill -0 "$process" 2>/dev/null; do
        framework.ui.screen::draw "$(framework.ui.steps::frame "$current" "$(framework.ui.steps::marker "$tick")" "$label" "$@")"
        tick=$((tick + 1))
        sleep "$UI_SPINNER_INTERVAL"
      done
      wait "$process" || status=$?
    fi
    [ "$status" -eq 0 ] || break
  done
  if [ "$status" -ne 0 ]; then
    if framework.ui.screen::is_rich; then
      framework.ui.screen::settle "$(framework.ui.steps::frame "$current" "$(framework.console.output::paint "$UI_STYLE_STEP_FAILED" "$UI_ICON_ERROR")" "$label" "$@")"
    else
      framework.console.output::emit 2 "  $UI_ICON_ERROR ${!current}"
    fi
  else
    framework.ui.steps::show "$current" "$label" "$@"
  fi
  framework.console.output::emit_file 2 "$output"
  return "$status"
}

# What marks the step under way, at <tick>: the pointer, or the loader's frame.
framework.ui.steps::marker() {
  if [ "$UI_STEPS_CURRENT" = loader ]; then
    framework.console.output::paint "$UI_STYLE_STEP_CURRENT" "${UI_STEPS_LOADER_FRAMES[$(($1 % ${#UI_STEPS_LOADER_FRAMES[@]}))]}"
    return
  fi
  framework.console.output::paint "$UI_STYLE_STEP_CURRENT" "$UI_GLYPH_POINTER"
}

# The frame of the steps at <current>, <marker> before the one under way.
framework.ui.steps::frame() {
  local current="$1" marker="$2" label="$3" first last index
  shift 3
  last=$((current + 1))
  [ "$last" -ge "$UI_STEPS_VISIBLE" ] || last=$UI_STEPS_VISIBLE
  [ "$last" -le $# ] || last=$#
  first=$((last - UI_STEPS_VISIBLE + 1))
  [ "$first" -ge 1 ] || first=1
  framework.console.output::bold "$label:"
  for ((index = first; index <= last; index++)); do
    if [ "$index" -lt "$current" ]; then
      printf '\n  %s' "$(framework.console.output::paint "$UI_STYLE_STEP_DONE" "$UI_ICON_SUCCESS ${!index}")"
    elif [ "$index" -eq "$current" ]; then
      printf '\n  %s %s' "$marker" "$(framework.console.output::paint "$UI_STYLE_STEP_CURRENT" "${!index}")"
    else
      printf '\n  %s' "$(framework.console.output::paint "$UI_STYLE_STEP_PENDING" "$UI_GLYPH_BULLET ${!index}")"
    fi
  done
}

# The steps in plain output at <current>: <label> as they start, then each
# one once it's done.
framework.ui.steps::plain() {
  local current="$1" label="$2" index
  shift 2
  if [ "$current" -le 1 ] || [ "$UI_STEPS_SHOWN" -lt 0 ]; then
    framework.console.output::emit 2 "$label:"
    UI_STEPS_SHOWN=0
  fi
  for ((index = UI_STEPS_SHOWN + 1; index < current && index <= $#; index++)); do
    framework.console.output::emit 2 "  $UI_ICON_SUCCESS ${!index}"
    UI_STEPS_SHOWN=$index
  done
}
