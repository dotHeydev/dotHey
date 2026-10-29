#!/usr/bin/env bash

DESCRIPTION="Set dotdot up for the project's harnesses."
DOCS="setting-up"

dot::use framework.console.args framework.console.output framework.console.prompt framework.helpers.fs framework.helpers.json \
  framework.ui.checkbox framework.ui.select framework.ui.confirm framework.ui.spinner framework.ui.steps \
  core.modules.setup.service core.modules.setup.console

SETUP_LABEL_MOVE="Move your skills and agents into dotdot"
SETUP_LABEL_BUILD="Prepare what each harness reads"
SETUP_LABEL_LINK="Link dotdot where your harnesses read it"
SETUP_LABEL_SAVE="Save your choices"
SETUP_LABEL_RELOCATE=""
SETUP_CHOSEN=""
SETUP_STRATEGY=""
SETUP_DIR=""
SETUP_RESUME="Resume any time: bash dot setup"
SETUP_CANCEL_INFO="Press Esc to stop at any time; nothing changes until you agree."

usage() {
  cat <<EOF
Finds the harnesses the project uses and what they already hold, then links
dotdot where the chosen ones read it: AGENTS.md (or an import into their own
instructions file), and dotdot's skills and agents. In parallel (combine),
the project's own skills and agents stay where they are; centralized (own),
they move into $DOTDOT_NAME/Skills/ and $DOTDOT_NAME/Agents/ and are linked back.
It shows the plan and asks before changing anything; with no one at a
terminal to ask, it only shows the plan. Run it again to change the choice:
harnesses no longer chosen are unlinked.

Usage:
  bash dot setup [--harness <a,b>] [--strategy combine|own] [--dir <path>]
                 [--preview] [-y, --yes]

Options:
  --harness <a,b>       The harnesses to link: $(core.harnesses.harness::ids | tr '\n' ' ')
                        Without it, a terminal asks, the detected ones checked.
  --strategy <name>     combine (the default): in parallel, the project's files
                        stay where they are. own: centralized, its skills and
                        agents move into dotdot.
  --dir <path>          Where dotdot lives afterwards: $DOTDOT_NAME (now) or
                        .agents/.dot; see bash dot relocate.
  --preview             Show the plan, and stop. Also --dry-run.
  -y, --yes             Apply without asking. Only at a terminal, or when
                        dotdot itself runs it.
  -h, --help            Show this help.

Examples:
  bash dot setup
  bash dot setup --harness claude,cursor --strategy combine --yes
  bash dot setup --harness claude --strategy own --preview
EOF
}

# The harnesses to link, those in <detected> checked: each noted as already
# in use, with what <rows> say it holds, or as new.
ask_harnesses() {
  local detected="$1" rows="$2" id index=0 checked="" picked label note labels=() ids=()
  for id in $SETUP_IDS; do
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

ask_strategy() {
  local choice
  choice=$(framework.ui.select::ask "$(core.modules.setup.console::question "How should dotdot treat your own skills and agents?")" \
    "In parallel: they stay where they are, beside dotdot's" \
    "Centralize: they move into $DOTDOT_NAME/ and are linked back") || return 1
  case "$choice" in
    Centralize*) printf 'own\n' ;;
    *) printf 'combine\n' ;;
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

# The choice saved, and what is left for the agent, also into
# SETUP_WORK/pending for the send-off.
save_choices() {
  local all pending
  # shellcheck disable=SC2086
  all=$(core.modules.setup.service::scan $SETUP_IDS)
  pending=$(core.modules.setup.service::pending "$SETUP_STRATEGY" "$all
$(core.modules.setup.service::unsure "$all")")
  printf '%s' "$pending" > "$SETUP_WORK/pending"
  core.modules.setup.service::save "$SETUP_CHOSEN" "$SETUP_STRATEGY" "$pending"
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
  local harnesses="" preview=false confirmed=false asking=false ask_strategy=false ask_dir=false id detected rows plan="" names steps=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --harness)
        framework.console.args::require_value "$@"
        harnesses=$(framework.console.args::split "$2" | tr '\n' ' ')
        [ -n "$harnesses" ] || framework.console.args::invalid "--harness needs at least one harness."
        shift
        ;;
      --strategy)
        framework.console.args::require_value "$@"
        core.modules.setup.service::is_strategy "$2" || framework.console.args::invalid "--strategy is combine or own (got $2)."
        SETUP_STRATEGY="$2"
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
  ! $confirmed || guards::skip_confirmation \
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
    framework.console.output::info "$SETUP_CANCEL_INFO"
  fi
  framework.helpers.fs::make_temp_dir SETUP_WORK || framework.console.output::fail "Couldn't create a temporary directory; please check free space and \$TMPDIR."
  if $asking; then
    framework.ui.spinner::run "Getting dotdot ready for your project…" core.modules.setup.service::assess "$SETUP_WORK"
  else
    core.modules.setup.service::assess "$SETUP_WORK"
  fi || framework.console.output::fail "Couldn't look through the project's harnesses."
  detected=$(tr '\n' ' ' < "$SETUP_WORK/detected")
  rows=$(cat -- "$SETUP_WORK/rows")
  if $asking; then
    SETUP_STEPS=1
    [ -n "$SETUP_STRATEGY" ] || ! core.modules.setup.service::holds_items "$rows" || { ask_strategy=true; SETUP_STEPS=$((SETUP_STEPS + 1)); }
    [ -n "$SETUP_DIR" ] || ! core.modules.setup.service::agents_home_in_use || { ask_dir=true; SETUP_STEPS=$((SETUP_STEPS + 1)); }
    SETUP_STEP=1
    harnesses=$(ask_harnesses "$detected" "$rows") || exit "$EXIT_PRECONDITION"
    if $ask_strategy; then
      SETUP_STEP=$((SETUP_STEP + 1))
      SETUP_STRATEGY=$(ask_strategy) || exit "$EXIT_PRECONDITION"
    fi
    if $ask_dir; then
      SETUP_STEP=$((SETUP_STEP + 1))
      SETUP_DIR=$(ask_dir) || exit "$EXIT_PRECONDITION"
    fi
  elif [ -z "$harnesses" ]; then
    harnesses="$detected"
  fi
  SETUP_CHOSEN="${harnesses% }"
  SETUP_STRATEGY="${SETUP_STRATEGY:-$SETUP_DEFAULT_STRATEGY}"
  # shellcheck disable=SC2086
  [ "$SETUP_STRATEGY" != own ] || core.modules.setup.service::plan_moves $SETUP_CHOSEN
  core.modules.setup.service::plan_map "$SETUP_CHOSEN" "$SETUP_IDS"
  # shellcheck disable=SC2086
  names=$(core.modules.setup.console::names $SETUP_CHOSEN)
  if ! $confirmed || $preview; then
    framework.console.output::newline
    plan=$(UI_SPINNER_KEEP=false framework.ui.spinner::run "Preparing the plan…" link_plan) || framework.console.output::fail "Couldn't plan the links."
    if ! core.modules.setup.console::plan "$plan" "$SETUP_DIR" "$SETUP_STRATEGY"; then
      # Nothing to change on disk; the choice is still saved, once agreed to.
      ! $preview && framework.console.prompt::can_ask || return 0
      save_choices || framework.console.output::fail "Couldn't save the setup."
      core.modules.setup.console::finish "$names" "$(cat -- "$SETUP_WORK/pending" 2>/dev/null)"
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
  [ "$SETUP_STRATEGY" != own ] || steps+=("$SETUP_LABEL_MOVE")
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
  core.modules.setup.console::finish "$names" "$(cat -- "$SETUP_WORK/pending" 2>/dev/null)"
}
