#!/usr/bin/env bash

dot::use core.modules.setup.service framework.console.output framework.helpers.json framework.helpers.text framework.ui.list

SETUP_STEP=0
SETUP_STEPS=0
SETUP_VERB_WIDTH=11
SETUP_ENDING="🚀 Build something amazing!"

# A warning for each harness whose data couldn't be read.
core.modules.setup.console::warn_invalid() {
  local id
  for id in ${SETUP_INVALID[@]+"${SETUP_INVALID[@]}"}; do
    framework.console.output::warn "Skipped the harness $id: its harness.json isn't valid JSON naming the harness."
  done
}

# What the scan found in <rows>, a line per harness with what it holds.
core.modules.setup.console::found() {
  local rows="$1" id
  if [ -z "$rows" ]; then
    framework.console.output::line "Found nothing of a harness's in the project."
    return
  fi
  framework.console.output::line "Found:"
  while IFS= read -r id; do
    if [ "$id" = "$SETUP_NO_HARNESS" ]; then
      framework.ui.list::item "Other docs" "$(core.modules.setup.service::summary "$id" "$rows")"
    else
      framework.ui.list::item "$(core.harnesses.harness::data "$id" .name)" "$(core.modules.setup.service::summary "$id" "$rows")"
    fi
  done < <(printf '%s\n' "$rows" | cut -f1 | awk '!seen[$0]++')
}

# <text> as the next question, numbered (2/4) while questions are counted.
core.modules.setup.console::question() {
  if [ "$SETUP_STEPS" -gt 0 ]; then
    printf '%s  %s' "$(framework.console.output::paint "$UI_STYLE_MUTED" "$SETUP_STEP/$SETUP_STEPS")" "$1"
  else
    printf '%s' "$1"
  fi
}

# The display names of <harness>..., as "A, B and C".
core.modules.setup.console::names() {
  local id names=() last
  for id in "$@"; do
    names+=("$(core.harnesses.harness::data "$id" .name)")
  done
  [ ${#names[@]} -gt 1 ] || { printf '%s' "${names[0]-}"; return; }
  last="${names[${#names[@]} - 1]}"
  unset 'names[${#names[@]}-1]'
  printf '%s and %s' "$(IFS=,; printf '%s' "${names[*]}" | sed 's/,/, /g')" "$last"
}

# The plan, condensed: link's <plan> (its --json preview), the moves own
# makes with <strategy>, and dotdot's move to <dir>, as what changes in the project, then in
# dotdot, a line per kind of change and folder. Status 1, saying so, when
# everything is already in place.
core.modules.setup.console::plan() {
  local plan="$1" dir="$2" strategy="$3" rows skills=0 agents=0 move skipped scope verb text previous="" folder missing=""
  for move in ${SETUP_MOVES[@]+"${SETUP_MOVES[@]}"}; do
    case "${move#*"$SETUP_TAB"}" in
      "$SETUP_AGENTS_DIR"/*) agents=$((agents + 1)) ;;
      *) skills=$((skills + 1)) ;;
    esac
  done
  rows=$(core.modules.setup.console::plan_rows "$plan")
  [ ${#SETUP_DUPLICATES[@]} -eq 0 ] || rows="$rows"$'\n'"project${SETUP_TAB}Replace${SETUP_TAB}$(framework.helpers.text::plural ${#SETUP_DUPLICATES[@]} duplicate) of what moves, with links"
  for skipped in ${SETUP_SKIPPED[@]+"${SETUP_SKIPPED[@]}"}; do
    rows="$rows"$'\n'"project${SETUP_TAB}Leave${SETUP_TAB}${skipped%%"$SETUP_TAB"*} ($(framework.console.output::paint "$UI_STYLE_MUTED" "${skipped#*"$SETUP_TAB"}"))"
  done
  if [ "$strategy" = own ]; then
    for folder in "$SETUP_SKILLS_DIR" "$SETUP_AGENTS_DIR"; do
      [ -d "$DOTDOT_ROOT/$folder" ] || missing="$missing${missing:+ and }$DOTDOT_NAME/$folder/"
    done
    [ -z "$missing" ] || rows="$rows"$'\n'"dotdot${SETUP_TAB}Create${SETUP_TAB}$missing, for your own skills and agents"
  fi
  if [ $((skills + agents)) -eq 1 ]; then
    move="${SETUP_MOVES[0]}"
    rows="$rows"$'\n'"dotdot${SETUP_TAB}Take in${SETUP_TAB}${move%%"$SETUP_TAB"*} as $DOTDOT_NAME/$(printf '%s' "${move#*"$SETUP_TAB"}" | cut -f1), linked back in place"
  elif [ $((skills + agents)) -gt 1 ]; then
    rows="$rows"$'\n'"dotdot${SETUP_TAB}Take in${SETUP_TAB}$(core.modules.setup.console::items "$skills" "$agents"), each linked back in place"
  fi
  [ -z "$dir" ] || [ "$dir" = "$DOTDOT_NAME" ] || rows="$rows"$'\n'"dotdot${SETUP_TAB}Move${SETUP_TAB}dotdot to $dir/, and relink it"
  rows=$(printf '%s\n' "$rows" | grep -v '^$' || true)
  if [ -z "$rows" ]; then
    framework.console.output::success "Everything is already in place."
    return 1
  fi
  framework.console.output::title "Here's the plan:"
  while IFS="$SETUP_TAB" read -r scope verb text; do
    if [ "$scope" != "$previous" ]; then
      framework.console.output::newline
      if [ "$scope" = project ]; then
        framework.console.output::line "  $(framework.console.output::heading "In your project")"
      else
        framework.console.output::line "  $(framework.console.output::heading "In dotdot")"
      fi
      previous="$scope"
    fi
    framework.console.output::line "    $(framework.console.output::bold "$(printf '%-*s' "$SETUP_VERB_WIDTH" "$verb")")$text"
  done < <(printf '%s\n' "$rows" | sort -s -t "$SETUP_TAB" -k1,1r)
  ! printf '%s\n' "$plan" | grep -q '"taken":[1-9]' \
    || framework.console.output::detail "$(framework.console.output::paint "$UI_STYLE_MUTED" "What's kept stays as it is; bash dot link --overwrite replaces it, backed up first.")"
}

# "<scope>\t<verb>\t<text>" for each kind of change in link's <plan>, its
# destinations grouped by folder; dotdot's own seeds left out.
core.modules.setup.console::plan_rows() {
  framework.helpers.json::leaves "$1" | awk -F '\t' -v dotdot="$DOTDOT_NAME/" -v OFS='\t' '
    $1 == "changes" { value[$2, $3] = $4; if ($2 + 1 > count) count = $2 + 1 }
    function verb(action) {
      if (action == "link" || action == "move") return "Link"
      if (action == "relink" || action == "backup") return "Replace"
      if (action == "append") return "Add"
      if (action == "create") return "Create"
      if (action == "skip") return "Keep"
      return "Remove"
    }
    function noun(folder) { return folder ~ /skills$/ ? "skills" : folder ~ /agents$/ ? "agents" : "files" }
    END {
      for (i = 0; i < count; i++) {
        destination = value[i, "destination"]
        scope = index(destination, dotdot) == 1 ? "dotdot" : "project"
        if (scope == "dotdot" && value[i, "action"] == "create") continue
        folder = destination
        sub(/\/$/, "", folder)
        if (!sub(/\/[^\/]*$/, "", folder)) folder = ""
        key = scope SUBSEP verb(value[i, "action"]) SUBSEP folder
        if (!(key in total)) order[++keys] = key
        total[key]++
        only[key] = value[i, "action"] == "append" ? "dotdot'"'"'s section to " destination : destination (value[i, "action"] == "link" ? " to " value[i, "origin"] : "")
      }
      # Groups alike but for their folder (19 skills in each harness) as one.
      for (k = 1; k <= keys; k++) {
        split(order[k], part, SUBSEP)
        if (total[order[k]] == 1) { row[++rows] = order[k]; continue }
        folder = part[3]
        if (folder ~ /\/(skills|agents)$/) sub(/\/[^\/]*$/, "", folder)
        alike = part[1] SUBSEP part[2] SUBSEP total[order[k]] SUBSEP noun(part[3])
        if (!(alike in places)) { row[++rows] = alike; first[alike] = part[3] "/" }
        folders[alike] = folders[alike] (places[alike]++ ? ", " : "") folder "/"
      }
      for (r = 1; r <= rows; r++) {
        n = split(row[r], part, SUBSEP)
        if (n == 3) text = only[row[r]]
        else text = part[3] " " part[4] (places[row[r]] > 1 ? " in each of " folders[row[r]] : " in " first[row[r]])
        if (part[2] == "Keep") text = text ", already there"
        print part[1], part[2], text
      }
    }'
}

# "9 skills into .dot/Skills/ and 1 agent into .dot/Agents/".
core.modules.setup.console::items() {
  local skills="$1" agents="$2" items=""
  [ "$skills" -eq 0 ] || items="$(framework.helpers.text::plural "$skills" skill) into $DOTDOT_NAME/$SETUP_SKILLS_DIR/"
  [ "$agents" -eq 0 ] || items="$items${items:+ and }$(framework.helpers.text::plural "$agents" agent) into $DOTDOT_NAME/$SETUP_AGENTS_DIR/"
  printf '%s' "$items"
}

# What own left in place, as warnings: for a run that showed no plan.
core.modules.setup.console::skipped() {
  local skipped
  for skipped in ${SETUP_SKIPPED[@]+"${SETUP_SKIPPED[@]}"}; do
    framework.console.output::warn "Left ${skipped%%"$SETUP_TAB"*} in place: ${skipped#*"$SETUP_TAB"}."
  done
}

# Done: the <harnesses> set up, in green, the next step, and the send-off.
core.modules.setup.console::finish() {
  local harnesses="$1" pending="$2"
  framework.console.output::newline
  framework.console.output::line "$(framework.console.output::paint "$UI_STYLE_SUCCESS" "$UI_ICON_SUCCESS dotdot is set up for $harnesses.")"
  if [ -n "$pending" ]; then
    framework.console.output::next "Now open your coding agent and tell it you're using dotdot; it finishes the rest."
  else
    framework.console.output::next "Now open your coding agent; dotdot is ready for it."
  fi
  framework.console.output::newline
  framework.console.output::line "$SETUP_ENDING"
  framework.console.output::newline
}
