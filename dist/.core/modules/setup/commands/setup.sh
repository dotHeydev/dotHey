#!/usr/bin/env bash

DESCRIPTION="Set dotdot up for the project's harnesses."
DOCS="setting-up"

dot::use framework.console.args framework.console.output framework.console.prompt framework.helpers.fs core.modules.setup.service core.modules.setup.console

usage() {
  cat <<EOF
Finds the harnesses the project uses and what they already hold, then links
dotdot where the chosen ones read it: AGENTS.md (or an import into their own
instructions file), and dotdot's skills and agents. With own, the project's
own skills and agents move into $DOTDOT_NAME/Skills/ and $DOTDOT_NAME/Agents/ and
are linked back. It previews every change and asks before applying any; with
no one at a terminal to ask, it only previews. Run it again to change the
choice: harnesses no longer chosen are unlinked.

Usage:
  bash dot setup [--harness <a,b>] [--strategy combine|own] [--dir <path>]
                 [--preview] [-y, --yes]

Options:
  --harness <a,b>       The harnesses to link: $(core.harnesses.harness::ids | tr '\n' ' ')
                        Without it, a terminal asks, the detected ones first.
  --strategy <name>     combine (the default): the project's files stay where
                        they are. own: its skills and agents move into dotdot.
  --dir <path>          Where dotdot lives afterwards: $DOTDOT_NAME (now) or
                        .agents/.dot; see bash dot relocate.
  --preview             Show the changes, and stop. Also --dry-run.
  -y, --yes             Apply without asking. Only at a terminal, or when
                        dotdot itself runs it.
  -h, --help            Show this help.

Examples:
  bash dot setup
  bash dot setup --harness claude,cursor --strategy combine --yes
  bash dot setup --harness claude --strategy own --preview
EOF
}

# The harnesses the person picks at the terminal, the detected ones offered.
ask_harnesses() {
  local detected="$1" answer
  answer=$(framework.console.prompt::ask "Which harnesses should dotdot link? (comma-separated: $SETUP_IDS)" "${detected// /,}")
  framework.console.args::split "$answer" | tr '\n' ' '
}

# combine or own, asked only when the project holds skills or agents.
ask_strategy() {
  local rows="$1" choice
  printf '%s\n' "$rows" | awk -F '\t' '$2 == "skill" || $2 == "agent"' | grep -q . || { printf '%s\n' "$SETUP_DEFAULT_STRATEGY"; return; }
  choice=$(framework.console.prompt::choice "What should happen to the project's own skills and agents?" \
    "Combine: they stay where they are, dotdot links beside them" \
    "Own: they move into $DOTDOT_NAME/ and are linked back") || framework.console.output::aborted
  [ "$choice" = 2 ] && printf 'own\n' || printf 'combine\n'
}

# Where dotdot lives, asked only when the project has an .agents/ folder.
ask_dir() {
  local choice
  [ -d "$BASE/$SETUP_AGENTS_HOME" ] && [ "$DOTDOT_NAME" != "$SETUP_AGENTS_HOME/.dot" ] || return 0
  choice=$(framework.console.prompt::choice "Where should dotdot live?" "$DOTDOT_NAME/ (where it is)" "$SETUP_AGENTS_HOME/.dot/") || framework.console.output::aborted
  [ "$choice" != 2 ] || printf '%s\n' "$SETUP_AGENTS_HOME/.dot"
}

# The rows without the links from folders dotdot doesn't hold yet (owned
# items, built files), for a preview that changes nothing.
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

# link's preview of the map as written, without its own closing lines.
link_preview() {
  dot::call link --preview 2>&1 | grep -v -e 'Preview only' -e 'No one at a terminal' -e 'To apply' || true
}

handle() {
  local harnesses="" strategy="" dir="" preview=false confirmed=false asked=false id detected rows backup all pending
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
        strategy="$2"
        shift
        ;;
      --dir)
        framework.console.args::require_value "$@"
        dir="${2%/}"
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
  # shellcheck disable=SC2086
  detected=$(core.modules.setup.service::detected $SETUP_IDS | tr '\n' ' ')
  if [ -z "$harnesses" ]; then
    if $preview; then
      harnesses="$detected"
    elif framework.console.prompt::can_ask; then
      # shellcheck disable=SC2086
      core.modules.setup.console::found "$(core.modules.setup.service::scan $SETUP_IDS)"
      harnesses=$(ask_harnesses "${detected% }")
      for id in $harnesses; do
        [[ " $SETUP_IDS " == *" $id "* ]] || framework.console.args::invalid "There's no harness $id; pick from: ${SETUP_IDS// /, }."
      done
      asked=true
    else
      framework.console.output::fail_as "$EXIT_PRECONDITION" "Which harnesses should dotdot link? No one is at a terminal to ask." \
        "Name them: bash dot setup --harness <a,b> (from: ${SETUP_IDS// /, })"
    fi
  fi
  # shellcheck disable=SC2086
  rows=$(core.modules.setup.service::scan $harnesses)
  if [ -z "$strategy" ] && $asked; then
    strategy=$(ask_strategy "$rows")
  fi
  strategy="${strategy:-$SETUP_DEFAULT_STRATEGY}"
  ! $asked || [ -n "$dir" ] || dir=$(ask_dir)
  $asked || core.modules.setup.console::found "$rows"
  # shellcheck disable=SC2086
  [ "$strategy" != own ] || core.modules.setup.service::plan_moves $harnesses
  core.modules.setup.service::plan_map "$harnesses" "$SETUP_IDS"
  framework.helpers.fs::make_temp_dir SETUP_WORK || framework.console.output::fail "Couldn't create a temporary directory; please check free space and \$TMPDIR."
  backup="$SETUP_WORK/dot.json"
  cp -p -- "$SETTINGS_FILE" "$backup" 2>/dev/null || : > "$backup"
  # With -y, link shows what it changes as it applies; no preview run first.
  if ! $confirmed || $preview; then
    core.modules.setup.service::write_map "$(present_rows "$SETUP_ROWS")" || framework.console.output::fail "Couldn't write the links."
    framework.console.output::newline
    link_preview
  fi
  core.modules.setup.console::moves
  [ -z "$dir" ] || [ "$dir" = "$DOTDOT_NAME" ] || framework.console.output::entry blue "~" "$DOTDOT_NAME/ → $dir/" "dotdot moves, and is relinked"
  if $preview || { ! $confirmed && ! framework.console.prompt::can_ask; }; then
    cat -- "$backup" > "$SETTINGS_FILE"
    $preview || framework.console.output::line "No one at a terminal to confirm, so this is only a preview."
    framework.console.output::line "Preview only — nothing changed."
    return 0
  fi
  if ! $confirmed && ! framework.console.prompt::confirm "Do you want to apply this setup?" n; then
    cat -- "$backup" > "$SETTINGS_FILE"
    framework.console.output::aborted "bash dot setup --harness ${harnesses// /,} --strategy $strategy"
    return 1
  fi
  core.modules.setup.service::move || framework.console.output::fail "Couldn't move every item; the rest is as it was."
  # shellcheck disable=SC2086
  core.modules.setup.service::build $harnesses || framework.console.output::fail "Couldn't build what the harnesses read."
  core.modules.setup.service::write_map "$SETUP_ROWS" || framework.console.output::fail "Couldn't write the links."
  dot::call link -y || framework.console.output::fail "Linking didn't finish; see above, then run: bash dot link"
  # shellcheck disable=SC2086
  all=$(core.modules.setup.service::scan $SETUP_IDS)
  pending=$(core.modules.setup.service::pending "$strategy" "$all
$(core.modules.setup.service::unsure "$all")")
  core.modules.setup.service::save "$harnesses" "$strategy" "$pending" || framework.console.output::fail "Couldn't save the setup."
  framework.console.output::success "Set up for: ${harnesses% }."
  core.modules.setup.console::pending "$pending"
  ! $asked || framework.console.prompt::hint "bash dot setup --harness ${harnesses// /,} --strategy $strategy${dir:+ --dir $dir} --yes"
  if [ -n "$dir" ] && [ "$dir" != "$DOTDOT_NAME" ]; then
    dot::call relocate "$dir" --yes || exit
  fi
}
