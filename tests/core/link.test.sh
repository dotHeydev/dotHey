#!/usr/bin/env bash

skill_paths() {
  find "$DOTDOT"/.core/system/*/skills "$DOTDOT"/.core/modules/*/skills -mindepth 1 -maxdepth 1 -type d
}

test_link_links_and_seeds() {
  dot link -y
  assert_success
  assert_link_to "$SANDBOX/AGENTS.md" "$DOTDOT/AGENTS.md"
  assert_file "$DOTDOT/USER.md"
}

# Every link in the project outside dotdot, with its target.
link_state() {
  find "$SANDBOX" -path "$DOTDOT" -prune -o -type l -print | sort | while IFS= read -r link; do
    printf '%s -> %s\n' "$link" "$(readlink "$link")"
  done
}

test_link_is_idempotent() {
  local before
  dot link -y
  before=$(link_state)
  dot link -y
  assert_success
  assert_equal "$(link_state)" "$before"
}

test_link_only_previews_without_a_terminal_or_with_preview() {
  dot link
  assert_success
  assert_no_file "$SANDBOX/AGENTS.md"
  DOT_INTERNAL_CALL="" dot link --preview -y
  assert_failure
  assert_equal "$STATUS" 5
  dot link --dry-run
  assert_success
  assert_no_file "$SANDBOX/AGENTS.md"
}

test_link_prunes_broken_dotdot_links_and_keeps_foreign_ones() {
  links "link:@dot:AGENTS.md->AGENTS.md" "link:@dotdotSkills->.claude/skills/"
  dot link -y
  ln -s ../../.dot/.core/system/link/skills/removed-skill "$SANDBOX/.claude/skills/removed-skill"
  ln -s /nonexistent/elsewhere "$SANDBOX/.claude/skills/foreign"
  dot link -y
  assert_success
  assert_no_file "$SANDBOX/.claude/skills/removed-skill"
  [ -L "$SANDBOX/.claude/skills/foreign" ] || fail "a foreign link was removed"
}

test_link_never_overwrites_files_without_override() {
  printf 'mine\n' > "$SANDBOX/AGENTS.md"
  dot link -y
  assert_equal "$(cat "$SANDBOX/AGENTS.md")" "mine"
  dot link -y --overwrite
  assert_success
  assert_link_to "$SANDBOX/AGENTS.md" "$DOTDOT/AGENTS.md"
  [ -n "$(find "$SANDBOX" -maxdepth 1 -name 'AGENTS.md.bak-*')" ] || fail "no backup was made"
}

test_link_seeds_a_map_the_user_controls() {
  dot link -y
  assert_success
  assert_equal "$(map_value '["@dot:AGENTS.md"]')" '["AGENTS.md"]'
  assert_contains "$(cat "$DOTDOT/dot.json")" '"migrations": []'
  links "link:@dot:RULES.md->RULES-here.md"
  cp "$DOTDOT/dot.json" "$SANDBOX/links.before"
  rm "$SANDBOX/AGENTS.md"
  dot link -y
  assert_success
  assert_link_to "$SANDBOX/RULES-here.md" "$DOTDOT/RULES.md"
  assert_no_file "$SANDBOX/AGENTS.md"
  assert_equal "$(cat "$DOTDOT/dot.json")" "$(cat "$SANDBOX/links.before")"
}

test_link_refuses_a_map_outside_its_structure() {
  sandbox::settings '"links": {"@dot:RULES.md": "rules.md", "link": {"@dot:AGENTS.md": ["AGENTS.md"]}}'
  dot link -y
  assert_failure
  assert_equal "$STATUS" 1
  assert_no_file "$SANDBOX/rules.md"
  sandbox::settings '"links": {"@dot:RULES.md": ["rules.md"],}'
  cp "$DOTDOT/dot.json" "$SANDBOX/links.before"
  dot link -y
  assert_failure
  assert_equal "$STATUS" 1
  assert_equal "$(cat "$DOTDOT/dot.json")" "$(cat "$SANDBOX/links.before")"
  sandbox::settings '"links": ["@dot:RULES.md"]'
  dot link -y
  assert_failure
  assert_equal "$STATUS" 1
  sandbox::settings '"links": {"@dot:RULES.md": ["@env:MY_PATH"]}'
  dot link -y
  assert_failure
  assert_equal "$STATUS" 1
}

test_link_never_writes_suggestions_back_once_taken() {
  dot plugins:new acme/widgets widgets
  manifest "$SANDBOX/widgets" "link:plugin.json->widgets.conf"
  add_plugin acme/widgets widgets
  take_suggestions acme/widgets
  core "dot::use framework.helpers.json framework.helpers.fs
    framework.helpers.json::delete \"\$(cat '$DOTDOT/dot.json')\" '.links.inactive[\"acme/widgets\"]' | framework.helpers.fs::write '$DOTDOT/dot.json'"
  dot link -y
  assert_success
  assert_equal "$(map_value '.inactive')" '{}'
  assert_link_to "$SANDBOX/widgets.conf" "$DOTDOT/.plugins/acme/widgets/plugin.json"
}

test_plugin_links_the_user_already_has_never_block_it() {
  dot plugins:new acme/widgets widgets
  manifest "$SANDBOX/widgets" "link:plugin.json->widgets.conf" "link:@dotdotAgents->.h/agents"
  add_plugin acme/widgets widgets
  take_suggestions acme/widgets
  core "dot::use core.system.plugins.service core.system.plugins.manifest
    core.system.plugins.service::fetch acme/widgets '' widgets
    core.system.plugins.manifest::validate \"\$PLUGIN_SOURCE\" acme/widgets"
  assert_success "its own taken links are no clash"
  links "link:@dot:RULES.md->widgets.conf"
  core "dot::use core.system.plugins.service core.system.plugins.manifest
    core.system.plugins.service::fetch acme/widgets '' widgets
    core.system.plugins.manifest::validate \"\$PLUGIN_SOURCE\" acme/widgets"
  assert_success "a destination the user links elsewhere is only reported"
  assert_contains "$ERRORS" "widgets.conf"
}

test_plugins_get_suggestions_in_the_map_that_the_user_can_take() {
  local plugin="$DOTDOT/.plugins/acme/widgets"
  dot plugins:new acme/widgets widgets
  manifest "$SANDBOX/widgets" "link:plugin.json->widgets.conf"
  add_plugin acme/widgets widgets
  assert_equal "$(map_value '.inactive["acme/widgets"]["@plugin:acme.widgets:plugin.json"]')" '["widgets.conf"]'
  assert_no_file "$SANDBOX/widgets.conf"
  take_suggestions acme/widgets
  dot link -y
  assert_success
  assert_link_to "$SANDBOX/widgets.conf" "$plugin/plugin.json"
  dot link -y --refresh-plugin acme/widgets
  assert_success
  assert_equal "$(map_value '.inactive["acme/widgets"]["@plugin:acme.widgets:plugin.json"]')" '["widgets.conf"]'
  assert_link_to "$SANDBOX/widgets.conf" "$plugin/plugin.json"
  links "link:@plugin:acme.widgets:plugin.json->widgets.conf" "remove:@plugin:acme.widgets:plugin.json->widgets.conf"
  dot link -y
  assert_success
  assert_no_file "$SANDBOX/widgets.conf"
  links "link:@plugin:acme.widgets:plugin.json->widgets.conf"
  dot link -y
  assert_link_to "$SANDBOX/widgets.conf" "$plugin/plugin.json"
  core "dot::use core.system.plugins.service core.system.plugins.manifest
    core.system.plugins.service::uninstall acme/widgets >/dev/null
    core.system.plugins.manifest::unlock acme/widgets"
  dot link -y
  assert_success
  assert_no_file "$SANDBOX/widgets.conf"
  assert_not_contains "$(cat "$DOTDOT/dot.json")" "acme"
}

test_removals_only_take_back_what_their_origin_made() {
  dot plugins:new acme/widgets widgets
  add_plugin acme/widgets widgets
  links "link:@dot:AGENTS.md->AGENTS.md" "link:@dot:RULES.md->rules.md" "append:@plugin:acme.widgets:plugin.json->notes.conf"
  dot link -y
  links "link:@dot:AGENTS.md->AGENTS.md" "remove:@dot:SECURITY.md->rules.md->notes.conf"
  dot link -y
  assert_success
  assert_link_to "$SANDBOX/rules.md" "$DOTDOT/RULES.md"
  assert_contains "$(cat "$SANDBOX/notes.conf")" "# acme/widgets (new file)"
  links "link:@dot:AGENTS.md->AGENTS.md" "link:@dot:RULES.md->rules.md" "remove:@dot:RULES.md->rules.md" "remove:@plugin:acme.widgets:commands->notes.conf"
  dot link -y
  assert_success
  assert_no_file "$SANDBOX/rules.md"
  assert_no_file "$SANDBOX/notes.conf"
}

test_plugin_suggestions_stay_within_the_plugin() {
  dot plugins:new acme/widgets widgets
  mkdir -p "$SANDBOX/widgets/dotdot/agents" "$SANDBOX/widgets/dotdot/stubs"
  : > "$SANDBOX/widgets/dotdot/agents/widgets-helper.md"
  printf 'x\n' > "$SANDBOX/widgets/dotdot/stubs/widgets.conf.stub"
  manifest "$SANDBOX/widgets" "link:@dotdotSkills->.h/skills" "link:agents/*->.h/agents" "append:context/STANDARDS.md->@dot:NOMENCLATURE.md"
  add_plugin acme/widgets widgets
  assert_equal "$(map_value '.inactive["acme/widgets"]')" '{"@dotdotSkills":[".h/skills"],"@plugin:acme.widgets:agents/*":[".h/agents"],"@plugin:acme.widgets:skills/*":[".agents/skills/"],"append":{"@plugin:acme.widgets:context/STANDARDS.md":["@dot:NOMENCLATURE.md"],"@plugin:acme.widgets:stubs/widgets.conf.stub":["widgets.conf"]}}'
  dot plugins:new other/gadgets gadgets
  add_plugin other/gadgets gadgets
  assert_equal "$(map_value '.inactive["other/gadgets"]')" '{"@plugin:other.gadgets:skills/*":[".agents/skills/"],"append":{"@plugin:other.gadgets:context/STANDARDS.md":["@dot:STANDARDS.md"]}}'
}

test_appended_context_follows_its_entry() {
  dot plugins:new acme/widgets widgets
  printf -- '---\ndescription: Widget rules.\n---\n\nwidgets rule\n' > "$SANDBOX/widgets/dotdot/context/STANDARDS.md"
  cp "$SANDBOX/widgets/dotdot/context/STANDARDS.md" "$SANDBOX/widgets/dotdot/context/WIDGETS.md"
  add_plugin acme/widgets widgets
  assert_equal "$(map_value '.inactive["acme/widgets"].append["@plugin:acme.widgets:context/WIDGETS.md"]')" '["@dot:WIDGETS.md"]'
  take_suggestions acme/widgets
  dot link -y
  assert_success
  assert_contains "$(cat "$DOTDOT/STANDARDS.md")" "
<!-- acme/widgets -->
---
## acme/widgets
> description: Widget rules.

widgets rule
<!-- /acme/widgets -->"
  assert_equal "$(cat "$DOTDOT/WIDGETS.md")" "---
name: WIDGETS.md
description: Widget rules.
---

<!-- acme/widgets (new file) -->
---
## acme/widgets
> description: Widget rules.

widgets rule
<!-- /acme/widgets -->"
  local before; before=$(cat "$DOTDOT/WIDGETS.md" "$DOTDOT/STANDARDS.md")
  dot link -y
  assert_success
  assert_equal "$(cat "$DOTDOT/WIDGETS.md" "$DOTDOT/STANDARDS.md")" "$before"
  dot link -y --refresh-plugin acme/widgets
  assert_success
  assert_contains "$(cat "$DOTDOT/STANDARDS.md")" "widgets rule"
  links "remove:@plugin:acme.widgets:context/WIDGETS.md->@dot:WIDGETS.md" "remove:@plugin:acme.widgets:context/STANDARDS.md->@dot:STANDARDS.md"
  dot link -y
  assert_success
  assert_no_file "$DOTDOT/WIDGETS.md"
  assert_equal "$(cat "$DOTDOT/STANDARDS.md")" "$(cat "$SOURCE_DIR/STANDARDS.md")"
}

test_plugin_commands_only_write_the_map() {
  core "dot::use core.system.plugins.console; core.system.plugins.console::suggest"
  assert_success
  assert_no_file "$SANDBOX/AGENTS.md"
  dot link --settings-only
  assert_success
}

test_link_keeps_origins_inside_dotdot() {
  printf 'DOT_GH_TOKEN=secret\n' > "$SANDBOX/.env"
  links "link:@dot:../.env->leak" "link:@dot:../../.env->leak2" "link:@plugin:acme.widgets:../../../.env->leak3" "link:../x->leak4" "append:@dot:../.env->leak5"
  dot link -y
  assert_failure
  assert_equal "$STATUS" 1
  for leak in leak leak2 leak3 leak4 leak5; do
    assert_no_file "$SANDBOX/$leak"
  done
}

test_link_map_shortcuts_resolve_dotdot_modules_plugins_and_sets() {
  dot plugins:new acme/widgets widgets
  add_plugin acme/widgets widgets
  mkdir -p "$DOTDOT/Notes/deep.er"
  : > "$DOTDOT/Notes/deep.er/n.md"
  links "link:@module:notes:skills/dot-tool-notes->one/dot-tool-notes" "link:@module:notes:skills->whole/skills" "link:@module:tasks:skills/*->each/" \
    "link:@module:link:skills/dot-tool-link->system/dot-tool-link" "link:@plugin:acme.widgets:skills/widgets-example->plugin/widgets-example" \
    "link:@plugin:acme.widgets:plugin.json->plugin/widgets.json" "link:@dot:Notes/deep.er/n.md->dotted/n.md" "link:@dot:Notes/*->notes/" \
    "link:@dotdotSkills->dotdot/" "link:@pluginsSkills->plugins/"
  dot link -y
  assert_success
  assert_link_to "$SANDBOX/one/dot-tool-notes" "$DOTDOT/.core/modules/notes/skills/dot-tool-notes"
  assert_link_to "$SANDBOX/whole/skills" "$DOTDOT/.core/modules/notes/skills"
  assert_link_to "$SANDBOX/each/dot-create-task" "$DOTDOT/.core/modules/tasks/skills/dot-create-task"
  assert_link_to "$SANDBOX/system/dot-tool-link" "$DOTDOT/.core/system/link/skills/dot-tool-link"
  assert_link_to "$SANDBOX/plugin/widgets-example" "$DOTDOT/.plugins/acme/widgets/skills/widgets-example"
  assert_link_to "$SANDBOX/plugin/widgets.json" "$DOTDOT/.plugins/acme/widgets/plugin.json"
  assert_link_to "$SANDBOX/dotted/n.md" "$DOTDOT/Notes/deep.er/n.md"
  assert_link_to "$SANDBOX/notes/deep.er" "$DOTDOT/Notes/deep.er"
  assert_link_to "$SANDBOX/dotdot/dot-onboard" "$DOTDOT/.core/modules/onboarding/skills/dot-onboard"
  assert_no_file "$SANDBOX/dotdot/widgets-example"
  assert_link_to "$SANDBOX/plugins/widgets-example" "$DOTDOT/.plugins/acme/widgets/skills/widgets-example"
  assert_no_file "$SANDBOX/plugins/dot-onboard"
}

test_link_map_removals_win_and_never_touch_real_files() {
  links "link:@dot:AGENTS.md->AGENTS.md" "link:@dot:RULES.md->rules.md"
  printf 'mine\n' > "$SANDBOX/real.md"
  dot link -y
  assert_link_to "$SANDBOX/rules.md" "$DOTDOT/RULES.md"
  links "link:@dot:AGENTS.md->AGENTS.md" "link:@dot:RULES.md->rules.md" "remove:@dot:RULES.md->rules.md->real.md->.git/config"
  dot link -y
  assert_success
  assert_no_file "$SANDBOX/rules.md"
  assert_equal "$(cat "$SANDBOX/real.md")" "mine"
  dot link -y
  assert_no_file "$SANDBOX/rules.md"
}

test_plugin_links_are_activated_and_lose_to_the_general_ones() {
  dot plugins:new acme/widgets widgets
  manifest "$SANDBOX/widgets" "link:plugin.json->widgets.conf->rules.md" "append:plugin.json->notes.md"
  add_plugin acme/widgets widgets
  links "link:@dot:RULES.md->rules.md" "append:@dot:STANDARDS.md->notes.md"
  core "dot::use framework.helpers.json framework.helpers.fs
    framework.helpers.json::set \"\$(cat '$DOTDOT/dot.json')\" '.links.inactive[\"acme/widgets\"]' '{\"@plugin:acme.widgets:plugin.json\": [\"widgets.conf\", \"rules.md\"], \"append\": {\"@plugin:acme.widgets:plugin.json\": [\"notes.md\"]}}' | framework.helpers.fs::write '$DOTDOT/dot.json'"
  dot link -y
  assert_success
  assert_no_file "$SANDBOX/widgets.conf"
  dot plugins:link acme/widgets --preview
  assert_success
  assert_no_file "$SANDBOX/widgets.conf"
  dot plugins:link acme/widgets -y
  assert_success
  assert_link_to "$SANDBOX/widgets.conf" "$DOTDOT/.plugins/acme/widgets/plugin.json"
  assert_equal "$(map_value '.inactive')" '{}'
  assert_equal "$(map_value '["acme/widgets"]["@plugin:acme.widgets:plugin.json"]')" '["widgets.conf","rules.md"]'
  assert_equal "$(core "dot::use framework.helpers.json; framework.helpers.json::keys \"\$(cat '$DOTDOT/dot.json')\" .links"; printf '%s' "$OUTPUT")" "@dot:RULES.md
append
remove
acme/widgets
inactive" "the group lands right before inactive"
  dot plugins:link acme/widgets -y
  assert_failure
  assert_equal "$STATUS" 5
  dot plugins:unlink acme/widgets -y
  assert_success
  assert_no_file "$SANDBOX/widgets.conf"
  assert_not_contains "$(cat "$SANDBOX/notes.md" 2>/dev/null)" "<!-- acme/widgets -->"
  assert_equal "$(map_value '.inactive["acme/widgets"]["@plugin:acme.widgets:plugin.json"]')" '["widgets.conf","rules.md"]'
  assert_equal "$(map_value '["acme/widgets"]')" ""
  dot plugins:unlink acme/widgets -y
  assert_failure
  assert_equal "$STATUS" 5
  dot plugins:link acme/widgets -y
  dot link -y
  assert_success
  assert_link_to "$SANDBOX/widgets.conf" "$DOTDOT/.plugins/acme/widgets/plugin.json"
  assert_link_to "$SANDBOX/rules.md" "$DOTDOT/RULES.md"
  assert_contains "$(cat "$SANDBOX/notes.md")" "<!-- dotdot"
  assert_contains "$(cat "$SANDBOX/notes.md")" "<!-- acme/widgets -->"
}

test_keys_defined_twice_in_the_links_are_reported() {
  sandbox::settings '"links": {"@dot:AGENTS.md": ["AGENTS.md"], "@dot:AGENTS.md": ["agents.md"], "acme/widgets": {"@dot:RULES.md": ["a.md"], "@dot:RULES.md": ["b.md"]}}'
  dot link -y
  assert_contains "$ERRORS" "\"@dot:AGENTS.md\""
  assert_contains "$ERRORS" "\"@dot:RULES.md\""
  assert_link_to "$SANDBOX/agents.md" "$DOTDOT/AGENTS.md"
}

test_a_destination_folder_takes_an_origin_under_its_own_name() {
  mkdir -p "$SANDBOX/docs"
  links "link:@dot:RULES.md->docs/->plain.md" "link:@dot:Notes/*->notes/"
  : > "$DOTDOT/Notes/n001.md"
  dot link -y
  assert_success
  assert_link_to "$SANDBOX/docs/RULES.md" "$DOTDOT/RULES.md"
  assert_link_to "$SANDBOX/plain.md" "$DOTDOT/RULES.md"
  assert_link_to "$SANDBOX/notes/n001.md" "$DOTDOT/Notes/n001.md"
}

test_link_map_refuses_unknown_origins() {
  links "link:@everything->x" "link:RULES.md->y"
  dot link -y
  assert_failure
  assert_equal "$STATUS" 1
  assert_contains "$ERRORS" "@everything"
  assert_contains "$ERRORS" "RULES.md"
}

test_skill_and_agent_sets_follow_the_skills_standard() {
  mkdir -p "$DOTDOT/.core/system/link/skills/not-a-skill" "$DOTDOT/.core/modules/notes/agents" "$DOTDOT/.core/modules/newmodule/skills/new-skill"
  : > "$DOTDOT/.core/modules/newmodule/skills/new-skill/SKILL.md"
  : > "$DOTDOT/.core/modules/notes/agents/notes-agent.md"
  : > "$DOTDOT/.core/modules/notes/agents/README.txt"
  links "link:@dotdotSkills->.claude/skills/" "link:@dotdotAgents->.claude/agents/"
  dot link -y
  assert_success
  assert_link_to "$SANDBOX/.claude/skills/dot-tool-link" "$DOTDOT/.core/system/link/skills/dot-tool-link"
  assert_link_to "$SANDBOX/.claude/skills/dot-onboard" "$DOTDOT/.core/modules/onboarding/skills/dot-onboard"
  assert_link_to "$SANDBOX/.claude/skills/new-skill" "$DOTDOT/.core/modules/newmodule/skills/new-skill"
  assert_no_file "$SANDBOX/.claude/skills/not-a-skill"
  assert_link_to "$SANDBOX/.claude/agents/notes-agent.md" "$DOTDOT/.core/modules/notes/agents/notes-agent.md"
  assert_no_file "$SANDBOX/.claude/agents/README.txt"
}

test_an_origin_links_and_appends_to_several_destinations() {
  links "link:@dot:RULES.md->one.md->two/rules.md->three.md" "append:@dot:RULES.md->a.md->b.md"
  dot link -y
  assert_success
  assert_link_to "$SANDBOX/one.md" "$DOTDOT/RULES.md"
  assert_link_to "$SANDBOX/two/rules.md" "$DOTDOT/RULES.md"
  assert_link_to "$SANDBOX/three.md" "$DOTDOT/RULES.md"
  assert_contains "$(cat "$SANDBOX/a.md")" "<!-- dotdot (new file) -->"
  assert_contains "$(cat "$SANDBOX/b.md")" "<!-- dotdot (new file) -->"
  links "link:@dot:RULES.md->one.md->two/rules.md" "remove:@dot:RULES.md->three.md->a.md->b.md"
  dot link -y
  assert_success
  assert_no_file "$SANDBOX/three.md"
  assert_no_file "$SANDBOX/a.md"
  assert_no_file "$SANDBOX/b.md"
  dot plugins:new acme/widgets widgets
  manifest "$SANDBOX/widgets" "link:plugin.json->w1.json->w2.json" "append:plugin.json->@dot:STANDARDS.md->notes.md"
  add_plugin acme/widgets widgets
  assert_equal "$(map_value '.inactive["acme/widgets"]["@plugin:acme.widgets:plugin.json"]')" '["w1.json","w2.json"]'
  assert_equal "$(map_value '.inactive["acme/widgets"].append["@plugin:acme.widgets:plugin.json"]')" '["@dot:STANDARDS.md","notes.md"]'
  manifest "$SANDBOX/widgets" "link:plugin.json->ok.json->.git/config"
  validate_chain acme/widgets widgets
  assert_failure
  assert_equal "$STATUS" 1
}

validate_chain() {
  core "dot::use core.system.plugins.service core.system.plugins.manifest
    core.system.plugins.service::fetch $1 '' $2
    core.system.plugins.manifest::validate \"\$PLUGIN_SOURCE\" $1"
}

test_link_edits_only_what_changed_in_the_map() {
  cat > "$DOTDOT/dot.json" <<'MAP'
{
  "state": {"migrations": []},
  "links": {
  "@dot:AGENTS.md": ["AGENTS.md"],    "@dot:RULES.md": ["rules.md"],
  "append": {},
  "remove": {},
  "inactive": {}
  }
}
MAP
  dot plugins:new acme/widgets widgets
  add_plugin acme/widgets widgets
  assert_contains "$(cat "$DOTDOT/dot.json")" '  "@dot:AGENTS.md": ["AGENTS.md"],    "@dot:RULES.md": ["rules.md"],'
  assert_equal "$(map_value '.inactive["acme/widgets"]["@plugin:acme.widgets:skills/*"]')" '[".agents/skills/"]'
  links_before=$(sed '/"inactive"/,$d' "$DOTDOT/dot.json")
  core "dot::use core.system.plugins.service core.system.plugins.manifest
    core.system.plugins.service::uninstall acme/widgets >/dev/null
    core.system.plugins.manifest::unlock acme/widgets"
  dot link -y
  assert_success
  assert_equal "$(sed '/"inactive"/,$d' "$DOTDOT/dot.json")" "$links_before"
  assert_equal "$(map_value '.inactive')" '{}'
}

test_link_leaves_out_everything_of_a_module_a_feature_flag_turns_off() {
  mkdir -p "$DOTDOT/.core/modules/release/skills/dot-release-example"
  printf -- '---\nname: dot-release-example\ndescription: An example.\n---\n' > "$DOTDOT/.core/modules/release/skills/dot-release-example/SKILL.md"
  : > "$DOTDOT/.core/modules/release/notes.md"
  sandbox::settings '"featureFlags": {"release": true}, "links": {"@dotdotSkills": ["skills/"], "append": {}, "remove": {}, "inactive": {}}'
  dot link -y
  assert_success
  assert_link_to "$SANDBOX/skills/dot-release-example" "$DOTDOT/.core/modules/release/skills/dot-release-example"
  sandbox::settings '"featureFlags": {}, "links": {"@dotdotSkills": ["skills/"], "@module:release:skills/dot-release-example": ["one/dot-release-example"], "append": {"@module:release:notes.md": ["notes.md"]}, "remove": {}, "inactive": {}}'
  dot link -y
  assert_link_to "$SANDBOX/skills/dot-onboard" "$DOTDOT/.core/modules/onboarding/skills/dot-onboard"
  assert_no_file "$SANDBOX/skills/dot-release-example"
  assert_no_file "$SANDBOX/one/dot-release-example"
  assert_failure
  assert_equal "$STATUS" 1
  assert_no_file "$SANDBOX/notes.md"
}

test_link_json_plans_then_applies_with_counts() {
  links "link:@dot:AGENTS.md->AGENTS.md"
  dot link --json
  assert_success
  assert_contains "$OUTPUT" '{"action":"link","origin":".dot/AGENTS.md","destination":"AGENTS.md"}'
  assert_no_file "$SANDBOX/AGENTS.md"
  dot link --json -y
  assert_success
  assert_contains "$OUTPUT" '"failed":0'
  assert_link_to "$SANDBOX/AGENTS.md" "$DOTDOT/AGENTS.md"
}
