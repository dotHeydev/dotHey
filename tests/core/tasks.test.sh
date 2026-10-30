# shellcheck shell=bash

use_file_tasks() {
  sandbox::settings '"tasks": {"service": "file"}'
}

test_tasks_need_initialization_at_a_terminal() {
  sandbox::settings '"tasks": {"service": ""}'
  hey tasks:list
  assert_failure
  assert_equal "$STATUS" 5
  assert_contains "$ERRORS" "tasks:initialize"
}

test_github_tasks_need_their_repository_setting() {
  sandbox::settings '"tasks": {"service": "github"}'
  mkdir -p "$SANDBOX/bin"
  printf '#!/bin/sh\nexit 0\n' > "$SANDBOX/bin/gh"
  chmod +x "$SANDBOX/bin/gh"
  run env PATH="$SANDBOX/bin:$PATH" bash ./hey tasks:list
  assert_failure
  assert_equal "$STATUS" 1
}

test_task_lifecycle_with_files() {
  local file
  use_file_tasks
  hey tasks:create "Write tests" --description "Cover the kernel."
  assert_success
  assert_contains "$OUTPUT" "t001"
  file="$DOTHEY/Tasks/t001--write-tests.md"
  assert_file "$file"
  assert_contains "$(cat "$file")" "Cover the kernel."
  hey tasks:doing t001
  assert_success
  assert_contains "$(cat "$file")" "status: doing"
  hey tasks:update 1 --title "Write more tests" --done-when "- [x] kernel"
  assert_success
  assert_contains "$(cat "$file")" "title: Write more tests"
  assert_contains "$(cat "$file")" "- [x] kernel"
  assert_contains "$(cat "$file")" "Cover the kernel."
  hey tasks:get t001 --no-pager
  assert_success
  assert_contains "$OUTPUT" "id: t001"
  hey tasks:list --status doing
  assert_success
  assert_contains "$OUTPUT" "Write more tests"
  hey tasks:list --status "done"
  assert_success
}

test_task_list_pages() {
  local index
  use_file_tasks
  for index in 1 2 3; do
    hey tasks:create "Task $index" --no-edit
  done
  hey tasks:list --limit 2 --page 2
  assert_success
  assert_contains "$OUTPUT" "Task 3"
  assert_not_contains "$OUTPUT" "Task 1"
  hey tasks:list --limit 2 --page 9
  assert_success
  assert_equal "$OUTPUT" ""
}

test_task_delete_needs_a_terminal() {
  use_file_tasks
  hey tasks:create "Keep me"
  hey tasks:delete t001
  assert_failure
  assert_equal "$STATUS" 5
  assert_file "$DOTHEY/Tasks/t001--keep-me.md"
}

test_unknown_tasks_fail_without_side_effects() {
  use_file_tasks
  hey tasks:doing t999
  assert_failure
  assert_equal "$STATUS" 4
  hey tasks:get t999
  assert_failure
  assert_equal "$STATUS" 4
}

test_task_list_and_get_print_for_scripts_and_agents() {
  use_file_tasks
  hey tasks:list --plain
  assert_success
  assert_equal "$OUTPUT" ""
  hey tasks:list --json
  assert_equal "$(json_value "$OUTPUT" .total)" 0
  assert_equal "$(json_value "$OUTPUT" .nextPage)" ""
  hey tasks:create "First" --json
  assert_success
  assert_equal "$(json_value "$OUTPUT" .id)" t001
  hey tasks:create "Second"
  hey tasks:list --plain -l 1
  assert_equal "$(printf '%s\n' "$OUTPUT" | cut -f1,2,5)" $'t001\ttodo\tFirst'
  hey tasks:list --json --limit 1
  assert_equal "$(json_value "$OUTPUT" '.tasks[].title')" First
  assert_equal "$(json_value "$OUTPUT" .nextPage)" 2
  hey tasks:list -n 1
  assert_equal "$STATUS" 2
  hey tasks:get t002 --json
  assert_success
  assert_equal "$(json_value "$OUTPUT" .title)" Second
  assert_equal "$(json_value "$OUTPUT" .status)" todo
  hey tasks:update t002 "Positional title"
  assert_equal "$STATUS" 2
}

test_tasks_initialize_takes_the_service_as_a_flag() {
  sandbox::settings '"tasks": {"service": ""}'
  hey tasks:initialize
  assert_equal "$STATUS" 2
  hey tasks:initialize --service nope
  assert_equal "$STATUS" 2
  run env AI_AGENT=some-agent bash ./hey tasks:initialize --service file
  assert_success
  core "hey::setting tasks.service"; assert_equal "$OUTPUT" "file"
  hey tasks:list
  assert_success
}
