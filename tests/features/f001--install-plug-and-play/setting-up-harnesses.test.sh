# shellcheck shell=bash
. "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"

# Golden

test_setup_links_every_chosen_harness() {
  hey setup --harness claude,agents --yes
  assert_success
  assert_link_to "$SANDBOX/AGENTS.md" "$DOTHEY/AGENTS.md"
  assert_no_file "$SANDBOX/.claude/CLAUDE.md"
  assert_contains "$(cat "$SANDBOX/CLAUDE.md")" "@AGENTS.md"
  assert_link_to "$SANDBOX/.claude/skills/hey-onboard" "$DOTHEY/.core/modules/onboarding/skills/hey-onboard"
  assert_link_to "$SANDBOX/.agents/skills/hey-onboard" "$DOTHEY/.core/modules/onboarding/skills/hey-onboard"
  assert_equal "$(setting_value '.state.setup.harnesses[]' | tr '\n' ,)" "claude,agents"
}

test_setup_previews_the_plan_for_the_detected_harnesses() {
  own_instructions CLAUDE.md
  own_skill .claude/skills/mine
  cp "$DOTHEY/hey.json" "$SANDBOX/before.json"
  hey setup --preview
  assert_success
  assert_contains "$OUTPUT" "CLAUDE.md"
  assert_contains "$OUTPUT" ".claude/skills/"
  assert_not_contains "$OUTPUT" ".cursor/"
  assert_equal "$(cat "$DOTHEY/hey.json")" "$(cat "$SANDBOX/before.json")"
  assert_no_file "$SANDBOX/.claude/skills/hey-onboard"
}

test_parallel_keeps_existing_files_and_imports_dothey() {
  own_instructions CLAUDE.md
  own_skill .claude/skills/mine
  hey setup --harness claude --type parallel --yes
  assert_success
  [ -f "$SANDBOX/CLAUDE.md" ] && [ ! -L "$SANDBOX/CLAUDE.md" ] || fail "CLAUDE.md is no longer the project's own file"
  assert_contains "$(cat "$SANDBOX/CLAUDE.md")" "Keep this line."
  assert_contains "$(cat "$SANDBOX/CLAUDE.md")" "@AGENTS.md"
  [ -d "$SANDBOX/.claude/skills/mine" ] && [ ! -L "$SANDBOX/.claude/skills/mine" ] || fail "the project's skill was moved"
  assert_link_to "$SANDBOX/.claude/skills/hey-onboard" "$DOTHEY/.core/modules/onboarding/skills/hey-onboard"
}

test_centralize_moves_skills_into_dothey_and_links_them_back() {
  own_instructions CLAUDE.md
  own_skill .claude/skills/mine
  hey setup --harness claude --type centralize --yes
  assert_success
  assert_file "$DOTHEY/Skills/mine/SKILL.md"
  assert_link_to "$SANDBOX/.claude/skills/mine" "$DOTHEY/Skills/mine"
  assert_contains "$(cat "$SANDBOX/CLAUDE.md")" "@AGENTS.md"
  assert_equal "$(setting_value '.state.setup.type')" "centralize"
}

test_centralize_links_owned_skills_into_every_chosen_harness() {
  own_skill .claude/skills/mine
  hey setup --harness claude,agents --type centralize --yes
  assert_success
  assert_link_to "$SANDBOX/.agents/skills/mine" "$DOTHEY/Skills/mine"
}

test_centralize_previews_where_each_item_moves() {
  own_skill .claude/skills/mine
  hey setup --harness claude --type centralize --preview
  assert_success
  assert_contains "$OUTPUT" ".hey/Skills/mine"
  assert_no_file "$DOTHEY/Skills/mine"
}

# Edge

test_centralize_leaves_an_item_named_like_dotheys_in_place() {
  own_skill .claude/skills/hey-onboard
  own_skill .claude/skills/mine
  hey setup --harness claude --type centralize --yes
  assert_success
  [ -d "$SANDBOX/.claude/skills/hey-onboard" ] && [ ! -L "$SANDBOX/.claude/skills/hey-onboard" ] || fail "the clashing skill was moved"
  assert_no_file "$DOTHEY/Skills/hey-onboard"
  assert_contains "$OUTPUT$ERRORS" ".claude/skills/hey-onboard"
  assert_file "$DOTHEY/Skills/mine/SKILL.md"
}

test_preview_changes_nothing() {
  own_skill .claude/skills/mine
  cp "$DOTHEY/hey.json" "$SANDBOX/before.json"
  hey setup --harness claude --type centralize --preview
  assert_success
  assert_equal "$(cat "$DOTHEY/hey.json")" "$(cat "$SANDBOX/before.json")"
  assert_no_file "$SANDBOX/.claude/skills/hey-onboard"
  assert_no_file "$DOTHEY/Skills/mine"
}

test_setup_without_a_person_and_no_choice_stops_naming_the_flags() {
  hey setup
  assert_failure
  assert_equal "$STATUS" 5
}

test_setup_without_a_person_only_previews() {
  HEY_INTERNAL_CALL="" hey setup --harness claude
  assert_success
  assert_no_file "$SANDBOX/.claude/skills/hey-onboard"
}

test_rerunning_setup_unlinks_harnesses_no_longer_chosen() {
  own_instructions CLAUDE.md
  hey setup --harness claude,agents --yes
  hey setup --harness agents --yes
  assert_success
  assert_no_file "$SANDBOX/.claude/skills/hey-onboard"
  assert_not_contains "$(cat "$SANDBOX/CLAUDE.md")" "@AGENTS.md"
  assert_contains "$(cat "$SANDBOX/CLAUDE.md")" "Keep this line."
  assert_link_to "$SANDBOX/.agents/skills/hey-onboard" "$DOTHEY/.core/modules/onboarding/skills/hey-onboard"
  assert_equal "$(setting_value '.state.setup.harnesses[]')" "agents"
}

test_rechoosing_a_harness_links_it_again() {
  hey setup --harness claude --yes
  hey setup --harness agents --yes
  hey setup --harness claude --yes
  assert_success
  assert_link_to "$SANDBOX/.claude/skills/hey-onboard" "$DOTHEY/.core/modules/onboarding/skills/hey-onboard"
}

test_rerunning_setup_duplicates_nothing() {
  own_instructions CLAUDE.md
  hey setup --harness claude --yes
  hey setup --harness claude --yes
  assert_success
  assert_equal "$(grep -c '@AGENTS.md' "$SANDBOX/CLAUDE.md")" 1
  assert_equal "$(setting_value '.links["@dotheySkills"][]' | grep -c '^.claude/skills/$')" 1
}

test_setup_unlinks_links_for_harnesses_not_chosen() {
  links "link:@hey:AGENTS.md->AGENTS.md" "link:@dotheySkills->.claude/skills/"
  hey link -y
  assert_link_to "$SANDBOX/.claude/skills/hey-onboard" "$DOTHEY/.core/modules/onboarding/skills/hey-onboard"
  hey setup --harness agents --yes
  assert_success
  assert_no_file "$SANDBOX/.claude/skills/hey-onboard"
}

# Adversarial

test_centralize_never_moves_a_link_leading_out_of_the_project() {
  local outside
  outside=$(mktemp -d)
  printf -- '---\nname: away\n---\n' > "$outside/SKILL.md"
  mkdir -p "$SANDBOX/.claude/skills"
  ln -s "$outside" "$SANDBOX/.claude/skills/away"
  hey setup --harness claude --type centralize --yes
  [ -L "$SANDBOX/.claude/skills/away" ] && [ "$(readlink "$SANDBOX/.claude/skills/away")" = "$outside" ] || fail "the outside link was touched"
  assert_file "$outside/SKILL.md"
  rm -rf -- "$outside"
  assert_success
  assert_no_file "$DOTHEY/Skills/away"
}

test_an_unknown_harness_is_refused_with_the_valid_ones() {
  cp "$DOTHEY/hey.json" "$SANDBOX/before.json"
  hey setup --harness nope --yes
  assert_failure
  assert_equal "$STATUS" 2
  assert_contains "$ERRORS" "claude"
  assert_equal "$(cat "$DOTHEY/hey.json")" "$(cat "$SANDBOX/before.json")"
}

test_a_harness_name_with_a_path_is_refused() {
  hey setup --harness ../../etc --yes
  assert_failure
  assert_equal "$STATUS" 2
  assert_contains "$ERRORS" "claude"
}

test_an_unknown_type_is_refused() {
  hey setup --harness claude --type merge --yes
  assert_failure
  assert_equal "$STATUS" 2
  assert_no_file "$SANDBOX/.claude/skills/hey-onboard"
}

test_the_plan_groups_changes_by_folder_rather_than_listing_files() {
  hey setup --harness claude,kiro --preview
  assert_success
  assert_contains "$OUTPUT" ".claude/"
  assert_contains "$OUTPUT" ".kiro/"
  assert_not_contains "$OUTPUT" ".claude/skills/hey-onboard"
}

test_centralize_moves_a_skill_found_twice_once_and_links_its_copy() {
  own_skill .agents/skills/twice
  own_skill .claude/skills/twice
  hey setup --harness agents,claude --type centralize --yes
  assert_success
  assert_file "$DOTHEY/Skills/twice/SKILL.md"
  assert_no_file "$DOTHEY/Skills/twice/twice"
  assert_link_to "$SANDBOX/.agents/skills/twice" "$DOTHEY/Skills/twice"
  assert_link_to "$SANDBOX/.claude/skills/twice" "$DOTHEY/Skills/twice"
}

test_centralize_leaves_a_differing_copy_in_place() {
  own_skill .agents/skills/twice
  own_skill .claude/skills/twice
  printf 'changed\n' >> "$SANDBOX/.claude/skills/twice/SKILL.md"
  hey setup --harness agents,claude --type centralize --yes
  assert_success
  [ -d "$SANDBOX/.claude/skills/twice" ] && [ ! -L "$SANDBOX/.claude/skills/twice" ] || fail "the differing copy was replaced"
  assert_contains "$ERRORS" ".claude/skills/twice"
}

test_an_existing_agents_md_is_appended_to_not_linked() {
  own_instructions AGENTS.md
  hey link -y
  hey setup --harness claude --yes
  assert_success
  [ -f "$SANDBOX/AGENTS.md" ] && [ ! -L "$SANDBOX/AGENTS.md" ] || fail "AGENTS.md is no longer the project's own"
  assert_contains "$(cat "$SANDBOX/AGENTS.md")" "Keep this line."
  assert_equal "$(setting_value '.links["@hey:AGENTS.md"][]' | grep -cx 'AGENTS.md')" 0
}

test_setup_asks_where_dothey_lives_only_when_agents_holds_more_than_skills() {
  local check="hey::use core.modules.setup.service; core.modules.setup.service::harnesses; core.modules.setup.service::agents_home_in_use"
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

test_centralizing_makes_dotheys_skills_and_agents_folders() {
  hey setup --harness claude --type centralize --yes
  assert_success
  assert_file "$DOTHEY/Skills/.gitkeep"
  assert_file "$DOTHEY/Agents/.gitkeep"
}

test_claude_imports_dothey_into_the_claude_md_the_project_uses() {
  own_instructions .claude/CLAUDE.md
  hey setup --harness claude --yes
  assert_success
  assert_contains "$(cat "$SANDBOX/.claude/CLAUDE.md")" "@../AGENTS.md"
  assert_no_file "$SANDBOX/CLAUDE.md"
}

test_commands_point_a_person_at_setup_until_it_ran() {
  HEY_INTERNAL_CALL="" hey notes:create idea
  assert_success
  assert_contains "$ERRORS" "bash hey setup"
  hey setup --harness agents --yes
  HEY_INTERNAL_CALL="" hey notes:create other
  assert_not_contains "$ERRORS" "bash hey setup"
}

test_harnesses_that_read_agents_skills_are_linked_there_only() {
  hey setup --harness cursor,copilot --yes
  assert_success
  assert_link_to "$SANDBOX/.agents/skills/hey-onboard" "$DOTHEY/.core/modules/onboarding/skills/hey-onboard"
  assert_no_file "$SANDBOX/.cursor/skills"
  assert_no_file "$SANDBOX/.github/skills"
}

test_zed_gets_dothey_in_the_one_instructions_file_it_reads() {
  own_instructions .rules
  hey setup --harness zed --yes
  assert_success
  assert_contains "$(cat "$SANDBOX/.rules")" "Keep this line."
  assert_contains "$(cat "$SANDBOX/.rules")" "<!-- dothey -->"
}

test_junie_gets_dothey_in_its_centralize_agents_md_when_there_is_one() {
  own_instructions .junie/AGENTS.md
  hey setup --harness junie --yes
  assert_success
  assert_contains "$(cat "$SANDBOX/.junie/AGENTS.md")" "Keep this line."
  assert_contains "$(cat "$SANDBOX/.junie/AGENTS.md")" "<!-- dothey -->"
}

test_an_agent_may_apply_setup_with_yes() {
  HEY_INTERNAL_CALL="" AI_AGENT=1 hey setup --harness agents --yes
  assert_success
  assert_link_to "$SANDBOX/.agents/skills/hey-onboard" "$DOTHEY/.core/modules/onboarding/skills/hey-onboard"
}

test_yes_without_a_person_or_an_agent_is_refused() {
  HEY_INTERNAL_CALL="" HEY_NO_INPUT=1 hey setup --harness agents --yes
  assert_equal "$STATUS" 5
  assert_no_file "$SANDBOX/.agents/skills/hey-onboard"
}

test_setup_puts_back_a_missing_dot_entry_and_the_alias_finds_dothey() {
  rm -f "$SANDBOX/hey"
  run env SHELL=/bin/sh bash "$DOTHEY/.core/system/bin/hey" setup --harness agents --yes
  assert_success
  assert_link_to "$SANDBOX/hey" "$DOTHEY/.core/system/bin/hey"
  assert_contains "$OUTPUT" "echo .hey/.core/system/bin/hey"
  run env SHELL=/bin/sh bash ./hey setup --harness agents --dir .agents/.hey --yes
  assert_success
  assert_contains "$OUTPUT" "echo .agents/.hey/.core/system/bin/hey"
  run env SHELL=/bin/zsh bash ./hey setup --harness agents --yes
  assert_contains "$OUTPUT" "bash hey alias:add"
}

test_alias_add_writes_once_per_shell_and_remove_takes_it_back() {
  local shell file
  mkdir -p "$SANDBOX/home"
  printf 'export EDITOR=vi\n' > "$SANDBOX/home/.zshrc"
  for shell in bash zsh fish tcsh; do
    run env HOME="$SANDBOX/home" SHELL="/bin/$shell" ZDOTDIR="" XDG_CONFIG_HOME="" bash -c "cd '$SANDBOX' && bash ./hey alias:add -y && bash ./hey alias:add -y"
    assert_success
  done
  for file in .bashrc .zshrc .config/fish/config.fish .tcshrc; do
    [ "$(uname -s)" != Darwin ] || [ "$file" != .bashrc ] || file=.bash_profile
    assert_equal "$(grep -c '^alias hey' "$SANDBOX/home/$file")" 1
  done
  assert_contains "$(cat "$SANDBOX/home/.zshrc")" "export EDITOR=vi"
  assert_contains "$(cat "$SANDBOX/home/.config/fish/config.fish")" "(test -e hey; and echo hey; or echo .hey/.core/system/bin/hey)"
  printf 'keep me\n' >> "$SANDBOX/home/.zshrc"
  run env HOME="$SANDBOX/home" SHELL=/bin/zsh ZDOTDIR="" bash -c "cd '$SANDBOX' && bash ./hey alias:remove -y"
  assert_success
  assert_not_contains "$(cat "$SANDBOX/home/.zshrc")" "alias hey"
  assert_contains "$(cat "$SANDBOX/home/.zshrc")" "keep me"
  run env HOME="$SANDBOX/home" SHELL=/bin/zsh ZDOTDIR="" HEY_INTERNAL_CALL="" AI_AGENT=1 bash -c "cd '$SANDBOX' && bash ./hey alias:add -y"
  assert_equal "$STATUS" 5
}

test_alias_add_takes_the_shells_named_and_remove_clears_them_all() {
  mkdir -p "$SANDBOX/home"
  run env HOME="$SANDBOX/home" SHELL=/bin/zsh ZDOTDIR="" XDG_CONFIG_HOME="" bash -c "cd '$SANDBOX' && bash ./hey alias:add --shell fish,ksh -y"
  assert_success
  assert_no_file "$SANDBOX/home/.zshrc"
  assert_contains "$(cat "$SANDBOX/home/.kshrc")" "alias hey="
  assert_contains "$(cat "$SANDBOX/home/.config/fish/config.fish")" "alias hey "
  run env HOME="$SANDBOX/home" SHELL=/bin/zsh ZDOTDIR="" XDG_CONFIG_HOME="" bash -c "cd '$SANDBOX' && bash ./hey alias:add --shell powershell -y"
  assert_equal "$STATUS" 2
  run env HOME="$SANDBOX/home" SHELL=/bin/zsh ZDOTDIR="" XDG_CONFIG_HOME="" bash -c "cd '$SANDBOX' && bash ./hey alias:remove -y"
  assert_success
  assert_not_contains "$(cat "$SANDBOX/home/.kshrc")$(cat "$SANDBOX/home/.config/fish/config.fish")" "alias hey"
}

test_alias_add_writes_through_a_linked_rc_file() {
  mkdir -p "$SANDBOX/home" "$SANDBOX/dotfiles"
  : > "$SANDBOX/dotfiles/zshrc"
  ln -s ../dotfiles/zshrc "$SANDBOX/home/.zshrc"
  run env HOME="$SANDBOX/home" SHELL=/bin/zsh ZDOTDIR="" bash -c "cd '$SANDBOX' && bash ./hey alias:add -y"
  assert_success
  [ -L "$SANDBOX/home/.zshrc" ] || fail "the rc file's link was replaced"
  assert_contains "$(cat "$SANDBOX/dotfiles/zshrc")" "alias hey="
}
