#!/usr/bin/env bash
. "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"

# Golden

test_setup_links_every_chosen_harness() {
  dot setup --harness claude,agents --yes
  assert_success
  assert_link_to "$SANDBOX/AGENTS.md" "$DOTDOT/AGENTS.md"
  assert_no_file "$SANDBOX/.claude/CLAUDE.md"
  assert_link_to "$SANDBOX/.claude/skills/dot-onboard" "$DOTDOT/.core/modules/onboarding/skills/dot-onboard"
  assert_link_to "$SANDBOX/.agents/skills/dot-onboard" "$DOTDOT/.core/modules/onboarding/skills/dot-onboard"
  assert_equal "$(setting_value '.setup.harnesses[]' | tr '\n' ,)" "claude,agents"
}

test_setup_previews_the_plan_for_the_detected_harnesses() {
  own_instructions CLAUDE.md
  own_skill .claude/skills/mine
  cp "$DOTDOT/dot.json" "$SANDBOX/before.json"
  dot setup --preview
  assert_success
  assert_contains "$OUTPUT" "CLAUDE.md"
  assert_contains "$OUTPUT" ".claude/skills/"
  assert_not_contains "$OUTPUT" ".cursor/"
  assert_equal "$(cat "$DOTDOT/dot.json")" "$(cat "$SANDBOX/before.json")"
  assert_no_file "$SANDBOX/.claude/skills/dot-onboard"
}

test_combine_keeps_existing_files_and_imports_dotdot() {
  own_instructions CLAUDE.md
  own_skill .claude/skills/mine
  dot setup --harness claude --strategy combine --yes
  assert_success
  [ -f "$SANDBOX/CLAUDE.md" ] && [ ! -L "$SANDBOX/CLAUDE.md" ] || fail "CLAUDE.md is no longer the project's own file"
  assert_contains "$(cat "$SANDBOX/CLAUDE.md")" "Keep this line."
  assert_contains "$(cat "$SANDBOX/CLAUDE.md")" "@.dot/AGENTS.md"
  [ -d "$SANDBOX/.claude/skills/mine" ] && [ ! -L "$SANDBOX/.claude/skills/mine" ] || fail "the project's skill was moved"
  assert_link_to "$SANDBOX/.claude/skills/dot-onboard" "$DOTDOT/.core/modules/onboarding/skills/dot-onboard"
}

test_own_moves_skills_into_dotdot_and_links_them_back() {
  own_instructions CLAUDE.md
  own_skill .claude/skills/mine
  dot setup --harness claude --strategy own --yes
  assert_success
  assert_file "$DOTDOT/Skills/mine/SKILL.md"
  assert_link_to "$SANDBOX/.claude/skills/mine" "$DOTDOT/Skills/mine"
  assert_contains "$(cat "$SANDBOX/CLAUDE.md")" "@.dot/AGENTS.md"
  assert_equal "$(setting_value '.setup.strategy')" "own"
}

test_own_links_owned_skills_into_every_chosen_harness() {
  own_skill .claude/skills/mine
  dot setup --harness claude,agents --strategy own --yes
  assert_success
  assert_link_to "$SANDBOX/.agents/skills/mine" "$DOTDOT/Skills/mine"
}

test_own_previews_where_each_item_moves() {
  own_skill .claude/skills/mine
  dot setup --harness claude --strategy own --preview
  assert_success
  assert_contains "$OUTPUT" ".dot/Skills/mine"
  assert_no_file "$DOTDOT/Skills/mine"
}

# Edge

test_own_leaves_an_item_named_like_dotdots_in_place() {
  own_skill .claude/skills/dot-onboard
  own_skill .claude/skills/mine
  dot setup --harness claude --strategy own --yes
  assert_success
  [ -d "$SANDBOX/.claude/skills/dot-onboard" ] && [ ! -L "$SANDBOX/.claude/skills/dot-onboard" ] || fail "the clashing skill was moved"
  assert_no_file "$DOTDOT/Skills/dot-onboard"
  assert_contains "$OUTPUT$ERRORS" ".claude/skills/dot-onboard"
  assert_file "$DOTDOT/Skills/mine/SKILL.md"
}

test_preview_changes_nothing() {
  own_skill .claude/skills/mine
  cp "$DOTDOT/dot.json" "$SANDBOX/before.json"
  dot setup --harness claude --strategy own --preview
  assert_success
  assert_equal "$(cat "$DOTDOT/dot.json")" "$(cat "$SANDBOX/before.json")"
  assert_no_file "$SANDBOX/.claude/skills/dot-onboard"
  assert_no_file "$DOTDOT/Skills/mine"
}

test_setup_without_a_person_and_no_choice_stops_naming_the_flags() {
  dot setup
  assert_failure
  assert_equal "$STATUS" 5
}

test_setup_without_a_person_only_previews() {
  DOT_INTERNAL_CALL="" dot setup --harness claude
  assert_success
  assert_no_file "$SANDBOX/.claude/skills/dot-onboard"
}

test_rerunning_setup_unlinks_harnesses_no_longer_chosen() {
  own_instructions CLAUDE.md
  dot setup --harness claude,agents --yes
  dot setup --harness agents --yes
  assert_success
  assert_no_file "$SANDBOX/.claude/skills/dot-onboard"
  assert_not_contains "$(cat "$SANDBOX/CLAUDE.md")" "@.dot/AGENTS.md"
  assert_contains "$(cat "$SANDBOX/CLAUDE.md")" "Keep this line."
  assert_link_to "$SANDBOX/.agents/skills/dot-onboard" "$DOTDOT/.core/modules/onboarding/skills/dot-onboard"
  assert_equal "$(setting_value '.setup.harnesses[]')" "agents"
}

test_rechoosing_a_harness_links_it_again() {
  dot setup --harness claude --yes
  dot setup --harness agents --yes
  dot setup --harness claude --yes
  assert_success
  assert_link_to "$SANDBOX/.claude/skills/dot-onboard" "$DOTDOT/.core/modules/onboarding/skills/dot-onboard"
}

test_rerunning_setup_duplicates_nothing() {
  own_instructions CLAUDE.md
  dot setup --harness claude --yes
  dot setup --harness claude --yes
  assert_success
  assert_equal "$(grep -c '@.dot/AGENTS.md' "$SANDBOX/CLAUDE.md")" 1
  assert_equal "$(setting_value '.links["@dotdotSkills"][]' | grep -c '^.claude/skills/$')" 1
}

test_setup_unlinks_links_for_harnesses_not_chosen() {
  links "link:@dot:AGENTS.md->AGENTS.md" "link:@dotdotSkills->.claude/skills/"
  dot link -y
  assert_link_to "$SANDBOX/.claude/skills/dot-onboard" "$DOTDOT/.core/modules/onboarding/skills/dot-onboard"
  dot setup --harness agents --yes
  assert_success
  assert_no_file "$SANDBOX/.claude/skills/dot-onboard"
}

# Adversarial

test_own_never_moves_a_link_leading_out_of_the_project() {
  local outside
  outside=$(mktemp -d)
  printf -- '---\nname: away\n---\n' > "$outside/SKILL.md"
  mkdir -p "$SANDBOX/.claude/skills"
  ln -s "$outside" "$SANDBOX/.claude/skills/away"
  dot setup --harness claude --strategy own --yes
  [ -L "$SANDBOX/.claude/skills/away" ] && [ "$(readlink "$SANDBOX/.claude/skills/away")" = "$outside" ] || fail "the outside link was touched"
  assert_file "$outside/SKILL.md"
  rm -rf -- "$outside"
  assert_success
  assert_no_file "$DOTDOT/Skills/away"
}

test_an_unknown_harness_is_refused_with_the_valid_ones() {
  cp "$DOTDOT/dot.json" "$SANDBOX/before.json"
  dot setup --harness nope --yes
  assert_failure
  assert_equal "$STATUS" 2
  assert_contains "$ERRORS" "claude"
  assert_equal "$(cat "$DOTDOT/dot.json")" "$(cat "$SANDBOX/before.json")"
}

test_a_harness_name_with_a_path_is_refused() {
  dot setup --harness ../../etc --yes
  assert_failure
  assert_equal "$STATUS" 2
  assert_contains "$ERRORS" "claude"
}

test_an_unknown_strategy_is_refused() {
  dot setup --harness claude --strategy merge --yes
  assert_failure
  assert_equal "$STATUS" 2
  assert_no_file "$SANDBOX/.claude/skills/dot-onboard"
}

test_the_plan_groups_changes_by_folder_rather_than_listing_files() {
  dot setup --harness claude,cursor --preview
  assert_success
  assert_contains "$OUTPUT" ".claude/"
  assert_contains "$OUTPUT" ".cursor/"
  assert_not_contains "$OUTPUT" ".claude/skills/dot-onboard"
}

test_own_moves_a_skill_found_twice_once_and_links_its_copy() {
  own_skill .agents/skills/twice
  own_skill .claude/skills/twice
  dot setup --harness agents,claude --strategy own --yes
  assert_success
  assert_file "$DOTDOT/Skills/twice/SKILL.md"
  assert_no_file "$DOTDOT/Skills/twice/twice"
  assert_link_to "$SANDBOX/.agents/skills/twice" "$DOTDOT/Skills/twice"
  assert_link_to "$SANDBOX/.claude/skills/twice" "$DOTDOT/Skills/twice"
}

test_own_leaves_a_differing_copy_in_place() {
  own_skill .agents/skills/twice
  own_skill .claude/skills/twice
  printf 'changed\n' >> "$SANDBOX/.claude/skills/twice/SKILL.md"
  dot setup --harness agents,claude --strategy own --yes
  assert_success
  [ -d "$SANDBOX/.claude/skills/twice" ] && [ ! -L "$SANDBOX/.claude/skills/twice" ] || fail "the differing copy was replaced"
  assert_contains "$ERRORS" ".claude/skills/twice"
}

test_an_existing_agents_md_is_appended_to_not_linked() {
  own_instructions AGENTS.md
  dot link -y
  dot setup --harness claude --yes
  assert_success
  [ -f "$SANDBOX/AGENTS.md" ] && [ ! -L "$SANDBOX/AGENTS.md" ] || fail "AGENTS.md is no longer the project's own"
  assert_contains "$(cat "$SANDBOX/AGENTS.md")" "Keep this line."
  assert_equal "$(setting_value '.links["@dot:AGENTS.md"][]' | grep -cx 'AGENTS.md')" 0
}

test_setup_asks_where_dotdot_lives_only_when_agents_holds_more_than_skills() {
  local check="dot::use core.modules.setup.service; core.modules.setup.service::harnesses; core.modules.setup.service::agents_home_in_use"
  own_skill .agents/skills/mine
  core "$check"
  assert_failure
  : > "$SANDBOX/.agents/mcp.json"
  core "$check"
  assert_success
  rm "$SANDBOX/.agents/mcp.json"
  mkdir -p "$SANDBOX/.claude"
  ln -s ../.agents/skills "$SANDBOX/.claude/skills"
  core "$check"
  assert_success
}

test_centralizing_makes_dotdots_skills_and_agents_folders() {
  dot setup --harness claude --strategy own --yes
  assert_success
  assert_file "$DOTDOT/Skills/.gitkeep"
  assert_file "$DOTDOT/Agents/.gitkeep"
}

test_claude_imports_dotdot_into_the_claude_md_the_project_uses() {
  own_instructions .claude/CLAUDE.md
  dot setup --harness claude --yes
  assert_success
  assert_contains "$(cat "$SANDBOX/.claude/CLAUDE.md")" "@../.dot/AGENTS.md"
  assert_no_file "$SANDBOX/CLAUDE.md"
}

test_commands_point_a_person_at_setup_until_it_ran() {
  DOT_INTERNAL_CALL="" dot notes:create idea
  assert_success
  assert_contains "$ERRORS" "bash dot setup"
  dot setup --harness agents --yes
  DOT_INTERNAL_CALL="" dot notes:create other
  assert_not_contains "$ERRORS" "bash dot setup"
}
