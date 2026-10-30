# shellcheck shell=bash

scaffold_plugin() {
  dot plugins:new "$1"
  assert_success "scaffold $1"
}

test_new_plugin_installs_and_runs_under_its_owner() {
  links "link:@dotdotSkills->.claude/skills"
  scaffold_plugin acme/widgets
  printf -- '---\ndescription: d\n---\n\nwidgets rule\n' > "$SANDBOX/widgets/dotdot/context/STANDARDS.md"
  add_plugin acme/widgets widgets
  take_suggestions acme/widgets
  dot link -y
  dot acme:hello dotdot
  assert_success
  assert_contains "$OUTPUT" "Hello, dotdot!"
  assert_contains "$(cat "$DOTDOT/STANDARDS.md")" "widgets rule"
  assert_link_to "$SANDBOX/.agents/skills/widgets-example" "$DOTDOT/.plugins/acme/widgets/skills/widgets-example"
  dot plugins:list
  assert_contains "$OUTPUT" "acme/widgets  path:widgets"
}

test_only_the_dotdot_folder_is_installed() {
  scaffold_plugin acme/widgets
  printf 'repository readme\n' > "$SANDBOX/widgets/README.md"
  add_plugin acme/widgets widgets
  assert_file "$DOTDOT/.plugins/acme/widgets/plugin.json"
  assert_no_file "$DOTDOT/.plugins/acme/widgets/README.md"
  assert_no_file "$DOTDOT/.plugins/acme/widgets/dotdot"
}

test_plugin_add_needs_a_terminal_even_with_yes() {
  scaffold_plugin acme/widgets
  dot plugins:add acme/widgets --from ./widgets --yes
  assert_failure
  assert_equal "$STATUS" 5
  assert_no_file "$DOTDOT/.plugins/acme"
}

test_plugin_ids_are_owner_and_name() {
  dot plugins:add widgets --from ./widgets
  assert_failure
  assert_equal "$STATUS" 1
  dot plugins:add acme/Not_Valid
  assert_failure
  assert_equal "$STATUS" 1
}

test_repos_without_a_dotdot_folder_are_refused() {
  mkdir -p "$SANDBOX/plain"
  core "dot::use core.system.plugins.service; core.system.plugins.service::fetch acme/plain '' plain"
  assert_failure
  assert_equal "$STATUS" 1
}

test_plugin_must_target_this_api() {
  scaffold_plugin acme/widgets
  sed -i.bak 's/"requires": [0-9]*/"requires": 99/' "$SANDBOX/widgets/dotdot/plugin.json"
  core "dot::use core.system.plugins.service core.system.plugins.manifest
    core.system.plugins.service::fetch acme/widgets '' widgets
    core.system.plugins.manifest::validate \"\$PLUGIN_SOURCE\" acme/widgets"
  assert_failure
  assert_equal "$STATUS" 1
}

test_plugin_commands_follow_the_layout() {
  scaffold_plugin acme/widgets
  mkdir -p "$SANDBOX/widgets/dotdot/commands/a/b"
  : > "$SANDBOX/widgets/dotdot/commands/a/b/deep.sh"
  core "dot::use core.system.plugins.service core.system.plugins.manifest
    core.system.plugins.service::fetch acme/widgets '' widgets
    core.system.plugins.manifest::validate \"\$PLUGIN_SOURCE\" acme/widgets"
  assert_failure
  assert_equal "$STATUS" 1
}

validate_plugin() {
  core "dot::use core.system.plugins.service core.system.plugins.manifest
    core.system.plugins.service::fetch $1 '' $2
    core.system.plugins.manifest::validate \"\$PLUGIN_SOURCE\" $1"
}

test_local_plugin_repos_install_as_committed_and_record_their_commit() {
  local commit
  scaffold_plugin acme/widgets
  git -C "$SANDBOX/widgets" init -q -b main
  git -C "$SANDBOX/widgets" add -A
  git -C "$SANDBOX/widgets" -c user.name=t -c user.email=t@t -c commit.gpgsign=false commit -qm first
  commit=$(git -C "$SANDBOX/widgets" rev-parse HEAD)
  printf 'not committed\n' > "$SANDBOX/widgets/dotdot/context/DRAFT.md"
  add_plugin acme/widgets widgets
  assert_contains "$(cat "$DOTDOT/.plugins/plugins-lock.json")" "{\"id\": \"acme/widgets\", \"origin\": \"path:widgets\", \"ref\": \"main\", \"commit\": \"$commit\", \"directory\": \"widgets\"}"
  assert_no_file "$DOTDOT/.plugins/acme/widgets/context/DRAFT.md"
  core "dot::use core.system.plugins.service; core.system.plugins.service::fetch acme/widgets nope widgets"
  assert_failure
  assert_equal "$STATUS" 1
  rm -rf "$SANDBOX/widgets/.git"
  core "dot::use core.system.plugins.service; core.system.plugins.service::fetch acme/widgets main widgets"
  assert_failure
  assert_equal "$STATUS" 1
}

test_taken_commands_are_refused() {
  scaffold_plugin acme/widgets
  scaffold_plugin acme/gadgets
  add_plugin acme/widgets widgets
  validate_plugin acme/gadgets gadgets
  assert_failure
  assert_equal "$STATUS" 1
}

test_owner_may_not_be_a_core_command_name() {
  scaffold_plugin tasks/widgets
  validate_plugin tasks/widgets widgets
  assert_failure
  assert_equal "$STATUS" 1
}

test_linked_entries_may_have_any_name_and_a_clash_is_reported() {
  scaffold_plugin acme/widgets
  mkdir -p "$SANDBOX/widgets/dotdot/skills/dot-onboard" "$SANDBOX/widgets/dotdot/skills/review"
  : > "$SANDBOX/widgets/dotdot/skills/review/SKILL.md"
  validate_plugin acme/widgets widgets
  assert_success
  assert_contains "$ERRORS" "skills/dot-onboard"
  assert_not_contains "$ERRORS" "skills/review"
}

test_linked_entries_that_clash_between_plugins_are_reported_and_the_first_wins() {
  scaffold_plugin acme/widgets
  add_plugin acme/widgets widgets
  dot plugins:new other/widgets other
  assert_success
  rm -f "$SANDBOX/other/dotdot/commands/hello.sh"
  validate_plugin other/widgets other
  assert_success "a clashing skill is only reported"
  assert_contains "$ERRORS" "skills/widgets-example"
  add_plugin other/widgets other
  dot plugins:link acme/widgets -y
  dot plugins:link other/widgets -y
  dot link -y
  assert_success
  assert_link_to "$SANDBOX/.agents/skills/widgets-example" "$DOTDOT/.plugins/acme/widgets/skills/widgets-example"
}

test_link_never_lets_a_plugin_replace_a_core_link() {
  scaffold_plugin acme/widgets
  add_plugin acme/widgets widgets
  mkdir -p "$DOTDOT/.plugins/acme/widgets/skills/dot-onboard"
  : > "$DOTDOT/.plugins/acme/widgets/skills/dot-onboard/SKILL.md"
  links "link:@dot:AGENTS.md->AGENTS.md" "link:@dotdotSkills->.claude/skills/" "link:@dot:RULES.md->.claude/rules/RULES.md" \
    "link:@pluginsSkills->.claude/skills" "link:@plugin:acme.widgets:plugin.json->AGENTS.md" "link:@dot:SECURITY.md->.claude/rules/RULES.md"
  dot link -y
  assert_success
  assert_link_to "$SANDBOX/AGENTS.md" "$DOTDOT/AGENTS.md"
  assert_link_to "$SANDBOX/.claude/skills/dot-onboard" "$DOTDOT/.core/modules/onboarding/skills/dot-onboard"
  assert_link_to "$SANDBOX/.claude/rules/RULES.md" "$DOTDOT/RULES.md"
}

test_link_never_links_secrets_or_into_git() {
  scaffold_plugin acme/widgets
  add_plugin acme/widgets widgets
  printf 'DOT_GH_TOKEN=secret\n' > "$SANDBOX/.env"
  links "link:@dot:../.env->leak" "link:@dot:../../.env->leak2" "append:@dot:../.env->leak3" "append:@plugin:acme.widgets:plugin.json->@dot:x.conf" \
    "append:@dot:AGENTS.md->.git/config->@dot:Notes/x.md" "link:@plugin:acme.widgets:plugin.json->.git/hooks/pre-commit->@dot:AGENTS.md"
  dot link -y
  assert_failure
  assert_equal "$STATUS" 1
  assert_no_file "$SANDBOX/leak"
  assert_no_file "$SANDBOX/leak2"
  assert_no_file "$SANDBOX/.git/hooks/pre-commit"
  [ ! -L "$DOTDOT/AGENTS.md" ] || fail "a plugin linked into dotdot"
  assert_no_file "$SANDBOX/leak3"
  assert_no_file "$DOTDOT/x.conf"
  assert_no_file "$SANDBOX/.git/config"
  assert_no_file "$DOTDOT/Notes/x.md"
}

test_plugin_links_are_validated_when_added() {
  local setting index=0 statuses=""
  scaffold_plugin acme/widgets
  while IFS= read -r setting; do
    index=$((index + 1))
    cp -R "$SANDBOX/widgets" "$SANDBOX/case$index"
    manifest "$SANDBOX/case$index" "$setting"
  done <<'CASES'
link:../x->y
link:@dot:dot.json->y
link:@dot:Notes/x.md->y
link:@module:notes:skills->y
link:@pluginsSkills->y
link:@plugin:other.x:skills->y
link:plugin.json->.git/config
link:plugin.json->../outside
link:plugin.json->@dot:x
link:plugin.json->dot
link:plugin.json->.env
link:missing.conf->x
append:../x->y
append:commands->y
append:plugin.json->@dot:Notes/x.md
append:plugin.json->.git/config
append:plugin.json->.env
append:plugin.json->@dot:dot.json
CASES
  # One process validates every case, each in its own subshell.
  core "for index in \$(seq 1 $index); do
      ( dot::use core.system.plugins.service core.system.plugins.manifest
        core.system.plugins.service::fetch acme/widgets '' case\$index 2>/dev/null
        core.system.plugins.manifest::validate \"\$PLUGIN_SOURCE\" acme/widgets ) 2>/dev/null && status=0 || status=\$?
      printf '%s ' \$status
    done"
  statuses="$OUTPUT"
  assert_equal "$statuses" "$(printf '1 %.0s' $(seq 1 "$index"))"
  manifest "$SANDBOX/widgets" "append:plugin.json->@dot:STANDARDS.md->AGENTS.md" "link:skills/*->x" "link:@dot:RULES.md->rules.md" "link:@plugin:acme.widgets:commands->cmd" "link:@dotdotSkills->.h/skills"
  validate_plugin acme/widgets widgets
  assert_success
  printf '{"description": "d", "links": ["a->b"], "x-notes": {"any": "thing"}}\n' > "$SANDBOX/widgets/dotdot/plugin.json"
  validate_plugin acme/widgets widgets
  assert_success "keys outside the schema are ignored"
  printf '{"description": "d", "link": {"plugin.json": "x"}}\n' > "$SANDBOX/widgets/dotdot/plugin.json"
  validate_plugin acme/widgets widgets
  assert_failure
  assert_equal "$STATUS" 1
}

test_plugin_link_destinations_that_clash_are_reported() {
  scaffold_plugin acme/widgets
  manifest "$SANDBOX/widgets" "link:plugin.json->widgets.conf"
  add_plugin acme/widgets widgets
  dot plugins:new other/gadgets gadgets
  manifest "$SANDBOX/gadgets" "link:plugin.json->widgets.conf"
  validate_plugin other/gadgets gadgets
  assert_success "a destination another plugin suggests too is only reported"
  assert_contains "$ERRORS" "widgets.conf"
}

test_lock_keeps_plugin_names_apart() {
  scaffold_plugin acme-x/y
  dot plugins:new acme/x-y other
  assert_success
  add_plugin acme-x/y y
  add_plugin acme/x-y other
  assert_equal "$(cat "$DOTDOT/.plugins/plugins-lock.json")" '{
  "plugins": [
    {"id": "acme-x/y", "origin": "path:y", "ref": "-", "commit": "-", "directory": "y"},
    {"id": "acme/x-y", "origin": "path:other", "ref": "-", "commit": "-", "directory": "x-y"}
  ]
}'
  core "dot::use core.system.plugins.manifest
    core.system.plugins.manifest::unlock acme/x-y
    core.system.plugins.manifest::installed"
  assert_equal "$OUTPUT" "acme-x/y"
}

test_plugin_remove_takes_back_its_links_and_appends_and_keeps_project_records() {
  links "link:@pluginsSkills->.claude/skills"
  scaffold_plugin acme/widgets
  printf -- '---\ndescription: d\n---\n\nwidgets rule\n' > "$SANDBOX/widgets/dotdot/context/STANDARDS.md"
  manifest "$SANDBOX/widgets"
  add_plugin acme/widgets widgets
  take_suggestions acme/widgets
  dot link -y
  assert_contains "$(cat "$DOTDOT/STANDARDS.md")" "widgets rule"
  assert_link_to "$SANDBOX/.agents/skills/widgets-example" "$DOTDOT/.plugins/acme/widgets/skills/widgets-example"
  assert_link_to "$SANDBOX/.claude/skills/widgets-example" "$DOTDOT/.plugins/acme/widgets/skills/widgets-example"
  mkdir -p "$DOTDOT/Widgets"
  printf 'kept\n' > "$DOTDOT/Widgets/w001.md"
  dot plugins:remove acme/widgets
  assert_failure
  assert_equal "$STATUS" 5
  core "dot::use core.system.plugins.service core.system.plugins.manifest
    core.system.plugins.service::uninstall acme/widgets
    core.system.plugins.manifest::unlock acme/widgets"
  dot link --remove-uninstalled -y
  assert_success
  assert_file "$DOTDOT/Widgets/w001.md"
  assert_no_file "$DOTDOT/.plugins/acme"
  assert_no_file "$SANDBOX/.agents/skills/widgets-example"
  assert_no_file "$SANDBOX/.claude/skills/widgets-example"
  assert_not_contains "$(cat "$DOTDOT/STANDARDS.md")" "widgets rule"
  assert_not_contains "$(cat "$DOTDOT/dot.json")" "acme/widgets"
  dot link -y
  assert_success
}

test_plugin_remove_without_links_sweeps_nothing() {
  scaffold_plugin acme/widgets
  add_plugin acme/widgets widgets
  printf 'mine\n<!-- acme/widgets -->\nkept\n<!-- /acme/widgets -->\n' > "$DOTDOT/STANDARDS.md"
  sandbox::settings
  core "dot::use core.system.plugins.service core.system.plugins.manifest
    core.system.plugins.service::uninstall acme/widgets
    core.system.plugins.manifest::unlock acme/widgets"
  dot link --remove-uninstalled -y
  assert_success
  assert_equal "$OUTPUT" ""
  assert_contains "$(cat "$DOTDOT/STANDARDS.md")" "kept"
  assert_not_contains "$(cat "$DOTDOT/dot.json")" "links"
}

test_plugin_stubs_are_appended_and_never_overwrite() {
  scaffold_plugin acme/widgets
  mkdir -p "$SANDBOX/widgets/dotdot/stubs/conf"
  printf 'theirs\n' > "$SANDBOX/widgets/dotdot/stubs/widgets.conf.stub"
  printf 'theirs\n' > "$SANDBOX/widgets/dotdot/stubs/conf/fresh.conf.stub"
  printf '{"theirs": true}\n' > "$SANDBOX/widgets/dotdot/stubs/settings.json.stub"
  printf '{"theirs": true}\n' > "$SANDBOX/widgets/dotdot/stubs/mine.json.stub"
  printf 'mine\n' > "$SANDBOX/widgets.conf"
  printf '{"mine": true}\n' > "$SANDBOX/mine.json"
  add_plugin acme/widgets widgets
  assert_no_file "$SANDBOX/conf/fresh.conf"
  take_suggestions acme/widgets
  dot link -y
  assert_success
  assert_equal "$(cat "$SANDBOX/widgets.conf")" "mine

# acme/widgets
theirs
# /acme/widgets"
  assert_equal "$(cat "$SANDBOX/conf/fresh.conf")" "# acme/widgets (new file)
theirs
# /acme/widgets"
  assert_equal "$(cat "$SANDBOX/settings.json")" '{"theirs": true}'
  assert_equal "$(cat "$SANDBOX/mine.json")" '{"mine": true}'
  dot link -y
  assert_success
  add_entry skip "@plugin:acme.widgets:stubs" widgets.conf
  add_entry skip "@plugin:acme.widgets:stubs" conf/fresh.conf
  add_entry skip "@plugin:acme.widgets:stubs" settings.json
  dot link -y
  assert_success
  assert_equal "$(cat "$SANDBOX/widgets.conf")" "mine"
  assert_no_file "$SANDBOX/conf/fresh.conf"
  assert_equal "$(cat "$SANDBOX/settings.json")" '{"theirs": true}'
}

test_plugin_settings_are_written_into_dot_json_and_read_from_there_only() {
  scaffold_plugin acme/widgets
  printf '{"requires": 3, "settings": {"Bad_Key": 1}}\n' > "$SANDBOX/widgets/dotdot/plugin.json"
  validate_plugin acme/widgets widgets
  assert_failure
  assert_equal "$STATUS" 1
  printf '{"requires": 3, "settings": {"url": "@env:URL"}}\n' > "$SANDBOX/widgets/dotdot/plugin.json"
  validate_plugin acme/widgets widgets
  assert_failure
  assert_equal "$STATUS" 1
  sandbox::settings '"plugins": {"acme/widgets": {"mode": "mine"}}'
  printf '{"requires": 3, "description": "d", "settings": {"mode": "fast", "apiUrl": "https://a.test", "strict": false}}\n' > "$SANDBOX/widgets/dotdot/plugin.json"
  add_plugin acme/widgets widgets
  assert_equal "$(core "dot::use framework.helpers.json; framework.helpers.json::encoded \"\$(cat '$DOTDOT/dot.json')\" '.plugins[\"acme/widgets\"]'"; printf '%s' "$OUTPUT")" '{"mode":"mine","apiUrl":"https://a.test","strict":false}'
  printf '#!/usr/bin/env bash\nDESCRIPTION="Probe."\nusage() { :; }\nhandle() { "$1" "$2"; }\n' > "$DOTDOT/.plugins/acme/widgets/commands/probe.sh"
  dot acme:probe dot::plugin_setting mode
  assert_success
  assert_equal "$OUTPUT" "mine"
  dot acme:probe dot::plugin_setting strict
  assert_equal "$OUTPUT" "false"
  sandbox::settings '"plugins": {"acme/widgets": {"apiUrl": "@env:WIDGETS_URL"}}, "tasks": {"service": "github"}'
  printf 'WIDGETS_URL=https://env.test\n' > "$SANDBOX/.env"
  dot acme:probe dot::plugin_setting apiUrl
  assert_equal "$OUTPUT" "https://env.test"
  dot acme:probe dot::plugin_setting mode
  assert_failure "plugin.json is never read for a setting"
  assert_equal "$STATUS" 1
  dot acme:probe dot::setting tasks.service
  assert_success "a plugin reads dotdot's settings"
  assert_equal "$OUTPUT" "github"
  dot acme:probe dot::save_setting tasks.service
  assert_failure
  assert_equal "$STATUS" 1
  core "dot::plugin_setting mode"
  assert_failure
  assert_equal "$STATUS" 1
}

test_plugin_secrets_carry_the_plugin_prefix() {
  scaffold_plugin acme/widgets
  add_plugin acme/widgets widgets
  printf 'DOT_GH_TOKEN=secret\nDOT_ACME_WIDGETS__KEY=own\n' > "$SANDBOX/.env"
  printf '#!/usr/bin/env bash\nDESCRIPTION="Probe."\nusage() { :; }\nhandle() { dot::secret "$1"; }\n' > "$DOTDOT/.plugins/acme/widgets/commands/probe.sh"
  dot acme:probe DOT_ACME_WIDGETS__KEY
  assert_success
  assert_equal "$OUTPUT" "own"
  dot acme:probe DOT_GH_TOKEN
  assert_failure
  assert_equal "$STATUS" 2
}

test_plugins_get_no_paths_outside_their_folder() {
  local kind
  scaffold_plugin acme/widgets
  add_plugin acme/widgets widgets
  printf '#!/usr/bin/env bash\nDESCRIPTION="Probe."\nusage() { :; }\nhandle() { dot::path "$1"; }\n' > "$DOTDOT/.plugins/acme/widgets/commands/probe.sh"
  for kind in data env; do
    dot acme:probe "$kind"
    assert_failure "dot::path $kind"
    assert_equal "$STATUS" 1
  done
  dot acme:probe plugin
  assert_success
  assert_equal "$OUTPUT" "$DOTDOT/.plugins/acme/widgets"
}

test_plugin_stubs_may_not_seed_git() {
  scaffold_plugin acme/widgets
  mkdir -p "$SANDBOX/widgets/dotdot/stubs/.git/hooks"
  printf 'theirs\n' > "$SANDBOX/widgets/dotdot/stubs/.git/hooks/pre-commit.stub"
  core "dot::use core.system.plugins.manifest core.system.plugins.service
    core.system.plugins.service::fetch acme/widgets '' widgets
    core.system.plugins.manifest::validate \"\$PLUGIN_SOURCE\" acme/widgets"
  assert_failure
  assert_equal "$STATUS" 1
}

test_plugin_update_lists_what_changed() {
  scaffold_plugin acme/widgets
  add_plugin acme/widgets widgets
  sed -i.bak 's/Hello/Howdy/' "$SANDBOX/widgets/dotdot/commands/hello.sh"
  rm -f "$SANDBOX/widgets/dotdot/commands/hello.sh.bak"
  core "dot::use core.system.plugins.service
    core.system.plugins.service::fetch acme/widgets '' widgets
    core.system.plugins.service::changed_files acme/widgets \"\$PLUGIN_SOURCE\""
  assert_success
  assert_equal "$OUTPUT" "changed	commands/hello.sh"
}

test_plugin_new_stays_inside_the_project() {
  dot plugins:new acme/widgets ../outside
  assert_failure
  assert_equal "$STATUS" 1
}

test_plugins_cannot_reach_core_internals_or_each_other() {
  local module
  scaffold_plugin acme/widgets
  scaffold_plugin other/gizmos
  add_plugin acme/widgets widgets
  add_plugin other/gizmos gizmos
  printf '#!/usr/bin/env bash\nother.gizmos::x() { :; }\n' > "$DOTDOT/.plugins/other/gizmos/tool.sh"
  for module in core.modules.notes.service framework.integrations.github.internal.route plugins.other.gizmos.tool; do
    printf '#!/usr/bin/env bash\nDESCRIPTION="Probe."\nusage() { :; }\nhandle() { dot::use %s; }\n' "$module" > "$DOTDOT/.plugins/acme/widgets/commands/probe.sh"
    dot acme:probe
    assert_failure "$module must be private"
    assert_equal "$STATUS" 1
  done
  printf '#!/usr/bin/env bash\nDESCRIPTION="Probe."\nusage() { :; }\nhandle() { dot::use framework.helpers.text framework.console.output framework.integrations.github.service; framework.console.output::success ok; }\n' \
    > "$DOTDOT/.plugins/acme/widgets/commands/probe.sh"
  dot acme:probe
  assert_success
}

test_core_modules_keep_to_themselves() {
  printf '#!/usr/bin/env bash\ndot::use core.modules.tasks.service\n' > "$DOTDOT/.core/modules/notes/probe.sh"
  core ". '$DOTDOT/.core/modules/notes/probe.sh'"
  assert_failure
  assert_equal "$STATUS" 1
  printf '#!/usr/bin/env bash\ndot::use core.system.plugins.service\n' > "$DOTDOT/.core/system/link/probe.sh"
  core ". '$DOTDOT/.core/system/link/probe.sh'"
  assert_failure
  assert_equal "$STATUS" 1
  printf '#!/usr/bin/env bash\ndot::use framework.integrations.github.internal.route\n' > "$DOTDOT/.core/framework/helpers/probe.sh"
  core ". '$DOTDOT/.core/framework/helpers/probe.sh'"
  assert_failure
  assert_equal "$STATUS" 1
  printf '#!/usr/bin/env bash\ndot::use core.modules.notes.service framework.helpers.text\n' > "$DOTDOT/.core/modules/notes/probe.sh"
  core ". '$DOTDOT/.core/modules/notes/probe.sh'"
  assert_success
}

test_leftover_environment_variables_are_ignored() {
  mkdir -p "$SANDBOX/precious"
  : > "$SANDBOX/precious/keep"
  scaffold_plugin acme/widgets
  core "PLUGINS_WORKSPACE='$SANDBOX/precious' DOT_PLUGIN=other/gizmos; export PLUGINS_WORKSPACE DOT_PLUGIN
    bash ./dot plugins:list >/dev/null
    dot::use core.system.plugins.service; core.system.plugins.service::fetch acme/widgets '' widgets"
  assert_success
  assert_file "$SANDBOX/precious/keep"
}

test_unprefixed_owners_run_commands_without_their_prefix() {
  scaffold_plugin acme/widgets
  add_plugin acme/widgets widgets
  sandbox::settings '"plugins": {"unprefixedCommandOwners": "@env:OWNERS"}'
  printf 'OWNERS=["other", "acme", "Not_Valid"]\n' > "$SANDBOX/.env"
  dot
  assert_contains "$OUTPUT" "  hello "
  assert_not_contains "$OUTPUT" "acme:hello"
  dot hello dotdot
  assert_success
  assert_contains "$OUTPUT" "Hello, dotdot!"
  dot acme:hello dotdot
  assert_success
  printf 'OWNERS=\n' > "$SANDBOX/.env"
  dot hello dotdot
  assert_failure
  assert_equal "$STATUS" 2
}

test_unprefixed_commands_that_clash_keep_their_prefix() {
  scaffold_plugin acme/widgets
  add_plugin acme/widgets widgets
  mkdir -p "$DOTDOT/.plugins/acme/widgets/commands/plugins"
  printf '#!/usr/bin/env bash\nDESCRIPTION="Probe."\nusage() { :; }\nhandle() { echo hijacked; }\n' > "$DOTDOT/.plugins/acme/widgets/commands/plugins/list.sh"
  dot plugins:new other/gadgets gadgets
  add_plugin other/gadgets gadgets
  sandbox::settings '"plugins": {"unprefixedCommandOwners": ["acme", "other"]}'
  dot
  assert_contains "$OUTPUT" "acme:plugins:list"
  assert_contains "$OUTPUT" "  hello "
  assert_contains "$OUTPUT" "other:hello"
  dot plugins:list
  assert_success
  assert_not_contains "$OUTPUT" "hijacked"
  dot acme:plugins:list
  assert_success
  assert_contains "$OUTPUT" "hijacked"
  dot other:hello you
  assert_success
  assert_contains "$OUTPUT" "Hello, you!"
}

test_adding_a_plugin_creates_nothing_outside_its_folder() {
  scaffold_plugin acme/widgets
  manifest "$SANDBOX/widgets"
  find "$SANDBOX" -path "$SANDBOX/widgets" -prune -o -print | sort > "$SANDBOX/.before"
  add_plugin acme/widgets widgets
  find "$SANDBOX" -path "$SANDBOX/widgets" -prune -o -print | grep -v "^$SANDBOX/.dot/.plugins\|^$SANDBOX/.dot/dot.json$\|^$SANDBOX/.before$\|^$SANDBOX/.after$\|^$SANDBOX/.stderr$" | sort > "$SANDBOX/.after"
  assert_equal "$(comm -13 "$SANDBOX/.before" "$SANDBOX/.after")" ""
}

test_plugin_manifests_need_only_a_description() {
  scaffold_plugin acme/widgets
  printf '{"description": "Widgets."}\n' > "$SANDBOX/widgets/dotdot/plugin.json"
  validate_plugin acme/widgets widgets
  assert_success "requires, depends, settings, link, and append are optional"
  printf '{"requires": 3}\n' > "$SANDBOX/widgets/dotdot/plugin.json"
  validate_plugin acme/widgets widgets
  assert_failure
  assert_equal "$STATUS" 1
}

test_plugin_manifests_must_be_json_objects_with_lists() {
  local manifest
  scaffold_plugin acme/widgets
  for manifest in 'REQUIRES=2' '[1]' '{"description": "d", "link": "a->b"}' '{"description": "d", "depends": "jq"}' '{"description": "d", "requires": 1}' '{"description": "d", "settings": []}'; do
    printf '%s\n' "$manifest" > "$SANDBOX/widgets/dotdot/plugin.json"
    validate_plugin acme/widgets widgets
    assert_failure "$manifest must be refused"
    assert_equal "$STATUS" 1
  done
}


test_plugins_list_json_new_into_and_add_preview() {
  dot plugins:list --json
  assert_equal "$OUTPUT" "[]"
  dot plugins:new acme/widgets --into widgets
  assert_success
  assert_file "$SANDBOX/widgets/dotdot/plugin.json"
  dot plugins:add acme/widgets --from widgets --preview
  assert_success
  assert_no_file "$DOTDOT/.plugins/acme/widgets/dotdot/plugin.json"
  dot plugins:list --json
  assert_equal "$OUTPUT" "[]"
  add_plugin acme/widgets widgets
  dot plugins:list --json
  assert_equal "$(json_value "$OUTPUT" '.[0].name')" acme/widgets
  dot plugins:update nobody/here
  assert_equal "$STATUS" 4
}

test_plugin_remove_takes_its_settings_with_it() {
  mkdir -p "$SANDBOX/widgets/dotdot"
  printf '{"requires": 3, "description": "d", "settings": {"mode": "fast"}}\n' > "$SANDBOX/widgets/dotdot/plugin.json"
  add_plugin acme/widgets widgets
  core "dot::use core.system.plugins.service; core.system.plugins.service::uninstall acme/widgets"
  assert_success
  assert_equal "$(core "dot::use framework.helpers.json; framework.helpers.json::encoded \"\$(cat '$DOTDOT/dot.json')\" '.plugins[\"acme/widgets\"]'"; printf '%s' "$OUTPUT")" null
}

test_a_plugin_is_read_from_its_name_or_its_github_url_exactly() {
  local given expected
  while IFS='|' read -r given expected; do
    core "dot::use core.system.plugins.manifest
      id=\$(core.system.plugins.manifest::id '$given') || { printf refused; exit 0; }
      core.system.plugins.manifest::parse '$given'
      printf '%s %s %s' \"\$id\" \"\$PLUGIN_REPOSITORY\" \"\$PLUGIN_SPEC_REF\""
    assert_equal "$OUTPUT" "$expected"
  done <<'CASES'
acme/Widgets.git|acme/widgets acme/Widgets 
acme/my.plugin|acme/my.plugin acme/my.plugin 
acme/my_plugin@release/v1@2|acme/my_plugin acme/my_plugin release/v1@2
acme/_w|acme/_w acme/_w 
acme/w@fix#12|acme/w acme/w fix#12
https://github.com/acme/widgets/?tab=readme#top|acme/widgets acme/widgets 
https://github.com/acme/widgets/tree/feature/a-b|acme/widgets acme/widgets feature/a-b
https://github.com/acme/widgets/commit/0123abc|acme/widgets acme/widgets 0123abc
git@github.com:acme/widgets.git|acme/widgets acme/widgets 
https://gitlab.com/acme/widgets|refused
acme/w/blob/main/README.md|refused
acme/..|refused
-acme/w|refused
acme-/w|refused
acme--x/w|refused
acme/w@|refused
CASES
}

test_names_differing_only_in_dots_dashes_or_underscores_are_different_plugins() {
  local plugin
  for plugin in acme/my-plg acme/my.plg acme/my_plg; do
    mkdir -p "$SANDBOX/src/$plugin/dotdot"
    printf '{"requires": 3, "description": "%s", "settings": {"mode": "x"}}\n' "$plugin" > "$SANDBOX/src/$plugin/dotdot/plugin.json"
    add_plugin "$plugin" "src/$plugin"
  done
  core "dot::use core.system.plugins.manifest; core.system.plugins.manifest::installed"
  assert_equal "$OUTPUT" $'acme/my-plg\nacme/my.plg\nacme/my_plg'
  assert_file "$DOTDOT/.plugins/acme/my-plg/plugin.json"
  assert_equal "$(find "$DOTDOT/.plugins/acme" -mindepth 1 -maxdepth 1 -type d -name 'my-plg---*' | wc -l | tr -d ' ')" 2
  assert_equal "$(core "dot::use framework.helpers.json; framework.helpers.json::keys \"\$(cat '$DOTDOT/dot.json')\" .plugins" ; printf '%s' "$OUTPUT" | sort | paste -sd ' ' -)" "acme/my-plg acme/my.plg acme/my_plg"
}

test_a_name_in_any_case_is_the_same_plugin() {
  mkdir -p "$SANDBOX/src/dotdot"
  printf '{"requires": 3, "description": "d"}\n' > "$SANDBOX/src/dotdot/plugin.json"
  add_plugin acme/myplg src
  core "dot::use core.system.plugins.manifest; core.system.plugins.manifest::lock_entry \$(core.system.plugins.manifest::id acme/mYpLg)"
  assert_success
  core "dot::use core.system.plugins.manifest; core.system.plugins.manifest::id https://github.com/ACME/MyPlg"
  assert_equal "$OUTPUT" acme/myplg
}

test_a_plugin_in_a_suffixed_folder_works_by_its_name() {
  local folder
  mkdir -p "$SANDBOX/src/dotdot/skills/plg-skill"
  printf -- '---\nname: plg-skill\ndescription: d\n---\n' > "$SANDBOX/src/dotdot/skills/plg-skill/SKILL.md"
  printf '{"requires": 3, "description": "d", "settings": {"mode": "fast"}}\n' > "$SANDBOX/src/dotdot/plugin.json"
  add_plugin acme/my.plg src
  folder=$(find "$DOTDOT/.plugins/acme" -mindepth 1 -maxdepth 1 -type d -name 'my-plg---*')
  [ -n "$folder" ] || fail "no suffixed folder"
  assert_contains "$(cat "$DOTDOT/.plugins/plugins-lock.json")" "\"id\": \"acme/my.plg\""
  assert_contains "$(cat "$DOTDOT/.plugins/plugins-lock.json")" "\"directory\": \"${folder##*/}\""
  mkdir -p "$folder/commands"
  printf '#!/usr/bin/env bash\nDESCRIPTION="Probe."\nusage() { :; }\nhandle() { dot::plugin_setting mode; }\n' > "$folder/commands/probe.sh"
  dot acme:probe
  assert_success
  assert_equal "$OUTPUT" "fast"
  take_suggestions acme/my.plg
  dot link -y
  assert_success
  assert_link_to "$SANDBOX/.agents/skills/plg-skill" "$folder/skills/plg-skill"
  core "dot::use core.system.plugins.service; core.system.plugins.service::uninstall acme/my.plg"
  assert_success
  assert_no_file "$folder"
}
