# shellcheck shell=bash

test_feature_is_built_from_the_template() {
  local file
  hey features:create "Password reset" --description "Lets a user reset a password." --specification "Given a user"
  assert_success
  file="$DOTHEY/Features/f001--password-reset.md"
  assert_file "$file"
  assert_contains "$(cat "$file")" "description: Lets a user reset a password."
  assert_contains "$(cat "$file")" "Given a user"
}

