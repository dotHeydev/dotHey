#!/usr/bin/env bash

# Setting dotdot up for a project: which harnesses it has and holds, and the
# links map entries that put dotdot where the chosen ones read it. Links are
# only ever changed through the map; bash dot link does the linking. Rows are
# tab-separated: "<link|append|skip>\t<origin>\t<destination>".

dot::use core.harnesses.harness core.harnesses.capabilities.agents framework.helpers.fs framework.helpers.json framework.helpers.text

SETUP_TYPES=" parallel centralize "
SETUP_DEFAULT_TYPE="parallel"
SETUP_HARNESSES_SETTING="setup.harnesses"
SETUP_TYPE_SETTING="setup.type"
SETUP_LINKS_SETTING="setup.links"
SETUP_PENDING_SETTING="setup.pending"
SETUP_DONE_SETTING="setup.done"
SETUP_READY_SETTING="state.isReady"
SETUP_SKILLS_DIR="Skills"
SETUP_AGENTS_DIR="Agents"
SETUP_AGENTS_HOME=".agents"
SETUP_TAB=$'\t'
SETUP_NO_HARNESS="-"
# Top-level docs every project has, which say what it is rather than how an
# agent should work: never listed as unsure.
SETUP_KNOWN_DOCS=" README.md CHANGELOG.md LICENSE.md "

SETUP_IDS=""
SETUP_INVALID=()
SETUP_WANTED=""
SETUP_MOVES=()
SETUP_DUPLICATES=()
SETUP_SKIPPED=()
SETUP_ROWS=""

# Every harness whose data is valid into SETUP_IDS (space-separated), the
# others into SETUP_INVALID.
core.modules.setup.service::harnesses() {
  local id
  SETUP_IDS=""
  SETUP_INVALID=()
  while IFS= read -r id; do
    if core.harnesses.harness::valid "$id"; then
      SETUP_IDS="$SETUP_IDS${SETUP_IDS:+ }$id"
    else
      SETUP_INVALID+=("$id")
    fi
  done < <(core.harnesses.harness::ids)
}

core.modules.setup.service::is_type() {
  [[ "$SETUP_TYPES" == *" $1 "* ]]
}

core.modules.setup.service::detected() {
  local id
  for id in "$@"; do
    core.harnesses.harness::call "$id" detect && printf '%s\n' "$id"
  done
  return 0
}

# "<harness>\t<kind>\t<path>\t<size>" for what the given harnesses' places
# hold, each path once.
core.modules.setup.service::scan() {
  local id
  for id in "$@"; do
    core.harnesses.harness::call "$id" scan | sed "s|^|$id$SETUP_TAB|"
  done | awk -F '\t' '!seen[$3]++'
}

# "-\tunsure\t<path>\t<size>" for each top-level Markdown doc no harness
# claims (not in <rows>), nor dotdot links or knows: context that may belong
# to the project's setup, for the agent to raise with the user.
core.modules.setup.service::unsure() {
  local rows="$1" file name
  for file in "$BASE"/*.md; do
    [ -f "$file" ] || continue
    name="${file##*/}"
    [[ "$SETUP_KNOWN_DOCS" != *" $name "* ]] && ! core.harnesses.harness::is_dotdots "$file" \
      && ! core.harnesses.harness::leaves_project "$file" || continue
    printf '%s\n' "$rows" | awk -F '\t' -v path="$name" '$3 == path { found = 1 } END { exit !found }' && continue
    printf '%s\tunsure\t%s\t%s\n' "$SETUP_NO_HARNESS" "$name" "$(core.harnesses.harness::size "$file")"
  done
}

# What the project holds, found once before anything is asked: the detected
# harnesses into <directory>/detected, the scan of every harness into
# <directory>/rows.
core.modules.setup.service::assess() {
  local directory="$1"
  # shellcheck disable=SC2086
  core.modules.setup.service::detected $SETUP_IDS > "$directory/detected" \
    && core.modules.setup.service::scan $SETUP_IDS > "$directory/rows"
}

# What <harness> holds in <rows>, counted by kind: "9 skills, 1 agent".
core.modules.setup.service::summary() {
  local id="$1" rows="$2" kind count summary=""
  while read -r count kind; do
    case "$kind" in
      instructions) kind=$(framework.helpers.text::plural "$count" "instructions file") ;;
      unsure) kind="$(framework.helpers.text::plural "$count" doc) to check" ;;
      mcp) kind=$(framework.helpers.text::plural "$count" "MCP config") ;;
      setting) kind=$(framework.helpers.text::plural "$count" "settings file") ;;
      personal) kind=$(framework.helpers.text::plural "$count" "personal instructions file") ;;
      *) kind=$(framework.helpers.text::plural "$count" "$kind") ;;
    esac
    summary="$summary${summary:+, }$kind"
  done < <(printf '%s\n' "$rows" | awk -F '\t' -v id="$id" '$1 == id { print $2 }' | sort | uniq -c)
  printf '%s' "$summary"
}

# Whether <rows> hold skills or agents of the project's own, for own to move.
core.modules.setup.service::holds_items() {
  printf '%s\n' "$1" | awk -F '\t' '$2 == "skill" || $2 == "agent" { found = 1 } END { exit !found }'
}

# Whether the project uses .agents/ for more than skills, or links into it
# from a harness's folders: then dotdot may belong there too.
core.modules.setup.service::agents_home_in_use() {
  local home="$BASE/$SETUP_AGENTS_HOME" entry destination target
  [ -d "$home" ] && [ ! -L "$home" ] && [ "$DOTDOT_NAME" != "$SETUP_AGENTS_HOME/.dot" ] || return 1
  for entry in "$home"/* "$home"/.[!.]*; do
    [ -e "$entry" ] || [ -L "$entry" ] || continue
    case "${entry##*/}" in
      skills | .dot) ;;
      *) return 0 ;;
    esac
  done
  # shellcheck disable=SC2086
  while IFS= read -r destination; do
    for entry in "$BASE/$destination" "$BASE/$destination"/*; do
      [ -L "$entry" ] && target=$(framework.helpers.fs::resolve "$entry") && framework.helpers.fs::is_inside "$target" "$home" && return 0
    done
  done < <(core.modules.setup.service::destinations $SETUP_IDS)
  return 1
}

core.modules.setup.service::state() {
  dot::setting "$1" "$2" 2>/dev/null || printf '%s\n' "$2"
}

# The names of dotdot's own skills and agents, which an owned item may not take.
core.modules.setup.service::taken_names() {
  local root
  while IFS= read -r root; do
    for root in "$root/skills"/*/ "$root/agents"/*.md; do
      [ -e "$root" ] || continue
      root="${root%/}"
      root="${root##*/}"
      printf '%s\n' "${root%.md}"
    done
  done < <(paths::modules)
}

# What centralizing would move, into SETUP_MOVES ("<from>\t<to>\t<harness>", project
# and dotdot paths); the copies of an item already moving, which go once it
# has, into SETUP_DUPLICATES ("<path>"); and what it leaves, into
# SETUP_SKIPPED ("<path>\t<why>").
core.modules.setup.service::plan_moves() {
  local taken id kind path name folder absolute first
  SETUP_MOVES=()
  SETUP_DUPLICATES=()
  SETUP_SKIPPED=()
  taken=" $(core.modules.setup.service::taken_names | tr '\n' ' ') "
  while IFS="$SETUP_TAB" read -r id kind path _; do
    absolute="$BASE/$path"
    name="${path##*/}"
    case "$kind" in
      skill) folder="$SETUP_SKILLS_DIR" ;;
      agent)
        folder="$SETUP_AGENTS_DIR"
        if ! name=$(core.harnesses.capabilities.agents::name_of "$id" "${path##*/}"); then
          SETUP_SKIPPED+=("$path${SETUP_TAB}in $(core.harnesses.harness::data "$id" .name)'s own format, not dotdot's")
          continue
        fi
        name="$name.md"
        if ! core.harnesses.capabilities.agents::import "$id" "${name%.md}" "$absolute" > /dev/null; then
          SETUP_SKIPPED+=("$path${SETUP_TAB}can't be read as an agent")
          continue
        fi
        ;;
      *) continue ;;
    esac
    if [ -L "$absolute" ]; then
      SETUP_SKIPPED+=("$path${SETUP_TAB}a link, left where it points")
    elif [[ "$taken" == *" ${name%.md} "* ]]; then
      SETUP_SKIPPED+=("$path${SETUP_TAB}dotdot has one named ${name%.md}")
    elif [ -e "$DOTDOT_ROOT/$folder/$name" ] || [ -L "$DOTDOT_ROOT/$folder/$name" ]; then
      SETUP_SKIPPED+=("$path${SETUP_TAB}$DOTDOT_NAME/$folder/$name already exists")
    elif first=$(core.modules.setup.service::moving_to "$folder/$name"); then
      if diff -rq -- "$BASE/$first" "$absolute" > /dev/null 2>&1; then
        SETUP_DUPLICATES+=("$path")
      else
        SETUP_SKIPPED+=("$path${SETUP_TAB}differs from $first, which moves")
      fi
    else
      SETUP_MOVES+=("$path$SETUP_TAB$folder/$name$SETUP_TAB$id")
    fi
  done < <(core.modules.setup.service::scan "$@")
}

# The item planned to move to <to> (a dotdot path), if any.
core.modules.setup.service::moving_to() {
  local move rest
  for move in ${SETUP_MOVES[@]+"${SETUP_MOVES[@]}"}; do
    rest="${move#*"$SETUP_TAB"}"
    if [ "${rest%%"$SETUP_TAB"*}" = "$1" ]; then
      printf '%s\n' "${move%%"$SETUP_TAB"*}"
      return 0
    fi
  done
  return 1
}

# Whether dotdot holds owned items in <folder> (Skills, Agents), or will
# once the planned moves are made.
core.modules.setup.service::will_own() {
  local entry move
  for entry in "$DOTDOT_ROOT/$1"/*; do
    [ -e "$entry" ] && [ "${entry##*/}" != "$KEEP_FILE" ] && return 0
  done
  for move in ${SETUP_MOVES[@]+"${SETUP_MOVES[@]}"}; do
    [[ "${move#*"$SETUP_TAB"}" == "$1/"* ]] && return 0
  done
  return 1
}

# The general entries of the links (no plugin's), as rows: dot.json's, or
# dotdot's default links when it has none.
core.modules.setup.service::map_rows() {
  local document
  document=$(framework.helpers.json::encoded "$(cat -- "$SETTINGS_FILE" 2>/dev/null)" .links)
  [ -n "$document" ] && [ "$document" != null ] || document=$(dot::default_value links "")
  framework.helpers.json::leaves "{\"links\": $document}" | awk -F '\t' -v OFS='\t' '
    $1 != "links" { next }
    NF == 4 && $2 != "append" && $2 != "skip" && $2 != "inactive" && $3 ~ /^[0-9]+$/ { print "link", $2, $4; next }
    NF == 5 && ($2 == "append" || $2 == "skip") && $4 ~ /^[0-9]+$/ { print $2, $3, $5 }
  '
}

# The rows setup wrote last time, from setup.links.
core.modules.setup.service::previous_rows() {
  local document
  document=$(core.modules.setup.service::state "$SETUP_LINKS_SETTING" "{}")
  framework.helpers.json::leaves "$document" | awk -F '\t' -v OFS='\t' '($1 == "link" || $1 == "append") && NF == 4 { print $1, $2, $4 }'
}

# The rows the chosen harnesses need: AGENTS.md at the root (appended into
# the project's own), then each harness's; owned items only once dotdot
# holds some.
core.modules.setup.service::wanted_rows() {
  local id kind origin destination
  if [ -f "$BASE/AGENTS.md" ] && [ ! -L "$BASE/AGENTS.md" ]; then
    printf 'append\t@dot:AGENTS.md\tAGENTS.md\n'
  else
    printf 'link\t@dot:AGENTS.md\tAGENTS.md\n'
  fi
  for id in "$@"; do
    while IFS="$SETUP_TAB" read -r kind origin destination; do
      case "$origin" in
        "@dot:$SETUP_SKILLS_DIR/*") core.modules.setup.service::will_own "$SETUP_SKILLS_DIR" || continue ;;
        "@dot:$SETUP_AGENTS_DIR/*") core.modules.setup.service::will_own "$SETUP_AGENTS_DIR" || continue ;;
      esac
      printf '%s\t%s\t%s\n' "$kind" "$origin" "$destination"
    done < <(core.harnesses.harness::call "$id" rows)
  done | awk '!seen[$0]++'
}

# Every destination the given harnesses may use, one per line, without a
# trailing /.
core.modules.setup.service::destinations() {
  local id
  for id in "$@"; do
    core.harnesses.harness::call "$id" destinations
  done | sed 's|/$||' | sort -u
}

# The links rows after choosing <chosen> (space-separated) among <all>: the
# wanted rows added and taken out of skip; last time's rows no longer
# wanted, and every entry aimed at a harness not chosen, moved to skip.
# Into SETUP_ROWS.
core.modules.setup.service::plan_map() {
  local chosen="$1" all="$2" wanted previous current dropped id unchosen=() picked=()
  for id in $all; do
    if [[ " $chosen " == *" $id "* ]]; then picked+=("$id"); else unchosen+=("$id"); fi
  done
  wanted=$(core.modules.setup.service::wanted_rows ${picked[@]+"${picked[@]}"})
  previous=$(core.modules.setup.service::previous_rows)
  current=$(core.modules.setup.service::map_rows)
  dropped=$(comm -23 \
    <(core.modules.setup.service::destinations ${unchosen[@]+"${unchosen[@]}"}) \
    <(core.modules.setup.service::destinations ${picked[@]+"${picked[@]}"}))
  SETUP_ROWS=$(awk -F '\t' -v OFS='\t' -v wanted="$wanted" -v previous="$previous" -v dropped="$dropped" '
    function key(kind, origin, destination) { sub(/\/$/, "", destination); return kind SUBSEP origin SUBSEP destination }
    BEGIN {
      n = split(wanted, lines, "\n")
      for (i = 1; i <= n; i++) if (split(lines[i], f, "\t") == 3) want[key(f[1], f[2], f[3])] = 1
      n = split(previous, lines, "\n")
      for (i = 1; i <= n; i++) if (split(lines[i], f, "\t") == 3 && !(key(f[1], f[2], f[3]) in want)) gone[key(f[1], f[2], f[3])] = lines[i]
      n = split(dropped, lines, "\n")
      for (i = 1; i <= n; i++) if (lines[i] != "") drop[lines[i]] = 1
    }
    {
      destination = $3
      sub(/\/$/, "", destination)
      if ($1 == "skip") {
        if (key("link", $2, $3) in want || key("append", $2, $3) in want) next
        print; seen["skip" SUBSEP $2 SUBSEP destination] = 1; next
      }
      if (key($1, $2, $3) in want) { if (!(key($1, $2, $3) in printed)) { print; printed[key($1, $2, $3)] = 1 }; next }
      # A link where an append of the same origin is wanted (or the other way
      # round): the destination changed kind, so the old entry just goes.
      if (key($1 == "link" ? "append" : "link", $2, $3) in want) next
      if (key($1, $2, $3) in gone || destination in drop) { removed[$2 SUBSEP $3] = 1; next }
      print
    }
    END {
      n = split(wanted, lines, "\n")
      for (i = 1; i <= n; i++) if (split(lines[i], f, "\t") == 3 && !(key(f[1], f[2], f[3]) in printed)) { print lines[i]; printed[key(f[1], f[2], f[3])] = 1 }
      for (k in gone) { split(gone[k], f, "\t"); removed[f[2] SUBSEP f[3]] = 1 }
      for (k in removed) {
        split(k, f, SUBSEP)
        destination = f[2]
        sub(/\/$/, "", destination)
        if (!(("skip" SUBSEP f[1] SUBSEP destination) in seen)) print "skip", f[1], f[2]
      }
    }
  ' <<< "$current")
  SETUP_WANTED="$wanted"
}

# Rows of one kind as a JSON object: {"<origin>": ["<destination>", ...]}.
core.modules.setup.service::object() {
  local kind="$1" rows="$2" origin destination previous="" json="" list=""
  while IFS="$SETUP_TAB" read -r _ origin destination; do
    if [ "$origin" != "$previous" ] && [ -n "$previous" ]; then
      json="$json${json:+, }$(framework.helpers.json::string "$previous"): [$list]"
      list=""
    fi
    previous="$origin"
    list="$list${list:+, }$(framework.helpers.json::string "$destination")"
  done < <(printf '%s\n' "$rows" | awk -F '\t' -v kind="$kind" '$1 == kind' | sort -t "$SETUP_TAB" -s -k2,2)
  [ -z "$previous" ] || json="$json${json:+, }$(framework.helpers.json::string "$previous"): [$list]"
  printf '{%s}' "$json"
}

# Writes <rows> as the general links in dot.json, keeping every plugin's group
# and the inactive ones as they are.
core.modules.setup.service::write_map() {
  local rows="$1" document links key kept="" general
  document=$(cat -- "$SETTINGS_FILE" 2>/dev/null) || document="{}"
  links=$(framework.helpers.json::encoded "$document" .links)
  [ -n "$links" ] && [ "$links" != null ] || links="{}"
  while IFS= read -r key; do
    case "$key" in
      append | skip) ;;
      inactive | */*) kept="$kept, $(framework.helpers.json::string "$key"): $(framework.helpers.json::encoded "$links" ".[$(framework.helpers.json::string "$key")]")" ;;
    esac
  done < <(framework.helpers.json::keys "$links" .)
  general=$(core.modules.setup.service::object link "$rows")
  general="${general#\{}"
  general="${general%\}}"
  general="{$general${general:+, }\"append\": $(core.modules.setup.service::object append "$rows"), \"skip\": $(core.modules.setup.service::object skip "$rows")$kept}"
  document=$(framework.helpers.json::set "$document" .links "$general" --keep-format) \
    && printf '%s\n' "$document" | framework.helpers.fs::write "$SETTINGS_FILE" \
    || dot::raise "Couldn't write the links to $(dot::relative "$SETTINGS_FILE"); please check that it's writable."
}

# Builds what the given harnesses link from dotdot (renamed or rendered
# files), and drops what was built for any other.
core.modules.setup.service::build() {
  local id directory
  for id in "$@"; do
    core.harnesses.harness::call "$id" build \
      || { dot::raise "Couldn't build what $(core.harnesses.harness::data "$id" .name) reads from dotdot."; return 1; }
  done
  for directory in "$DOTDOT_ROOT/$HARNESS_BUILD_DIR"/*/; do
    [ -d "$directory" ] || continue
    directory="${directory%/}"
    [[ " $* " == *" ${directory##*/} "* ]] || rm -rf -- "$directory"
  done
}

# Centralizing: dotdot's Skills/ and Agents/ made (kept by a .gitkeep, as
# git tracks no empty folder), and the planned items moved in.
core.modules.setup.service::centralize() {
  local folder
  for folder in "$SETUP_SKILLS_DIR" "$SETUP_AGENTS_DIR"; do
    mkdir -p -- "$DOTDOT_ROOT/$folder" && touch -- "$DOTDOT_ROOT/$folder/$KEEP_FILE" \
      || { dot::raise "Couldn't create $DOTDOT_NAME/$folder/."; return 1; }
  done
  core.modules.setup.service::move
}

# Moves each planned item into dotdot; an agent in a harness's own format is
# imported into dotdot's, and the original removed. Then the duplicates go:
# link puts dotdot's copy in their place.
core.modules.setup.service::move() {
  local move from to id rest name duplicate
  for move in ${SETUP_MOVES[@]+"${SETUP_MOVES[@]}"}; do
    from="$BASE/${move%%"$SETUP_TAB"*}"
    rest="${move#*"$SETUP_TAB"}"
    to="$DOTDOT_ROOT/${rest%%"$SETUP_TAB"*}"
    id="${rest#*"$SETUP_TAB"}"
    mkdir -p -- "${to%/*}" || { dot::raise "Couldn't create $(dot::relative "${to%/*}")."; return 1; }
    if [[ "$to" == "$DOTDOT_ROOT/$SETUP_AGENTS_DIR/"* ]]; then
      name="${to##*/}"
      core.harnesses.capabilities.agents::import "$id" "${name%.md}" "$from" > "$to" && rm -f -- "$from" \
        || { rm -f -- "$to"; dot::raise "Couldn't take $(dot::relative "$from") into $(dot::relative "$to")."; return 1; }
    else
      mv -- "$from" "$to" || { dot::raise "Couldn't move $(dot::relative "$from") into $(dot::relative "$to")."; return 1; }
    fi
  done
  for duplicate in ${SETUP_DUPLICATES[@]+"${SETUP_DUPLICATES[@]}"}; do
    rm -rf -- "${BASE:?}/$duplicate" || { dot::raise "Couldn't remove $duplicate, a copy of what moved."; return 1; }
  done
}

# The values of a list setting, one per line.
core.modules.setup.service::list() {
  framework.helpers.json::values "$(core.modules.setup.service::state "$1" "[]")" '.[]'
}

# Lines as a JSON list of strings.
core.modules.setup.service::json_list() {
  local item list=""
  while IFS= read -r item; do
    [ -z "$item" ] || list="$list${list:+, }$(framework.helpers.json::string "$item")"
  done
  printf '[%s]' "$list"
}

# What only the agent can finish, from <type> and <rows> (the scan, the
# unsure docs included), less what it already finished: the context while
# dotdot isn't ready; with own, splitting each instructions file into
# dotdot's docs and checking that every harness still reads what moved; and
# the unsure docs, to raise with the user.
core.modules.setup.service::pending() {
  local type="$1" rows="$2" finished
  finished=$(core.modules.setup.service::list "$SETUP_DONE_SETTING")
  {
    [ "$(core.modules.setup.service::state "$SETUP_READY_SETTING" false)" = true ] || printf 'context\n'
    [ "$type" != centralize ] || printf '%s\n' "$rows" | awk -F '\t' '$2 == "instructions" { print "split:" $3 }'
    printf '%s\n' "$rows" | awk -F '\t' '$2 == "unsure" { print "unsure:" $3 }'
    [ "$type" != centralize ] || printf 'verify\n'
  } | awk -v done="$finished" 'BEGIN { n = split(done, d, "\n"); for (i = 1; i <= n; i++) skip[d[i]] = 1 } !($0 in skip) && !seen[$0]++'
}

# Marks <item> of what was left to the agent as finished; status 1 when it
# isn't left.
core.modules.setup.service::finish() {
  local item="$1" pending
  pending=$(core.modules.setup.service::list "$SETUP_PENDING_SETTING")
  printf '%s\n' "$pending" | grep -qxF -- "$item" || return 1
  dot::save_setting "$SETUP_PENDING_SETTING" "$(printf '%s\n' "$pending" | grep -vxF -- "$item" | core.modules.setup.service::json_list)" \
    && dot::save_setting "$SETUP_DONE_SETTING" "$({ core.modules.setup.service::list "$SETUP_DONE_SETTING"; printf '%s\n' "$item"; } | core.modules.setup.service::json_list)"
}

# The dot entry at the project's root, linked to dotdot's when it's missing
# or broken; one the project put there itself is left alone.
core.modules.setup.service::entry_link() {
  [ ! -e "$ENTRY_LINK" ] || return 0
  rm -f -- "$ENTRY_LINK" && ln -s -- "${DOT_BIN#"$BASE"/}" "$ENTRY_LINK" \
    || { dot::raise "Couldn't link $(dot::relative "$ENTRY_LINK") to dotdot." "Please run: ln -s ${DOT_BIN#"$BASE"/} dot"; return 1; }
}

# Saves the choice: the harnesses, the type, the rows written, and what
# is left for the agent.
core.modules.setup.service::save() {
  local harnesses="$1" type="$2" pending="$3"
  dot::save_setting "$SETUP_HARNESSES_SETTING" "$(printf '%s\n' $harnesses | core.modules.setup.service::json_list)" \
    && dot::save_setting "$SETUP_TYPE_SETTING" "$(framework.helpers.json::string "$type")" \
    && dot::save_setting "$SETUP_LINKS_SETTING" "{\"link\": $(core.modules.setup.service::object link "$SETUP_WANTED"), \"append\": $(core.modules.setup.service::object append "$SETUP_WANTED")}" \
    && dot::save_setting "$SETUP_PENDING_SETTING" "$(printf '%s\n' "$pending" | core.modules.setup.service::json_list)"
}
