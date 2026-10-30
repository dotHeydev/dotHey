# shellcheck shell=bash

skill_paths() {
  find "$DOTHEY"/.core/system/*/skills "$DOTHEY"/.core/modules/*/skills -mindepth 1 -maxdepth 1 -type d
}

test_link_links_and_seeds() {
  hey link -y
  assert_success
  assert_link_to "$SANDBOX/AGENTS.md" "$DOTHEY/AGENTS.md"
  assert_file "$DOTHEY/USER.md"
}

# Every link in the project outside dotHey, with its target.
link_state() {
  find "$SANDBOX" -path "$DOTHEY" -prune -o -type l -print | sort | while IFS= read -r link; do
    printf '%s -> %s\n' "$link" "$(readlink "$link")"
  done
}

test_link_is_idempotent() {
  local before
  hey link -y
  before=$(link_state)
  hey link -y
  assert_success
  assert_equal "$(link_state)" "$before"
}

test_link_only_previews_without_a_terminal_or_with_preview() {
  hey link
  assert_success
  assert_no_file "$SANDBOX/AGENTS.md"
  HEY_INTERNAL_CALL="" hey link --preview -y
  assert_failure
  assert_equal "$STATUS" 5
  hey link --dry-run
  assert_success
  assert_no_file "$SANDBOX/AGENTS.md"
}

test_link_prunes_broken_dothey_links_and_keeps_foreign_ones() {
  links "link:@hey:AGENTS.md->AGENTS.md" "link:@dotheySkills->.claude/skills/"
  hey link -y
  ln -s ../../.hey/.core/system/link/skills/removed-skill "$SANDBOX/.claude/skills/removed-skill"
  ln -s /nonexistent/elsewhere "$SANDBOX/.claude/skills/foreign"
  hey link -y
  assert_success
  assert_no_file "$SANDBOX/.claude/skills/removed-skill"
  [ -L "$SANDBOX/.claude/skills/foreign" ] || fail "a foreign link was removed"
}

test_link_never_overwrites_files_without_override() {
  printf 'mine\n' > "$SANDBOX/AGENTS.md"
  hey link -y
  assert_equal "$(cat "$SANDBOX/AGENTS.md")" "mine"
  hey link -y --overwrite
  assert_success
  assert_link_to "$SANDBOX/AGENTS.md" "$DOTHEY/AGENTS.md"
  [ -n "$(find "$SANDBOX" -maxdepth 1 -name 'AGENTS.md.bak-*')" ] || fail "no backup was made"
}

test_link_seeds_a_map_the_user_controls() {
  hey link -y
  assert_success
  assert_equal "$(map_value '["@hey:AGENTS.md"]')" '["AGENTS.md"]'
  assert_contains "$(cat "$DOTHEY/hey.json")" "\"migrations\": [$(sandbox::migrations)]"
  links "link:@hey:RULES.md->RULES-here.md"
  cp "$DOTHEY/hey.json" "$SANDBOX/links.before"
  rm "$SANDBOX/AGENTS.md"
  hey link -y
  assert_success
  assert_link_to "$SANDBOX/RULES-here.md" "$DOTHEY/RULES.md"
  assert_no_file "$SANDBOX/AGENTS.md"
  assert_equal "$(cat "$DOTHEY/hey.json")" "$(cat "$SANDBOX/links.before")"
}

test_link_refuses_a_map_outside_its_structure() {
  sandbox::settings '"links": {"@hey:RULES.md": "rules.md", "link": {"@hey:AGENTS.md": ["AGENTS.md"]}}'
  hey link -y
  assert_failure
  assert_equal "$STATUS" 1
  assert_no_file "$SANDBOX/rules.md"
  sandbox::settings '"links": {"@hey:RULES.md": ["rules.md"],}'
  cp "$DOTHEY/hey.json" "$SANDBOX/links.before"
  hey link -y
  assert_failure
  assert_equal "$STATUS" 1
  assert_equal "$(cat "$DOTHEY/hey.json")" "$(cat "$SANDBOX/links.before")"
  sandbox::settings '"links": ["@hey:RULES.md"]'
  hey link -y
  assert_failure
  assert_equal "$STATUS" 1
  sandbox::settings '"links": {"@hey:RULES.md": ["@env:MY_PATH"]}'
  hey link -y
  assert_failure
  assert_equal "$STATUS" 1
}

test_link_never_writes_suggestions_back_once_taken() {
  hey plugins:new acme/widgets widgets
  manifest "$SANDBOX/widgets" "link:plugin.json->widgets.conf"
  add_plugin acme/widgets widgets
  take_suggestions acme/widgets
  core "hey::use framework.helpers.json framework.helpers.fs
    framework.helpers.json::delete \"\$(cat '$DOTHEY/hey.json')\" '.links.inactive[\"acme/widgets\"]' | framework.helpers.fs::write '$DOTHEY/hey.json'"
  hey link -y
  assert_success
  assert_equal "$(map_value '.inactive')" '{}'
  assert_link_to "$SANDBOX/widgets.conf" "$DOTHEY/.plugins/acme/widgets/plugin.json"
}

test_plugin_links_the_user_already_has_never_block_it() {
  hey plugins:new acme/widgets widgets
  manifest "$SANDBOX/widgets" "link:plugin.json->widgets.conf" "link:@dotheyAgents->.h/agents"
  add_plugin acme/widgets widgets
  take_suggestions acme/widgets
  core "hey::use core.system.plugins.service core.system.plugins.manifest
    core.system.plugins.service::fetch acme/widgets '' widgets
    core.system.plugins.manifest::validate \"\$PLUGIN_SOURCE\" acme/widgets"
  assert_success "its own taken links are no clash"
  links "link:@hey:RULES.md->widgets.conf"
  core "hey::use core.system.plugins.service core.system.plugins.manifest
    core.system.plugins.service::fetch acme/widgets '' widgets
    core.system.plugins.manifest::validate \"\$PLUGIN_SOURCE\" acme/widgets"
  assert_success "a destination the user links elsewhere is only reported"
  assert_contains "$ERRORS" "widgets.conf"
}

test_plugins_get_suggestions_in_the_map_that_the_user_can_take() {
  local plugin="$DOTHEY/.plugins/acme/widgets"
  hey plugins:new acme/widgets widgets
  manifest "$SANDBOX/widgets" "link:plugin.json->widgets.conf"
  add_plugin acme/widgets widgets
  assert_equal "$(map_value '.inactive["acme/widgets"]["@plugin:acme.widgets:plugin.json"]')" '["widgets.conf"]'
  assert_no_file "$SANDBOX/widgets.conf"
  take_suggestions acme/widgets
  hey link -y
  assert_success
  assert_link_to "$SANDBOX/widgets.conf" "$plugin/plugin.json"
  hey link -y --refresh-plugin acme/widgets
  assert_success
  assert_equal "$(map_value '.inactive["acme/widgets"]["@plugin:acme.widgets:plugin.json"]')" '["widgets.conf"]'
  assert_link_to "$SANDBOX/widgets.conf" "$plugin/plugin.json"
  links "link:@plugin:acme.widgets:plugin.json->widgets.conf" "skip:@plugin:acme.widgets:plugin.json->widgets.conf"
  hey link -y
  assert_success
  assert_no_file "$SANDBOX/widgets.conf"
  links "link:@plugin:acme.widgets:plugin.json->widgets.conf"
  hey link -y
  assert_link_to "$SANDBOX/widgets.conf" "$plugin/plugin.json"
  core "hey::use core.system.plugins.service core.system.plugins.manifest
    core.system.plugins.service::uninstall acme/widgets >/dev/null
    core.system.plugins.manifest::unlock acme/widgets"
  hey link -y
  assert_success
  assert_no_file "$SANDBOX/widgets.conf"
  assert_not_contains "$(cat "$DOTHEY/hey.json")" "acme"
}

test_removals_only_take_back_what_their_origin_made() {
  hey plugins:new acme/widgets widgets
  add_plugin acme/widgets widgets
  links "link:@hey:AGENTS.md->AGENTS.md" "link:@hey:RULES.md->rules.md" "append:@plugin:acme.widgets:plugin.json->notes.conf"
  hey link -y
  links "link:@hey:AGENTS.md->AGENTS.md" "link:@hey:RULES.md->rules.md" "append:@plugin:acme.widgets:plugin.json->notes.conf" "skip:@hey:SECURITY.md->rules.md->notes.conf"
  hey link -y
  assert_success
  assert_link_to "$SANDBOX/rules.md" "$DOTHEY/RULES.md"
  assert_contains "$(cat "$SANDBOX/notes.conf")" "# acme/widgets (new file)"
  links "link:@hey:AGENTS.md->AGENTS.md" "link:@hey:RULES.md->rules.md" "skip:@hey:RULES.md->rules.md" "skip:@plugin:acme.widgets:commands->notes.conf"
  hey link -y
  assert_success
  assert_no_file "$SANDBOX/rules.md"
  assert_no_file "$SANDBOX/notes.conf"
}

test_plugin_suggestions_stay_within_the_plugin() {
  hey plugins:new acme/widgets widgets
  mkdir -p "$SANDBOX/widgets/dothey/agents" "$SANDBOX/widgets/dothey/stubs"
  : > "$SANDBOX/widgets/dothey/agents/widgets-helper.md"
  printf 'x\n' > "$SANDBOX/widgets/dothey/stubs/widgets.conf.stub"
  manifest "$SANDBOX/widgets" "link:@dotheySkills->.h/skills" "link:agents/*->.h/agents" "append:context/STANDARDS.md->@hey:NOMENCLATURE.md"
  add_plugin acme/widgets widgets
  assert_equal "$(map_value '.inactive["acme/widgets"]')" '{"@dotheySkills":[".h/skills"],"@plugin:acme.widgets:agents/*":[".h/agents"],"@plugin:acme.widgets:skills/*":[".agents/skills/"],"append":{"@plugin:acme.widgets:context/STANDARDS.md":["@hey:NOMENCLATURE.md"],"@plugin:acme.widgets:stubs/widgets.conf.stub":["widgets.conf"]}}'
  hey plugins:new other/gadgets gadgets
  add_plugin other/gadgets gadgets
  assert_equal "$(map_value '.inactive["other/gadgets"]')" '{"@plugin:other.gadgets:skills/*":[".agents/skills/"],"append":{"@plugin:other.gadgets:context/STANDARDS.md":["@hey:STANDARDS.md"]}}'
}

test_appended_context_follows_its_entry() {
  hey plugins:new acme/widgets widgets
  printf -- '---\ndescription: Widget rules.\n---\n\nwidgets rule\n' > "$SANDBOX/widgets/dothey/context/STANDARDS.md"
  cp "$SANDBOX/widgets/dothey/context/STANDARDS.md" "$SANDBOX/widgets/dothey/context/WIDGETS.md"
  add_plugin acme/widgets widgets
  assert_equal "$(map_value '.inactive["acme/widgets"].append["@plugin:acme.widgets:context/WIDGETS.md"]')" '["@hey:WIDGETS.md"]'
  take_suggestions acme/widgets
  hey link -y
  assert_success
  assert_contains "$(cat "$DOTHEY/STANDARDS.md")" "
<!-- acme/widgets -->
---
## acme/widgets
> description: Widget rules.

widgets rule
<!-- /acme/widgets -->"
  assert_equal "$(cat "$DOTHEY/WIDGETS.md")" "---
name: WIDGETS.md
description: Widget rules.
---

<!-- acme/widgets (new file) -->
---
## acme/widgets
> description: Widget rules.

widgets rule
<!-- /acme/widgets -->"
  local before; before=$(cat "$DOTHEY/WIDGETS.md" "$DOTHEY/STANDARDS.md")
  hey link -y
  assert_success
  assert_equal "$(cat "$DOTHEY/WIDGETS.md" "$DOTHEY/STANDARDS.md")" "$before"
  hey link -y --refresh-plugin acme/widgets
  assert_success
  assert_contains "$(cat "$DOTHEY/STANDARDS.md")" "widgets rule"
  links "skip:@plugin:acme.widgets:context/WIDGETS.md->@hey:WIDGETS.md" "skip:@plugin:acme.widgets:context/STANDARDS.md->@hey:STANDARDS.md"
  hey link -y
  assert_success
  assert_no_file "$DOTHEY/WIDGETS.md"
  assert_equal "$(cat "$DOTHEY/STANDARDS.md")" "$(cat "$SOURCE_DIR/STANDARDS.md")"
}

test_plugin_commands_only_write_the_map() {
  core "hey::use core.system.plugins.console; core.system.plugins.console::suggest"
  assert_success
  assert_no_file "$SANDBOX/AGENTS.md"
  hey link --settings-only
  assert_success
}

test_link_keeps_origins_inside_dothey() {
  printf 'HEY_GH_TOKEN=secret\n' > "$SANDBOX/.env"
  links "link:@hey:../.env->leak" "link:@hey:../../.env->leak2" "link:@plugin:acme.widgets:../../../.env->leak3" "link:../x->leak4" "append:@hey:../.env->leak5"
  hey link -y
  assert_failure
  assert_equal "$STATUS" 1
  for leak in leak leak2 leak3 leak4 leak5; do
    assert_no_file "$SANDBOX/$leak"
  done
}

test_link_map_shortcuts_resolve_dothey_modules_plugins_and_sets() {
  hey plugins:new acme/widgets widgets
  add_plugin acme/widgets widgets
  mkdir -p "$DOTHEY/Notes/deep.er"
  : > "$DOTHEY/Notes/deep.er/n.md"
  links "link:@module:onboarding:skills/hey-tools->one/hey-tools" "link:@module:onboarding:skills->whole/skills" "link:@module:tasks:skills/*->each/" \
    "link:@module:link:commands/link.sh->system/link.sh" "link:@plugin:acme.widgets:skills/widgets-example->plugin/widgets-example" \
    "link:@plugin:acme.widgets:plugin.json->plugin/widgets.json" "link:@hey:Notes/deep.er/n.md->dotted/n.md" "link:@hey:Notes/*->notes/" \
    "link:@dotheySkills->dothey/" "link:@pluginsSkills->plugins/"
  hey link -y
  assert_success
  assert_link_to "$SANDBOX/one/hey-tools" "$DOTHEY/.core/modules/onboarding/skills/hey-tools"
  assert_link_to "$SANDBOX/whole/skills" "$DOTHEY/.core/modules/onboarding/skills"
  assert_link_to "$SANDBOX/each/hey-create-task" "$DOTHEY/.core/modules/tasks/skills/hey-create-task"
  assert_link_to "$SANDBOX/system/link.sh" "$DOTHEY/.core/system/link/commands/link.sh"
  assert_link_to "$SANDBOX/plugin/widgets-example" "$DOTHEY/.plugins/acme/widgets/skills/widgets-example"
  assert_link_to "$SANDBOX/plugin/widgets.json" "$DOTHEY/.plugins/acme/widgets/plugin.json"
  assert_link_to "$SANDBOX/dotted/n.md" "$DOTHEY/Notes/deep.er/n.md"
  assert_link_to "$SANDBOX/notes/deep.er" "$DOTHEY/Notes/deep.er"
  assert_link_to "$SANDBOX/dothey/hey-onboard" "$DOTHEY/.core/modules/onboarding/skills/hey-onboard"
  assert_no_file "$SANDBOX/dothey/widgets-example"
  assert_link_to "$SANDBOX/plugins/widgets-example" "$DOTHEY/.plugins/acme/widgets/skills/widgets-example"
  assert_no_file "$SANDBOX/plugins/hey-onboard"
}

test_link_map_removals_win_and_never_touch_real_files() {
  links "link:@hey:AGENTS.md->AGENTS.md" "link:@hey:RULES.md->rules.md"
  printf 'mine\n' > "$SANDBOX/real.md"
  hey link -y
  assert_link_to "$SANDBOX/rules.md" "$DOTHEY/RULES.md"
  links "link:@hey:AGENTS.md->AGENTS.md" "link:@hey:RULES.md->rules.md" "skip:@hey:RULES.md->rules.md->real.md->.git/config"
  hey link -y
  assert_success
  assert_no_file "$SANDBOX/rules.md"
  assert_equal "$(cat "$SANDBOX/real.md")" "mine"
  hey link -y
  assert_no_file "$SANDBOX/rules.md"
}

test_plugin_links_are_activated_and_lose_to_the_general_ones() {
  hey plugins:new acme/widgets widgets
  manifest "$SANDBOX/widgets" "link:plugin.json->widgets.conf->rules.md" "append:plugin.json->notes.md"
  add_plugin acme/widgets widgets
  links "link:@hey:RULES.md->rules.md" "append:@hey:STANDARDS.md->notes.md"
  core "hey::use framework.helpers.json framework.helpers.fs
    framework.helpers.json::set \"\$(cat '$DOTHEY/hey.json')\" '.links.inactive[\"acme/widgets\"]' '{\"@plugin:acme.widgets:plugin.json\": [\"widgets.conf\", \"rules.md\"], \"append\": {\"@plugin:acme.widgets:plugin.json\": [\"notes.md\"]}}' | framework.helpers.fs::write '$DOTHEY/hey.json'"
  hey link -y
  assert_success
  assert_no_file "$SANDBOX/widgets.conf"
  hey plugins:link acme/widgets --preview
  assert_success
  assert_no_file "$SANDBOX/widgets.conf"
  hey plugins:link acme/widgets -y
  assert_success
  assert_link_to "$SANDBOX/widgets.conf" "$DOTHEY/.plugins/acme/widgets/plugin.json"
  assert_equal "$(map_value '.inactive')" '{}'
  assert_equal "$(map_value '["acme/widgets"]["@plugin:acme.widgets:plugin.json"]')" '["widgets.conf","rules.md"]'
  assert_equal "$(core "hey::use framework.helpers.json; framework.helpers.json::keys \"\$(cat '$DOTHEY/hey.json')\" .links"; printf '%s' "$OUTPUT")" "@hey:RULES.md
append
skip
acme/widgets
inactive" "the group lands right before inactive"
  hey plugins:link acme/widgets -y
  assert_failure
  assert_equal "$STATUS" 5
  hey plugins:unlink acme/widgets -y
  assert_success
  assert_no_file "$SANDBOX/widgets.conf"
  assert_not_contains "$(cat "$SANDBOX/notes.md" 2>/dev/null)" "<!-- acme/widgets -->"
  assert_equal "$(map_value '.inactive["acme/widgets"]["@plugin:acme.widgets:plugin.json"]')" '["widgets.conf","rules.md"]'
  assert_equal "$(map_value '["acme/widgets"]')" ""
  hey plugins:unlink acme/widgets -y
  assert_failure
  assert_equal "$STATUS" 5
  hey plugins:link acme/widgets -y
  hey link -y
  assert_success
  assert_link_to "$SANDBOX/widgets.conf" "$DOTHEY/.plugins/acme/widgets/plugin.json"
  assert_link_to "$SANDBOX/rules.md" "$DOTHEY/RULES.md"
  assert_contains "$(cat "$SANDBOX/notes.md")" "<!-- dothey"
  assert_contains "$(cat "$SANDBOX/notes.md")" "<!-- acme/widgets -->"
}

test_keys_defined_twice_in_the_links_are_reported() {
  sandbox::settings '"links": {"@hey:AGENTS.md": ["AGENTS.md"], "@hey:AGENTS.md": ["agents.md"], "acme/widgets": {"@hey:RULES.md": ["a.md"], "@hey:RULES.md": ["b.md"]}}'
  hey link -y
  assert_contains "$ERRORS" "\"@hey:AGENTS.md\""
  assert_contains "$ERRORS" "\"@hey:RULES.md\""
  assert_link_to "$SANDBOX/agents.md" "$DOTHEY/AGENTS.md"
}

test_a_destination_folder_takes_an_origin_under_its_own_name() {
  mkdir -p "$SANDBOX/docs"
  links "link:@hey:RULES.md->docs/->plain.md" "link:@hey:Notes/*->notes/"
  : > "$DOTHEY/Notes/n001.md"
  hey link -y
  assert_success
  assert_link_to "$SANDBOX/docs/RULES.md" "$DOTHEY/RULES.md"
  assert_link_to "$SANDBOX/plain.md" "$DOTHEY/RULES.md"
  assert_link_to "$SANDBOX/notes/n001.md" "$DOTHEY/Notes/n001.md"
}

test_link_map_refuses_unknown_origins() {
  links "link:@everything->x" "link:RULES.md->y"
  hey link -y
  assert_failure
  assert_equal "$STATUS" 1
  assert_contains "$ERRORS" "@everything"
  assert_contains "$ERRORS" "RULES.md"
}

test_skill_and_agent_sets_follow_the_skills_standard() {
  mkdir -p "$DOTHEY/.core/system/link/skills/not-a-skill" "$DOTHEY/.core/modules/notes/agents" "$DOTHEY/.core/modules/newmodule/skills/new-skill"
  : > "$DOTHEY/.core/modules/newmodule/skills/new-skill/SKILL.md"
  : > "$DOTHEY/.core/modules/notes/agents/notes-agent.md"
  : > "$DOTHEY/.core/modules/notes/agents/README.txt"
  links "link:@dotheySkills->.claude/skills/" "link:@dotheyAgents->.claude/agents/"
  hey link -y
  assert_success
  assert_link_to "$SANDBOX/.claude/skills/hey-tools" "$DOTHEY/.core/modules/onboarding/skills/hey-tools"
  assert_link_to "$SANDBOX/.claude/skills/hey-onboard" "$DOTHEY/.core/modules/onboarding/skills/hey-onboard"
  assert_link_to "$SANDBOX/.claude/skills/new-skill" "$DOTHEY/.core/modules/newmodule/skills/new-skill"
  assert_no_file "$SANDBOX/.claude/skills/not-a-skill"
  assert_link_to "$SANDBOX/.claude/agents/notes-agent.md" "$DOTHEY/.core/modules/notes/agents/notes-agent.md"
  assert_no_file "$SANDBOX/.claude/agents/README.txt"
}

test_an_origin_links_and_appends_to_several_destinations() {
  links "link:@hey:RULES.md->one.md->two/rules.md->three.md" "append:@hey:RULES.md->a.md->b.md"
  hey link -y
  assert_success
  assert_link_to "$SANDBOX/one.md" "$DOTHEY/RULES.md"
  assert_link_to "$SANDBOX/two/rules.md" "$DOTHEY/RULES.md"
  assert_link_to "$SANDBOX/three.md" "$DOTHEY/RULES.md"
  assert_contains "$(cat "$SANDBOX/a.md")" "<!-- dothey (new file) -->"
  assert_contains "$(cat "$SANDBOX/b.md")" "<!-- dothey (new file) -->"
  links "link:@hey:RULES.md->one.md->two/rules.md" "skip:@hey:RULES.md->three.md->a.md->b.md"
  hey link -y
  assert_success
  assert_no_file "$SANDBOX/three.md"
  assert_no_file "$SANDBOX/a.md"
  assert_no_file "$SANDBOX/b.md"
  hey plugins:new acme/widgets widgets
  manifest "$SANDBOX/widgets" "link:plugin.json->w1.json->w2.json" "append:plugin.json->@hey:STANDARDS.md->notes.md"
  add_plugin acme/widgets widgets
  assert_equal "$(map_value '.inactive["acme/widgets"]["@plugin:acme.widgets:plugin.json"]')" '["w1.json","w2.json"]'
  assert_equal "$(map_value '.inactive["acme/widgets"].append["@plugin:acme.widgets:plugin.json"]')" '["@hey:STANDARDS.md","notes.md"]'
  manifest "$SANDBOX/widgets" "link:plugin.json->ok.json->.git/config"
  validate_chain acme/widgets widgets
  assert_failure
  assert_equal "$STATUS" 1
}

validate_chain() {
  core "hey::use core.system.plugins.service core.system.plugins.manifest
    core.system.plugins.service::fetch $1 '' $2
    core.system.plugins.manifest::validate \"\$PLUGIN_SOURCE\" $1"
}

test_link_edits_only_what_changed_in_the_map() {
  cat > "$DOTHEY/hey.json" <<MAP
{
  "state": {"migrations": [$(sandbox::migrations)]},
  "links": {
  "@hey:AGENTS.md": ["AGENTS.md"],    "@hey:RULES.md": ["rules.md"],
  "append": {},
  "skip": {},
  "inactive": {}
  }
}
MAP
  hey plugins:new acme/widgets widgets
  add_plugin acme/widgets widgets
  assert_contains "$(cat "$DOTHEY/hey.json")" '  "@hey:AGENTS.md": ["AGENTS.md"],    "@hey:RULES.md": ["rules.md"],'
  assert_equal "$(map_value '.inactive["acme/widgets"]["@plugin:acme.widgets:skills/*"]')" '[".agents/skills/"]'
  links_before=$(sed '/"inactive"/,$d' "$DOTHEY/hey.json")
  core "hey::use core.system.plugins.service core.system.plugins.manifest
    core.system.plugins.service::uninstall acme/widgets >/dev/null
    core.system.plugins.manifest::unlock acme/widgets"
  hey link -y
  assert_success
  assert_equal "$(sed '/"inactive"/,$d' "$DOTHEY/hey.json")" "$links_before"
  assert_equal "$(map_value '.inactive')" '{}'
}

test_link_leaves_out_everything_of_a_module_a_feature_flag_turns_off() {
  mkdir -p "$DOTHEY/.core/modules/release/skills/hey-release-example"
  printf -- '---\nname: hey-release-example\ndescription: An example.\n---\n' > "$DOTHEY/.core/modules/release/skills/hey-release-example/SKILL.md"
  : > "$DOTHEY/.core/modules/release/notes.md"
  sandbox::settings '"featureFlags": {"release": true}, "links": {"@dotheySkills": ["skills/"], "append": {}, "skip": {}, "inactive": {}}'
  hey link -y
  assert_success
  assert_link_to "$SANDBOX/skills/hey-release-example" "$DOTHEY/.core/modules/release/skills/hey-release-example"
  sandbox::settings '"featureFlags": {}, "links": {"@dotheySkills": ["skills/"], "@module:release:skills/hey-release-example": ["one/hey-release-example"], "append": {"@module:release:notes.md": ["notes.md"]}, "skip": {}, "inactive": {}}'
  hey link -y
  assert_link_to "$SANDBOX/skills/hey-onboard" "$DOTHEY/.core/modules/onboarding/skills/hey-onboard"
  assert_no_file "$SANDBOX/skills/hey-release-example"
  assert_no_file "$SANDBOX/one/hey-release-example"
  assert_failure
  assert_equal "$STATUS" 1
  assert_no_file "$SANDBOX/notes.md"
}

test_link_json_plans_then_applies_with_counts() {
  links "link:@hey:AGENTS.md->AGENTS.md"
  hey link --json
  assert_success
  assert_contains "$OUTPUT" '{"action":"link","origin":".hey/AGENTS.md","destination":"AGENTS.md"}'
  assert_no_file "$SANDBOX/AGENTS.md"
  hey link --json -y
  assert_success
  assert_contains "$OUTPUT" '"failed":0'
  assert_link_to "$SANDBOX/AGENTS.md" "$DOTHEY/AGENTS.md"
}
