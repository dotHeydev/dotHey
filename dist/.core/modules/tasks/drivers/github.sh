#!/usr/bin/env bash

DESCRIPTION="GitHub issues with the task label, through gh or DOT_GH_TOKEN."

dot::use framework.helpers.date framework.helpers.json framework.integrations.github.service

TASK_LABEL="task"
TASK_LABEL_COLOR="EDEDED"
TASK_STATUS_LABEL_PREFIX="task:"
TASK_CLOSED_STATUSES=" done discarded "
TASK_DISCARDED_STATUS="discarded"
TASK_REPOSITORY_SETTING="tasks.githubRepo"
TASK_ISSUE_LIMIT=1000

core.modules.tasks.drivers.github::status_color() {
  case "$1" in
    todo) printf '8250DF\n' ;;
    doing) printf '0969DA\n' ;;
    paused) printf 'FBCA04\n' ;;
    done) printf '1A7F37\n' ;;
    discarded) printf '6E7781\n' ;;
    *) printf 'BFD4F2\n' ;;
  esac
}

core.modules.tasks.drivers.github::repository() {
  local repository
  repository=$(dot::setting "$TASK_REPOSITORY_SETTING") || return 1
  framework.integrations.github.service::is_repository "$repository" \
    || dot::abort "$TASK_REPOSITORY_SETTING \"$repository\" isn't an <owner>/<name> repo."
  printf '%s\n' "$repository"
}

core.modules.tasks.drivers.github::number() {
  local number="${1#\#}"
  [[ "$number" =~ ^[0-9]+$ ]] || dot::abort "\"$1\" isn't an issue number (like #12)."
  printf '%s\n' "$number"
}

# The service's issue rows as task rows: #<number>, the status its labels
# give (or done or todo by its state), created and updated in local time,
# title.
core.modules.tasks.drivers.github::task_rows() {
  local number state labels created updated title status label
  while IFS=$'\t' read -r number state labels created updated title; do
    [ -n "$number" ] || continue
    status=""
    for label in $(printf '%s' "$labels" | tr ',' ' '); do
      case "$label" in
        "$TASK_STATUS_LABEL_PREFIX"*) status="${label#"$TASK_STATUS_LABEL_PREFIX"}"; break ;;
      esac
    done
    [ -n "$status" ] || { [ "$state" = CLOSED ] && status="done" || status="todo"; }
    printf '#%s\t%s\t%s\t%s\t%s\n' "$number" "$status" "$(framework.helpers.date::from_iso "$created")" "$(framework.helpers.date::from_iso "$updated")" "$title"
  done
}

# An issue's service row, refused unless it is a task.
core.modules.tasks.drivers.github::task_issue() {
  local repository="$1" number="$2" row labels
  row=$(framework.integrations.github.service::issue "$repository" "$number") || return 1
  labels=$(printf '%s' "$row" | cut -f3)
  [[ ",$labels," == *",$TASK_LABEL,"* ]] \
    || dot::abort "Issue #$number isn't a task (it has no \"$TASK_LABEL\" label), so it was left alone."
  printf '%s\n' "$row"
}

core.modules.tasks.drivers.github::is_closed_status() {
  case "$TASK_CLOSED_STATUSES" in
    *" $1 "*) return 0 ;;
  esac
  return 1
}

# Sets a task's status on its issue (whose service row is <row>): one
# task:<status> label, and the issue open, or closed for a closed status.
core.modules.tasks.drivers.github::apply_status() {
  local repository="$1" number="$2" status="$3" row="$4" state labels label removed="" added=""
  state=$(printf '%s' "$row" | cut -f2)
  labels=$(printf '%s' "$row" | cut -f3)
  for label in $(printf '%s' "$labels" | tr ',' ' '); do
    case "$label" in
      "$TASK_STATUS_LABEL_PREFIX"*) [ "$label" = "$TASK_STATUS_LABEL_PREFIX$status" ] || removed="${removed:+$removed,}$label" ;;
    esac
  done
  [[ ",$labels," == *",$TASK_STATUS_LABEL_PREFIX$status,"* ]] || added="$TASK_STATUS_LABEL_PREFIX$status"
  if [ -n "$removed$added" ]; then
    framework.integrations.github.service::label_issue "$repository" "$number" "$added" "$removed" || return 1
  fi
  if ! core.modules.tasks.drivers.github::is_closed_status "$status"; then
    [ "$state" = OPEN ] || framework.integrations.github.service::reopen_issue "$repository" "$number"
    return
  fi
  if [ "$state" = CLOSED ] && [ -n "$removed" ]; then
    framework.integrations.github.service::reopen_issue "$repository" "$number" || return 1
    state=OPEN
  fi
  [ "$state" != OPEN ] || framework.integrations.github.service::close_issue "$repository" "$number" \
    "$([ "$status" = "$TASK_DISCARDED_STATUS" ] && printf not_planned || printf completed)"
}

core.modules.tasks.drivers.github::is_authenticated() {
  framework.integrations.github.service::is_ready
}

core.modules.tasks.drivers.github::detected_repository() {
  framework.integrations.github.service::repository_of "$BASE"
}

core.modules.tasks.drivers.github::check_repository() {
  framework.integrations.github.service::is_repository "$1" || dot::abort "\"${1:-}\" isn't an <owner>/<name> repo."
  framework.integrations.github.service::can_reach "$1"
}

core.modules.tasks.drivers.github::managed_labels() {
  local status
  printf '%s\n' "$TASK_LABEL"
  while IFS= read -r status; do
    printf '%s%s\n' "$TASK_STATUS_LABEL_PREFIX" "$status"
  done < <(core.modules.tasks.service::statuses)
}

core.modules.tasks.drivers.github::configure() {
  local repository="$1" status
  framework.integrations.github.service::save_label "$repository" "$TASK_LABEL" "$TASK_LABEL_COLOR" "Managed by dotdot tasks" || return 1
  while IFS= read -r status; do
    framework.integrations.github.service::save_label "$repository" "$TASK_STATUS_LABEL_PREFIX$status" \
      "$(core.modules.tasks.drivers.github::status_color "$status")" "dot task: $status" || return 1
  done < <(core.modules.tasks.service::statuses)
  dot::save_setting "$TASK_REPOSITORY_SETTING" "$(framework.helpers.json::string "$repository")"
}

core.modules.tasks.drivers.github::create() {
  local title="$1" status="$2" body="$3" repository number row
  repository=$(core.modules.tasks.drivers.github::repository) || return 1
  number=$(framework.integrations.github.service::create_issue "$repository" "$title" "$body" "$TASK_LABEL") || return 1
  [[ "$number" =~ ^[0-9]+$ ]] || dot::abort "GitHub answered unexpectedly while creating the issue."
  row=$(framework.integrations.github.service::issue "$repository" "$number") || return 1
  core.modules.tasks.drivers.github::apply_status "$repository" "$number" "$status" "$row" || return 1
  printf '#%s\n' "$number"
}

core.modules.tasks.drivers.github::list() {
  local repository rows
  repository=$(core.modules.tasks.drivers.github::repository) || return 1
  rows=$(framework.integrations.github.service::issues "$repository" "$TASK_LABEL" "$TASK_ISSUE_LIMIT") || return 1
  printf '%s\n' "$rows" | core.modules.tasks.drivers.github::task_rows
}

core.modules.tasks.drivers.github::show() {
  local repository number row
  repository=$(core.modules.tasks.drivers.github::repository) || return 1
  number=$(core.modules.tasks.drivers.github::number "$1") || return 1
  row=$(core.modules.tasks.drivers.github::task_issue "$repository" "$number") || return 1
  printf '%s\n' "$row" | core.modules.tasks.drivers.github::task_rows
  framework.integrations.github.service::issue_body "$repository" "$number"
}

core.modules.tasks.drivers.github::update() {
  local repository number
  repository=$(core.modules.tasks.drivers.github::repository) || return 1
  number=$(core.modules.tasks.drivers.github::number "$1") || return 1
  core.modules.tasks.drivers.github::task_issue "$repository" "$number" >/dev/null || return 1
  framework.integrations.github.service::edit_issue "$repository" "$number" "$2" "$3"
}

core.modules.tasks.drivers.github::status() {
  local repository number row
  repository=$(core.modules.tasks.drivers.github::repository) || return 1
  number=$(core.modules.tasks.drivers.github::number "$1") || return 1
  row=$(core.modules.tasks.drivers.github::task_issue "$repository" "$number") || return 1
  core.modules.tasks.drivers.github::apply_status "$repository" "$number" "$2" "$row"
}

core.modules.tasks.drivers.github::delete() {
  local repository number
  repository=$(core.modules.tasks.drivers.github::repository) || return 1
  number=$(core.modules.tasks.drivers.github::number "$1") || return 1
  core.modules.tasks.drivers.github::task_issue "$repository" "$number" >/dev/null || return 1
  framework.integrations.github.service::delete_issue "$repository" "$number"
}

core.modules.tasks.drivers.github::link() {
  local repository number
  repository=$(core.modules.tasks.drivers.github::repository) || return 1
  number=$(core.modules.tasks.drivers.github::number "$1") || return 1
  printf '%s/issues/%s\n' "$(framework.integrations.github.service::url "$repository")" "$number"
}
