#!/usr/bin/env bash

DESCRIPTION="Set dotdot up for the project's harnesses."
DOCS="setting-up"

dot::use framework.console.args framework.console.output framework.console.prompt framework.helpers.fs framework.helpers.json \
  framework.ui.checkbox framework.ui.select framework.ui.confirm framework.ui.spinner framework.ui.steps framework.ui.message \
  core.modules.setup.service core.modules.setup.console

SETUP_LABEL_MOVE="Move your skills and agents into dotdot"
SETUP_LABEL_BUILD="Prepare what each harness reads"
SETUP_LABEL_LINK="Link dotdot where your harnesses read it"
SETUP_LABEL_SAVE="Save your choices"
SETUP_LABEL_RELOCATE=""
SETUP_CHOSEN=""
SETUP_TYPE=""
SETUP_DIR=""
SETUP_RESUME="Resume any time: bash dot setup"
SETUP_CANCEL_INFO="Press Esc to stop at any time; nothing changes until you agree."
SETUP_RERUN_INFO="Change your choices later by running bash dot setup again."

usage() {
  cat <<EOF
Finds the harnesses the project uses and what they already hold, then links
dotdot where the chosen ones read it: AGENTS.md (or an import into their own
instructions file), and dotdot's skills and agents. In parallel, the
project's own skills and agents stay where they are; centralized, they move
into $DOTDOT_NAME/Skills/ and $DOTDOT_NAME/Agents/ and are linked back.
It shows the plan and asks before changing anything; with no one at a
terminal to ask, it only shows the plan. Run it again to change the choice:
harnesses no longer chosen are unlinked.

Usage:
  bash dot setup [--harness <a,b>] [--type parallel|centralize] [--dir <path>]
                 [--preview] [-y, --yes]

Options:
  --harness <a,b>       The harnesses to link: $(core.harnesses.harness::ids | tr '\n' ' ')
                        Without it, a terminal asks, the detected ones checked.
  --type <name>         parallel (the default): the project's skills and
                        agents stay where they are. centralize: they move
                        into dotdot and are linked back.
  --dir <path>          Where dotdot lives afterwards: $DOTDOT_NAME (now) or
                        .agents/.dot; see bash dot relocate.
  --preview             Show the plan, and stop. Also --dry-run.
  -y, --yes             Apply without asking: at a terminal, for an AI agent,
                        or when dotdot itself runs it.
  -h, --help            Show this help.

Examples:
  bash dot setup
  bash dot setup --harness claude,cursor --type parallel --yes
  bash dot setup --harness claude --type centralize --preview
EOF
}

# The harnesses to link, those in <detected> checked: each noted as already
# in use, with what <rows> say it holds, or as new.
ask_harnesses() {
  local detected="$1" rows="$2" id name index=0 checked="" picked label note labels=() ids=()
  # In the order of their names, as people look for them.
  for id in $(for name in $SETUP_IDS; do printf '%s\t%s\n' "$(core.harnesses.harness::data "$name" .name)" "$name"; done | sort -f | cut -f2); do
    if [[ " $detected " == *" $id "* ]]; then
      note=$(core.modules.setup.service::summary "$id" "$rows")
      note="in use${note:+: $note}"
    else
      note="new"
    fi
    label="$(core.harnesses.harness::data "$id" .name)  $(framework.console.output::paint "$UI_STYLE_MUTED" "($note)")"
    labels+=("$label")
    ids+=("$id")
    index=$((index + 1))
    [[ " $detected " != *" $id "* ]] || checked="$checked${checked:+,}$index"
  done
  while :; do
    picked=$(framework.ui.checkbox::ask --checked "$checked" "$(core.modules.setup.console::question "Which harnesses should dotdot link?")" "${labels[@]}") || return 1
    [ -z "$picked" ] || break
    framework.console.output::warn "Please pick at least one, or press Esc to stop."
  done
  while IFS= read -r label; do
    for index in "${!labels[@]}"; do
      [ "${labels[index]}" != "$label" ] || printf '%s ' "${ids[index]}"
    done
  done <<< "$picked"
}

ask_type() {
  local choice
  choice=$(framework.ui.select::ask "$(core.modules.setup.console::question "How should dotdot treat your own skills and agents?")" \
    "Centralize: they move into $DOTDOT_NAME/ and are linked back" \
    "In parallel: they stay where they are, beside dotdot's") || return 1
  case "$choice" in
    Centralize*) printf 'centralize\n' ;;
    *) printf 'parallel\n' ;;
  esac
}

ask_dir() {
  local choice
  choice=$(framework.ui.select::ask "$(core.modules.setup.console::question "You seem to keep your agent files in $SETUP_AGENTS_HOME/. Should dotdot live there too?")" \
    "Yes, move it to $SETUP_AGENTS_HOME/.dot/" "No, keep it in $DOTDOT_NAME/") || return 1
  case "$choice" in
    Yes*) printf '%s\n' "$SETUP_AGENTS_HOME/.dot" ;;
    *) printf '%s\n' "$DOTDOT_NAME" ;;
  esac
}

# The rows without the links from folders dotdot doesn't hold yet (owned
# items, built files), for a plan that changes nothing.
present_rows() {
  local kind origin destination folder
  while IFS="$SETUP_TAB" read -r kind origin destination; do
    case "$origin" in
      @dot:*/\*)
        folder="${origin#@dot:}"
        [ -d "$DOTDOT_ROOT/${folder%/\*}" ] || continue
        ;;
    esac
    printf '%s\t%s\t%s\n' "$kind" "$origin" "$destination"
  done <<< "$1"
}

# What link would change for the rows planned, as its --json preview; dot.json
# is left as it was.
link_plan() {
  local backup="$SETUP_WORK/dot.json"
  cp -p -- "$SETTINGS_FILE" "$backup" 2>/dev/null || : > "$backup"
  core.modules.setup.service::write_map "$(present_rows "$SETUP_ROWS")" || return 1
  dot::call link --preview --json 2>/dev/null
  cat -- "$backup" > "$SETTINGS_FILE"
}

# The map written and linked, link's errors raised as they are.
link_all() {
  local errors="$SETUP_WORK/link.errors" line message
  core.modules.setup.service::write_map "$SETUP_ROWS" || return 1
  [[ "$(dot::call link -y --json 2>"$errors")" == *'"failed":0'* ]] && return 0
  while IFS= read -r line; do
    message=$(framework.helpers.json::values "$line" .error.message)
    [ -z "$message" ] || dot::raise "$message"
  done < "$errors"
  dot::raise "Linking didn't finish." "bash dot link shows what's left."
}

# The choice saved, the dot entry in place, and what is left for the agent,
# also into SETUP_WORK/pending for the send-off.
save_choices() {
  local all pending
  # shellcheck disable=SC2086
  all=$(core.modules.setup.service::scan $SETUP_IDS)
  pending=$(core.modules.setup.service::pending "$SETUP_TYPE" "$all
$(core.modules.setup.service::unsure "$all")")
  printf '%s' "$pending" > "$SETUP_WORK/pending"
  core.modules.setup.service::entry_link \
    && core.modules.setup.service::save "$SETUP_CHOSEN" "$SETUP_TYPE" "$pending"
}

# One step of applying the setup, by its label.
apply_step() {
  # shellcheck disable=SC2086
  case "$1" in
    "$SETUP_LABEL_MOVE") core.modules.setup.service::centralize ;;
    "$SETUP_LABEL_BUILD") core.modules.setup.service::build $SETUP_CHOSEN ;;
    "$SETUP_LABEL_LINK") link_all ;;
    "$SETUP_LABEL_SAVE") save_choices ;;
    "$SETUP_LABEL_RELOCATE") dot::call relocate "$SETUP_DIR" --yes > /dev/null ;;
  esac
}

handle() {
  local harnesses="" preview=false confirmed=false asking=false ask_type=false ask_dir=false id detected rows plan="" steps=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --harness)
        framework.console.args::require_value "$@"
        harnesses=$(framework.console.args::split "$2" | tr '\n' ' ')
        [ -n "$harnesses" ] || framework.console.args::invalid "--harness needs at least one harness."
        shift
        ;;
      --type)
        framework.console.args::require_value "$@"
        core.modules.setup.service::is_type "$2" || framework.console.args::invalid "--type is parallel or centralize (got $2)."
        SETUP_TYPE="$2"
        shift
        ;;
      --dir)
        framework.console.args::require_value "$@"
        SETUP_DIR="${2%/}"
        shift
        ;;
      --preview | --dry-run) preview=true ;;
      -y | --yes) confirmed=true ;;
      *) framework.console.args::unexpected "$1" ;;
    esac
    shift
  done
  # An agent may set dotdot up unattended, as the user asked it to.
  ! $confirmed || guards::skip_confirmation || framework.console.output::is_agent \
    || framework.console.output::fail_as "$EXIT_PRECONDITION" "-y only works in a terminal, so nothing changed unseen." "$OUTPUT_MANUAL_RUN bash dot setup"
  core.modules.setup.service::harnesses
  core.modules.setup.console::warn_invalid
  for id in $harnesses; do
    [[ " $SETUP_IDS " == *" $id "* ]] || framework.console.args::invalid "There's no harness $id; pick from: ${SETUP_IDS// /, }."
  done
  if [ -z "$harnesses" ] && ! $preview; then
    framework.console.prompt::can_ask || framework.console.output::fail_as "$EXIT_PRECONDITION" "Which harnesses should dotdot link? No one is at a terminal to ask." \
      "Name them: bash dot setup --harness <a,b> (from: ${SETUP_IDS// /, })"
    asking=true
    framework.ui.screen::on_cancel "$SETUP_RESUME"
    framework.ui.message::info "$SETUP_CANCEL_INFO" "$SETUP_RERUN_INFO"
  fi
  # Setup may move dotdot (--dir), so a fallback for its files can't be in it.
  FS_TEMP_FALLBACK="$BASE/$DOT_PROJECT_TEMP_DIR"
  framework.helpers.fs::make_temp_dir SETUP_WORK || framework.console.output::fail "Couldn't create a temporary directory; please check free space and \$TMPDIR."
  if $asking; then
    framework.ui.spinner::run "Getting dotdot ready for your project…" core.modules.setup.service::assess "$SETUP_WORK"
  else
    core.modules.setup.service::assess "$SETUP_WORK"
  fi || framework.console.output::fail "Couldn't look through the project's harnesses."
  detected=$(tr '\n' ' ' < "$SETUP_WORK/detected")
  # Asked again, the harnesses chosen last time count as in use too.
  $asking && detected="$detected $(core.modules.setup.service::list "$SETUP_HARNESSES_SETTING" | tr '\n' ' ')"
  rows=$(cat -- "$SETUP_WORK/rows")
  if $asking; then
    SETUP_STEPS=1
    [ -n "$SETUP_TYPE" ] || ! core.modules.setup.service::holds_items "$rows" || { ask_type=true; SETUP_STEPS=$((SETUP_STEPS + 1)); }
    [ -n "$SETUP_DIR" ] || ! core.modules.setup.service::agents_home_in_use || { ask_dir=true; SETUP_STEPS=$((SETUP_STEPS + 1)); }
    SETUP_STEP=1
    harnesses=$(ask_harnesses "$detected" "$rows") || exit "$EXIT_PRECONDITION"
    if $ask_type; then
      SETUP_STEP=$((SETUP_STEP + 1))
      SETUP_TYPE=$(ask_type) || exit "$EXIT_PRECONDITION"
    fi
    if $ask_dir; then
      SETUP_STEP=$((SETUP_STEP + 1))
      SETUP_DIR=$(ask_dir) || exit "$EXIT_PRECONDITION"
    fi
  elif [ -z "$harnesses" ]; then
    harnesses="$detected"
  fi
  SETUP_CHOSEN="${harnesses% }"
  SETUP_TYPE="${SETUP_TYPE:-$SETUP_DEFAULT_TYPE}"
  # shellcheck disable=SC2086
  [ "$SETUP_TYPE" != centralize ] || core.modules.setup.service::plan_moves $SETUP_CHOSEN
  core.modules.setup.service::plan_map "$SETUP_CHOSEN" "$SETUP_IDS"
  if ! $confirmed || $preview; then
    framework.console.output::newline
    plan=$(UI_SPINNER_KEEP=false framework.ui.spinner::run "Preparing the plan…" link_plan) || framework.console.output::fail "Couldn't plan the links."
    if ! core.modules.setup.console::plan "$plan" "$SETUP_DIR" "$SETUP_TYPE"; then
      # Nothing to change on disk; the choice is still saved, once agreed to.
      ! $preview && framework.console.prompt::can_ask || return 0
      save_choices || framework.console.output::fail "Couldn't save the setup."
      core.modules.setup.console::finish "$(cat -- "$SETUP_WORK/pending" 2>/dev/null)" "${SETUP_DIR:-$DOTDOT_NAME}"
      return 0
    fi
  fi
  if $preview || { ! $confirmed && ! framework.console.prompt::can_ask; }; then
    framework.console.output::newline
    $preview || framework.console.output::line "No one at a terminal to confirm, so this is only a preview."
    framework.console.output::line "Preview only — nothing changed."
    return 0
  fi
  if ! $confirmed; then
    framework.ui.confirm::ask "Apply this setup?" y || { framework.console.output::aborted "$SETUP_RESUME"; return 1; }
  fi
  [ "$SETUP_TYPE" != centralize ] || steps+=("$SETUP_LABEL_MOVE")
  steps+=("$SETUP_LABEL_BUILD" "$SETUP_LABEL_LINK" "$SETUP_LABEL_SAVE")
  if [ -n "$SETUP_DIR" ] && [ "$SETUP_DIR" != "$DOTDOT_NAME" ]; then
    SETUP_LABEL_RELOCATE="Move dotdot to $SETUP_DIR/"
    steps+=("$SETUP_LABEL_RELOCATE")
    # dotdot moves from under this run: it keeps printing from copies.
    framework.console.output::detach || framework.console.output::fail "Couldn't create a temporary directory; please check free space and \$TMPDIR."
  fi
  framework.console.output::newline
  UI_STEPS_CURRENT=loader framework.ui.steps::run "Setting up" apply_step "${steps[@]}" \
    || framework.console.output::fail "The setup didn't finish; run it again with: bash dot setup"
  [ -n "$plan" ] || core.modules.setup.console::skipped
  core.modules.setup.console::finish "$(cat -- "$SETUP_WORK/pending" 2>/dev/null)" "${SETUP_DIR:-$DOTDOT_NAME}"
}
