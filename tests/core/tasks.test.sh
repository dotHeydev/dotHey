#!/usr/bin/env bash

use_file_tasks() {
  sandbox::settings '"tasks": {"service": "file"}'
}

test_tasks_need_initialization_at_a_terminal() {
  sandbox::settings '"tasks": {"service": ""}'
  dot tasks:list
  assert_failure
  assert_contains "$ERRORS" "tasks:initialize"
}

test_github_tasks_need_their_repository_setting() {
  sandbox::settings '"tasks": {"service": "github"}'
  mkdir -p "$SANDBOX/bin"
  printf '#!/bin/sh\nexit 0\n' > "$SANDBOX/bin/gh"
  chmod +x "$SANDBOX/bin/gh"
  run env PATH="$SANDBOX/bin:$PATH" bash ./dot tasks:list
  assert_failure
  assert_contains "$ERRORS" "The setting tasks.githubRepo isn't set yet."
}

test_task_lifecycle_with_files() {
  local file
  use_file_tasks
  dot tasks:create "Write tests" --description "Cover the kernel."
  assert_success
  assert_contains "$OUTPUT" "Created task t001 • Write tests (todo)"
  file="$DOTDOT/Tasks/t001--write-tests.md"
  assert_file "$file"
  assert_contains "$(cat "$file")" "Cover the kernel."
  dot tasks:doing t001
  assert_success
  assert_contains "$(cat "$file")" "status: doing"
  dot tasks:update 1 "Write more tests" --done-when "- [x] kernel"
  assert_success
  assert_contains "$(cat "$file")" "title: Write more tests"
  assert_contains "$(cat "$file")" "- [x] kernel"
  assert_contains "$(cat "$file")" "Cover the kernel."
  dot tasks:show t001 --no-pager
  assert_success
  assert_contains "$OUTPUT" "id: t001"
  dot tasks:list --status doing
  assert_success
  assert_contains "$OUTPUT" "Write more tests"
  dot tasks:list --status "done"
  assert_contains "$OUTPUT" "No tasks with status done yet."
}

test_task_list_pages() {
  local index
  use_file_tasks
  for index in 1 2 3; do
    dot tasks:create "Task $index" --no-edit
  done
  dot tasks:list --limit 2 --page 2
  assert_success
  assert_contains "$OUTPUT" "Task 3"
  assert_not_contains "$OUTPUT" "Task 1"
  assert_contains "$OUTPUT" "page 2 of 2"
  dot tasks:list --limit 2 --page 9
  assert_contains "$ERRORS" "the last one is --page 2"
}

test_task_input_is_validated() {
  use_file_tasks
  dot tasks:create
  assert_failure
  assert_contains "$ERRORS" "The task needs a title."
  dot tasks:create "x" --status nonsense
  assert_failure
  assert_contains "$ERRORS" "\"nonsense\" isn't a task status."
  dot tasks:update t001
  assert_failure
  assert_contains "$ERRORS" "Nothing to change"
  dot tasks:list --status ""
  assert_failure
  assert_contains "$ERRORS" "--status needs a value"
  dot tasks:create "x" --body-file ../../etc/passwd
  assert_failure
  assert_contains "$ERRORS" "must be a file in the project"
}

test_task_delete_needs_a_terminal() {
  use_file_tasks
  dot tasks:create "Keep me"
  dot tasks:delete t001
  assert_failure
  assert_file "$DOTDOT/Tasks/t001--keep-me.md"
}

test_unknown_tasks_fail_without_side_effects() {
  use_file_tasks
  dot tasks:doing t999
  assert_failure
  assert_contains "$ERRORS" "There's no task t999"
  dot tasks:show t999
  assert_failure
  assert_contains "$ERRORS" "There's no task t999"
}
