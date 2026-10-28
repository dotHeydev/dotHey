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
  dot tasks:update 1 --title "Write more tests" --done-when "- [x] kernel"
  assert_success
  assert_contains "$(cat "$file")" "title: Write more tests"
  assert_contains "$(cat "$file")" "- [x] kernel"
  assert_contains "$(cat "$file")" "Cover the kernel."
  dot tasks:get t001 --no-pager
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
  dot tasks:get t999
  assert_failure
  assert_contains "$ERRORS" "There's no task t999"
}

test_task_list_and_get_print_for_scripts_and_agents() {
  use_file_tasks
  dot tasks:list --plain
  assert_success
  assert_equal "$OUTPUT" ""
  dot tasks:list --json
  assert_equal "$(json_value "$OUTPUT" .total)" 0
  assert_equal "$(json_value "$OUTPUT" .nextPage)" ""
  dot tasks:create "First" --json
  assert_success
  assert_equal "$(json_value "$OUTPUT" .id)" t001
  dot tasks:create "Second"
  dot tasks:list --plain -l 1
  assert_equal "$(printf '%s\n' "$OUTPUT" | cut -f1,2,5)" $'t001\ttodo\tFirst'
  dot tasks:list --json --limit 1
  assert_equal "$(json_value "$OUTPUT" '.tasks[].title')" First
  assert_equal "$(json_value "$OUTPUT" .nextPage)" 2
  dot tasks:list -n 1
  assert_equal "$STATUS" 2
  dot tasks:get t002 --json
  assert_success
  assert_equal "$(json_value "$OUTPUT" .title)" Second
  assert_equal "$(json_value "$OUTPUT" .status)" todo
  dot tasks:update t002 "Positional title"
  assert_equal "$STATUS" 2
}

test_tasks_initialize_takes_the_service_as_a_flag() {
  sandbox::settings '"tasks": {"service": ""}'
  dot tasks:initialize
  assert_equal "$STATUS" 2
  assert_contains "$ERRORS" "--service <"
  dot tasks:initialize --service nope
  assert_equal "$STATUS" 2
  run env AI_AGENT=some-agent bash ./dot tasks:initialize --service file
  assert_success
  assert_contains "$OUTPUT" "Tasks will be kept in file."
  dot tasks:list
  assert_success
}
