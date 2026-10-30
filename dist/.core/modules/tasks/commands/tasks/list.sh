# shellcheck shell=bash

DESCRIPTION="List the project's tasks."
DOCS="tasks"
JSON=true

dot::use framework.console.args framework.helpers.fs framework.console.output core.modules.tasks.console core.modules.tasks.service framework.helpers.text framework.helpers.json

usage() {
  cat <<USAGE
Lists the project's tasks, oldest first, $TASK_PAGE_SIZE to a page.

Usage:
  bash dot tasks:list [options]

Options:
  -s, --status <status>    Only these, comma-separated:
                           $(core.modules.tasks.service::statuses | paste -sd ' ' -).
  --sort <date>            created or updated (default: created).
  --order <order>          asc or desc (default: asc).
  -l, --limit <n>          Tasks per page (default: $TASK_PAGE_SIZE; 0 for all).
  -p, --page <n>           The page to show (default: 1).
  --plain                  One task per line, tab-separated: id, status,
                           created, updated, title; no header.
  --json                   {"tasks": [...], "total", "page", "pages", "nextPage"}.
  -h, --help               Show this help.

Examples:
  bash dot tasks:list --status todo,doing,paused
  bash dot tasks:list --sort updated --order desc -l 5
  bash dot tasks:list --plain | cut -f1,5
USAGE
}

# The tasks in <rows>, from <first> to <last>, as the format asked for.
print_rows() {
  local rows="$1" first="$2" last="$3" format="$4" id status created updated title
  if [ "$format" = plain ]; then
    sed -n "${first},${last}p" "$rows"
    return
  fi
  if [ "$format" = json ]; then
    sed -n "${first},${last}p" "$rows" | while IFS=$'\t' read -r id status created updated title; do
      printf '{"id":%s,"status":%s,"created":%s,"updated":%s,"title":%s}\n' "$(framework.helpers.json::string "$id")" \
        "$(framework.helpers.json::string "$status")" "$(framework.helpers.json::string "$created")" \
        "$(framework.helpers.json::string "$updated")" "$(framework.helpers.json::string "$title")"
    done | paste -sd ',' -
    return
  fi
  framework.console.output::title "$(printf '%-8s %-10s %-19s  %-19s  %s' ID STATUS CREATED UPDATED TITLE)"
  sed -n "${first},${last}p" "$rows" | while IFS=$'\t' read -r id status created updated title; do
    printf '%-8s %-10s %-19s  %-19s  %s\n' "$id" "$status" "$created" "$updated" "$title"
  done
}

handle() {
  local work statuses="" sort=created order=asc limit page=1 status total size pages first last next="" format=table
  ! $DOT_JSON || format=json
  core.modules.tasks.console::ensure_service
  limit=$TASK_PAGE_SIZE
  while [ $# -gt 0 ]; do
    case "$1" in
      -p | --page)
        framework.console.args::require_value "$@"
        framework.console.args::is_number "$2" && [ "$((10#$2))" -ge 1 ] || framework.console.args::invalid "--page takes a number from 1."
        page=$((10#$2))
        shift 2
        ;;
      -s | --status)
        framework.console.args::require_value "$@"
        statuses=""
        while IFS= read -r status; do
          core.modules.tasks.service::is_status "$status" || framework.console.args::invalid "\"$status\" isn't a task status."
          statuses="$statuses $status"
        done < <(framework.console.args::split "$2")
        [ -n "$statuses" ] || framework.console.args::invalid "--status needs a value."
        statuses="$statuses "
        shift 2
        ;;
      --sort)
        framework.console.args::require_value "$@"
        core.modules.tasks.service::is_sort_column "$2" || framework.console.args::invalid "--sort takes created or updated."
        sort="$2"
        shift 2
        ;;
      --plain) format=plain; shift ;;
      -l | --limit)
        framework.console.args::require_value "$@"
        framework.console.args::is_number "$2" || framework.console.args::invalid "--limit takes a number (0 for all)."
        limit=$((10#$2))
        shift 2
        ;;
      --order)
        framework.console.args::require_value "$@"
        case "$2" in
          asc | desc) order="$2" ;;
          *) framework.console.args::invalid "--order takes asc or desc." ;;
        esac
        shift 2
        ;;
      *) framework.console.args::unexpected "$1" ;;
    esac
  done
  framework.helpers.fs::make_temp_dir work || framework.console.output::fail "Couldn't create a temporary directory; please check free space and \$TMPDIR."
  core.modules.tasks.console::call list > "$work/list" || exit
  core.modules.tasks.service::sort_rows "$work/list" "$statuses" "$sort" "$order" > "$work/rows"
  total=$(wc -l < "$work/rows" | tr -d ' ')
  size=$limit
  [ "$size" -gt 0 ] || size=$total
  pages=0
  [ "$total" -eq 0 ] || pages=$(( (total + size - 1) / size ))
  first=$(( (page - 1) * size + 1 ))
  last=$(( page * size < total ? page * size : total ))
  if [ "$format" = json ]; then
    [ "$page" -le "$pages" ] || last=0
    [ "$page" -ge "$pages" ] && next=null || next=$((page + 1))
    printf '{"tasks":[%s],"total":%s,"page":%s,"pages":%s,"nextPage":%s}\n' \
      "$([ "$last" -eq 0 ] || print_rows "$work/rows" "$first" "$last" json)" "$total" "$page" "$pages" "$next"
    return 0
  fi
  if [ "$total" -eq 0 ]; then
    [ "$format" = plain ] && return 0
    statuses=$(framework.helpers.text::trim "$statuses")
    framework.console.output::line "No tasks${statuses:+ with status ${statuses// /, }} yet."
    return 0
  fi
  if [ "$page" -gt "$pages" ]; then
    framework.console.output::warn "There's no page $page; the last one is --page $pages."
    return 0
  fi
  print_rows "$work/rows" "$first" "$last" "$format"
  [ "$format" = table ] && [ "$pages" -gt 1 ] || return 0
  [ "$page" -ge "$pages" ] || next=" · next: --page $((page + 1))"
  framework.console.output::line "$(framework.console.output::gray "Showing $first–$last of $total $UI_SEPARATOR page $page of $pages")$next"
}
