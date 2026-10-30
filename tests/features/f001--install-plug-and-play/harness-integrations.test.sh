# shellcheck shell=bash
. "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"

# Golden

test_every_shipped_harness_is_offered() {
  local harness
  dot adopt --scan --json
  assert_success
  for harness in claude codex cursor copilot opencode agents; do
    assert_contains "$(json_value "$OUTPUT" '.harnesses[].id')" "$harness"
  done
}

test_a_new_harness_folder_is_offered_and_linked_without_core_changes() {
  copy_harness agents acme
  harness_data acme name '"Acme"'
  harness_data acme detect '[".acme/"]'
  harness_data acme skills '".acme/skills/"'
  mkdir -p "$SANDBOX/.acme"
  dot adopt --scan --json
  assert_contains "$(json_value "$OUTPUT" '.detected[]')" "acme"
  dot setup --harness acme --yes
  assert_success
  assert_link_to "$SANDBOX/.acme/skills/dot-onboard" "$DOTDOT/.core/modules/onboarding/skills/dot-onboard"
}

test_changing_harness_data_links_its_new_place_and_leaves_the_old_row_to_the_user() {
  copy_harness agents acme
  harness_data acme skills '".acme/skills/"'
  dot setup --harness acme --yes
  harness_data acme skills '".acme/tools/"'
  dot setup --harness acme --yes
  assert_success
  assert_link_to "$SANDBOX/.acme/tools/dot-onboard" "$DOTDOT/.core/modules/onboarding/skills/dot-onboard"
  assert_equal "$(map_value '["@dotdotSkills"][]' | sort | tr '\n' ' ')" ".acme/skills/ .acme/tools/ "
}

# Edge

test_broken_harnesses_are_skipped_and_the_rest_work() {
  copy_harness agents broken
  printf '{ not json' > "$DOTDOT/.core/harnesses/broken/harness.json"
  copy_harness agents nameless
  harness_data nameless name 'null'
  dot adopt --scan --json
  assert_success
  assert_equal "$(json_value "$OUTPUT" '.invalid[]' | sort | paste -sd ' ' -)" "broken nameless"
  assert_not_contains "$(json_value "$OUTPUT" '.harnesses[].id')" "nameless"
  dot setup --harness claude --yes
  assert_success
  assert_link_to "$SANDBOX/.claude/skills/dot-onboard" "$DOTDOT/.core/modules/onboarding/skills/dot-onboard"
}

# Adversarial

test_harness_data_aimed_outside_the_project_is_refused() {
  copy_harness agents up && harness_data up skills '"../outside/"'
  copy_harness agents git && harness_data git skills '".git/hooks/"'
  copy_harness agents inner && harness_data inner skills '".dot/inner/"'
  copy_harness agents env && harness_data env skills '".env"'
  dot setup --harness up,git,inner,env --yes
  assert_no_file "$SANDBOX/../outside/dot-onboard"
  assert_no_file "$SANDBOX/.git/hooks/dot-onboard"
  assert_no_file "$DOTDOT/inner/dot-onboard"
  [ ! -L "$SANDBOX/.env" ] || fail ".env was linked"
}
