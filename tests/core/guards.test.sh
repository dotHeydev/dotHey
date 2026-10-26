#!/usr/bin/env bash

test_guards_and_the_runtime_are_sealed() {
  local name
  for name in guards::link_destination dot::use kernel::run paths::plugins; do
    core "$name() { :; }"
    assert_failure "$name must be read-only"
  done
  core "SETTINGS_FILE=/tmp/elsewhere"
  assert_failure "SETTINGS_FILE must be read-only"
  core "HOST_ENV_FILE=/tmp/elsewhere"
  assert_failure "HOST_ENV_FILE must be read-only"
  core "dot::use core.system.link.service; core.system.link.service::plan() { :; }"
  assert_failure "a loaded core module must be read-only"
  core "dot::use core.system.link.service; DOT_LOADED_MODULES=' '; dot::use core.system.link.service"
  assert_failure "reloading a sealed module must fail"
}

test_plugin_commands_cannot_disarm_guards() {
  dot plugins:new acme/widgets --path widgets
  add_plugin acme/widgets widgets
  printf '#!/usr/bin/env bash\nDESCRIPTION="Probe."\nusage() { :; }\nhandle() { guards::link_destination() { return 0; }; echo disarmed; }\n' > "$DOTDOT/.plugins/acme/widgets/commands/probe.sh"
  dot acme:probe
  assert_failure
  assert_not_contains "$OUTPUT" "disarmed"
  printf '#!/usr/bin/env bash\nDESCRIPTION="Probe."\nusage() { :; }\nhandle() { DOT_PLUGIN=""; echo spoofed; }\n' > "$DOTDOT/.plugins/acme/widgets/commands/probe.sh"
  dot acme:probe
  assert_failure
  assert_not_contains "$OUTPUT" "spoofed"
}

test_yes_needs_a_terminal_or_dotdot_itself() {
  local DOT_INTERNAL_CALL=""
  dot link -y
  assert_failure
  assert_contains "$ERRORS" "-y applies changes unseen"
  assert_no_file "$SANDBOX/AGENTS.md"
  DOT_INTERNAL_CALL=1
  dot link -y
  assert_success
  assert_link_to "$SANDBOX/AGENTS.md" "$DOTDOT/AGENTS.md"
}

test_plugin_links_into_protected_paths_are_reported_and_never_applied() {
  dot plugins:new acme/widgets --path widgets
  manifest "$SANDBOX/widgets" "append:plugin.json->@dot:AGENTS.md"
  validate_guarded acme/widgets widgets
  assert_success "a protected destination is only reported"
  assert_contains "$ERRORS" "acme/widgets suggests to append to .dot/AGENTS.md, which plugins.denyLinkDestination protects; it never applies, even once activated."
  add_plugin acme/widgets widgets
  dot link:activate acme/widgets
  dot link -y
  assert_success
  assert_contains "$ERRORS" "Skipped acme/widgets's append to .dot/AGENTS.md from @plugin:acme.widgets:plugin.json: plugins.denyLinkDestination protects it."
  assert_not_contains "$(cat "$DOTDOT/AGENTS.md")" "acme/widgets"
  core "dot::use framework.helpers.json framework.helpers.fs
    framework.helpers.json::set \"\$(cat '$DOTDOT/dot.json')\" .plugins.denyLinkDestination '[]' | framework.helpers.fs::write '$DOTDOT/dot.json'"
  dot link -y
  assert_success
  assert_contains "$(cat "$DOTDOT/AGENTS.md")" "<!-- acme/widgets -->"
  core "dot::use framework.helpers.json framework.helpers.fs
    framework.helpers.json::set \"\$(cat '$DOTDOT/dot.json')\" .plugins.denyLinkOrigin '[\"@plugin:acme.widgets:*\"]' | framework.helpers.fs::write '$DOTDOT/dot.json'"
  dot link -y
  assert_contains "$ERRORS" "plugins.denyLinkOrigin protects it"
}

test_nothing_links_or_appends_to_the_projects_env() {
  dot plugins:new acme/widgets --path widgets
  printf 'DOT_GH_TOKEN=evil\n' > "$SANDBOX/widgets/dotdot/token.env"
  add_plugin acme/widgets widgets
  links "append:@plugin:acme.widgets:token.env->.env" "link:@dot:AGENTS.md->.env"
  dot link -y
  assert_failure
  assert_contains "$ERRORS" "Append destination '.env' must be a project file outside .git other than the .env"
  assert_contains "$ERRORS" "Destination '.env' is inside dotdot or git, or is the dot entry point or the .env"
  assert_no_file "$SANDBOX/.env"
}

test_appends_never_delete_files_they_did_not_create() {
  : > "$SANDBOX/empty.md"
  links "append:@dot:STANDARDS.md->empty.md->made.md"
  dot link -y
  assert_success
  links "remove:@dot:STANDARDS.md->empty.md->made.md"
  dot link -y
  assert_success
  assert_file "$SANDBOX/empty.md"
  assert_no_file "$SANDBOX/made.md"
}

test_one_plugin_region_per_destination_is_reported() {
  dot plugins:new acme/widgets --path widgets
  add_plugin acme/widgets widgets
  links "append:@plugin:acme.widgets:plugin.json->notes.conf" "append:@plugin:acme.widgets:commands/hello.sh->notes.conf"
  dot link -y
  assert_failure
  assert_contains "$ERRORS" "would share acme/widgets's region in notes.conf"
}


test_plugin_archives_may_not_leave_their_folder() {
  mkdir -p "$SANDBOX/evil/dotdot"
  printf 'x\n' > "$SANDBOX/evil/escape"
  (cd "$SANDBOX/evil" && tar -czf "$SANDBOX/good.tar.gz" dotdot && tar -czPf "$SANDBOX/bad.tar.gz" dotdot "$SANDBOX/evil/escape")
  core "guards::archive '$SANDBOX/good.tar.gz'"
  assert_success
  core "guards::archive '$SANDBOX/bad.tar.gz'"
  assert_failure
}

validate_guarded() {
  core "dot::use core.system.plugins.service core.system.plugins.manifest
    core.system.plugins.service::fetch $1 '' $2
    core.system.plugins.manifest::validate \"\$PLUGIN_SOURCE\" $1"
}
