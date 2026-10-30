# shellcheck shell=bash
. "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"

# Golden

test_the_help_opens_with_the_release() {
  installed_release
  hey
  assert_success
  assert_equal "$(printf '%s\n' "$OUTPUT" | grep -m1 '^dotHey')" "dotHey (v$RELEASE)"
  hey --help
  assert_contains "$OUTPUT" "dotHey (v$RELEASE)"
}

test_the_version_shows_the_release_and_the_json_the_commit_too() {
  installed_release
  core "hey::save_state commit '\"$COMMIT\"'"
  hey -v
  assert_success
  assert_equal "$OUTPUT" "dotHey $RELEASE"
  hey -v --json
  assert_equal "$(json_value "$OUTPUT" .version)" "$RELEASE"
  assert_equal "$(json_value "$OUTPUT" .commit)" "$COMMIT"
}

# Edge

test_without_a_release_the_help_says_unreleased() {
  core "hey::save_state version '\"\"'"
  hey
  assert_success
  assert_equal "$(printf '%s\n' "$OUTPUT" | grep -m1 '^dotHey')" "dotHey (unreleased)"
}

test_a_release_that_isnt_a_version_is_not_shown() {
  core "hey::save_state version '\"latest\"'"
  hey
  assert_success
  assert_equal "$(printf '%s\n' "$OUTPUT" | grep -m1 '^dotHey')" "dotHey (unreleased)"
}

test_without_a_commit_the_json_has_none() {
  installed_release
  hey -v --json
  assert_success
  assert_equal "$OUTPUT" "{\"version\":\"$RELEASE\",\"commit\":null}"
}

# Adversarial

test_a_release_with_terminal_codes_is_not_shown() {
  core "hey::save_state version '\"1.0.0\\u001b[31m\"'"
  hey -v
  assert_success
  assert_equal "$OUTPUT" "dotHey (unreleased)"
}

# An upstream repo whose one commit ships <hey.json> in the source; prints it.
upstream_with() {
  local upstream="$SANDBOX/upstream"
  mkdir -p "$upstream/$SOURCE_NAME/.core"
  git init -q "$upstream"
  printf '%s\n' "$1" > "$upstream/$SOURCE_NAME/hey.json"
  git -C "$upstream" add -A
  git -C "$upstream" -c user.name=t -c user.email=t@t -c commit.gpgsign=false commit -qm release
  git -C "$upstream" rev-parse HEAD
}

test_an_upgrade_records_the_release_and_commit_it_brings() {
  local shipped
  shipped=$(upstream_with '{"state": {"version": "9.8.7", "commit": ""}}')
  core "hey::use core.system.update.service; UPDATE_REPOSITORY='$SANDBOX/upstream'; core.system.update.service::record_version $shipped"
  assert_success
  assert_equal "$(setting_value '.state.version')" "9.8.7"
  assert_equal "$(setting_value '.state.commit')" "$shipped"
}

test_an_upgrade_to_a_commit_shipping_no_release_records_none() {
  local shipped
  shipped=$(upstream_with '{"state": {"version": "next"}}')
  core "hey::use core.system.update.service; UPDATE_REPOSITORY='$SANDBOX/upstream'; core.system.update.service::record_version $shipped"
  assert_success
  assert_equal "$(setting_value '.state.version')" ""
  assert_equal "$(setting_value '.state.commit')" "$shipped"
}

test_the_setup_notice_stands_apart_from_the_help() {
  hey
  assert_success
  assert_equal "$(printf '%s\n' "$ERRORS" | tail -n 1)" ""
}
