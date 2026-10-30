# shellcheck shell=bash

DESCRIPTION="Plain Markdown files in .dot/Tasks/ (t001--slug.md)."

dot::use framework.helpers.date framework.helpers.frontmatter framework.helpers.fs framework.helpers.record framework.helpers.text

TASK_SLUG_LIMIT=60
TASK_FALLBACK_SLUG="task"

core.modules.tasks.drivers.file::file() {
  local number matches=() file
  number=$(framework.helpers.record::normalize "$1") || dot::abort "\"$1\" isn't a task id (like t004)."
  for file in "$TASKS_DIR/$TASK_PREFIX$number$RECORD_SEPARATOR"*"$RECORD_EXTENSION"; do
    [ -f "$file" ] && matches+=("$file")
  done
  [ ${#matches[@]} -gt 0 ] || dot::abort_as "$EXIT_NOT_FOUND" "There's no task $TASK_PREFIX$number." "See them all: bash dot tasks:list"
  [ ${#matches[@]} -eq 1 ] || dot::abort "Found more than one file for task $TASK_PREFIX$number in $(dot::relative "$TASKS_DIR")/; please keep one."
  printf '%s\n' "${matches[0]}"
}

core.modules.tasks.drivers.file::write() {
  local file="$1" title="$2" status="$3" created="$4" updated="$5" body="$6"
  {
    printf -- '---\ntitle: %s\nstatus: %s\ncreated: %s\nupdated: %s\n---\n\n' "$title" "$status" "$created" "$updated"
    cat -- "$body"
  } | framework.helpers.fs::write "$file"
}

core.modules.tasks.drivers.file::row() {
  local file="$1"
  printf '%s\t%s\t%s\t%s\t%s\n' "$(framework.helpers.record::id "$TASK_PREFIX" "$file")" \
    "$(framework.helpers.frontmatter::field "$file" status)" "$(framework.helpers.frontmatter::field "$file" created)" \
    "$(framework.helpers.frontmatter::field "$file" updated)" "$(framework.helpers.frontmatter::field "$file" title)"
}

core.modules.tasks.drivers.file::rewrite() {
  local file="$1" title="$2" status="$3" body="$4" kept
  if [ -z "$body" ]; then
    framework.helpers.fs::make_temp_file kept || return 1
    framework.helpers.frontmatter::body "$file" > "$kept"
    body="$kept"
  fi
  core.modules.tasks.drivers.file::write "$file" "$title" "$status" "$(framework.helpers.frontmatter::field "$file" created)" "$(framework.helpers.date::now)" "$body"
  [ -z "${kept-}" ] || rm -f -- "$kept"
}

core.modules.tasks.drivers.file::configure() {
  mkdir -p -- "$TASKS_DIR" || dot::abort "Couldn't create $(dot::relative "$TASKS_DIR")/."
}

core.modules.tasks.drivers.file::create() {
  local title="$1" status="$2" body="$3" slug path stamp
  slug=$(framework.helpers.text::slug "$title" "$TASK_SLUG_LIMIT")
  path=$(framework.helpers.record::next_path "$TASKS_DIR" "$TASK_PREFIX" "${slug:-$TASK_FALLBACK_SLUG}") \
    || dot::abort "Couldn't create the task file in $(dot::relative "$TASKS_DIR")/; please try again."
  stamp=$(framework.helpers.date::now)
  core.modules.tasks.drivers.file::write "$path" "$title" "$status" "$stamp" "$stamp" "$body"
  framework.helpers.record::id "$TASK_PREFIX" "$path"
  printf '\n'
}

core.modules.tasks.drivers.file::list() {
  local file
  while IFS= read -r file; do
    core.modules.tasks.drivers.file::row "$file"
  done < <(framework.helpers.record::files "$TASKS_DIR" "$TASK_PREFIX")
}

core.modules.tasks.drivers.file::show() {
  local file
  file=$(core.modules.tasks.drivers.file::file "$1") || return
  core.modules.tasks.drivers.file::row "$file"
  framework.helpers.frontmatter::body "$file"
}

core.modules.tasks.drivers.file::update() {
  local file title
  file=$(core.modules.tasks.drivers.file::file "$1") || return
  title="${2:-$(framework.helpers.frontmatter::field "$file" title)}"
  core.modules.tasks.drivers.file::rewrite "$file" "$title" "$(framework.helpers.frontmatter::field "$file" status)" "$3"
}

core.modules.tasks.drivers.file::status() {
  local file
  file=$(core.modules.tasks.drivers.file::file "$1") || return
  core.modules.tasks.drivers.file::rewrite "$file" "$(framework.helpers.frontmatter::field "$file" title)" "$2" ""
}

core.modules.tasks.drivers.file::delete() {
  local file
  file=$(core.modules.tasks.drivers.file::file "$1") || return
  rm -f -- "$file"
}

core.modules.tasks.drivers.file::link() {
  local file
  file=$(core.modules.tasks.drivers.file::file "$1") || return
  dot::relative "$file"
}
