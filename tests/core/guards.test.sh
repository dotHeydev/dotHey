# shellcheck shell=bash

test_guards_and_the_runtime_are_sealed() {
  local name
  for name in guards::link_destination hey::use kernel::run paths::plugins; do
    core "$name() { :; }"
    assert_failure "$name must be read-only"
    assert_equal "$STATUS" 1
  done
  core "SETTINGS_FILE=/tmp/elsewhere"
  assert_failure "SETTINGS_FILE must be read-only"
  assert_equal "$STATUS" 1
  core "HOST_ENV_FILE=/tmp/elsewhere"
  assert_failure "HOST_ENV_FILE must be read-only"
  assert_equal "$STATUS" 1
  core "hey::use core.system.link.service; core.system.link.service::plan() { :; }"
  assert_failure "a loaded core module must be read-only"
  assert_equal "$STATUS" 1
  core "hey::use core.system.link.service; HEY_LOADED_MODULES=' '; hey::use core.system.link.service"
  assert_failure "reloading a sealed module must fail"
  assert_equal "$STATUS" 1
}

test_plugin_commands_cannot_disarm_guards() {
  hey plugins:new acme/widgets widgets
  add_plugin acme/widgets widgets
  printf '#!/usr/bin/env bash\nDESCRIPTION="Probe."\nusage() { :; }\nhandle() { guards::link_destination() { return 0; }; echo disarmed; }\n' > "$DOTHEY/.plugins/acme/widgets/commands/probe.sh"
  hey acme:probe
  assert_failure
  assert_equal "$STATUS" 1
  assert_not_contains "$OUTPUT" "disarmed"
  printf '#!/usr/bin/env bash\nDESCRIPTION="Probe."\nusage() { :; }\nhandle() { HEY_PLUGIN=""; echo spoofed; }\n' > "$DOTHEY/.plugins/acme/widgets/commands/probe.sh"
  hey acme:probe
  assert_failure
  assert_equal "$STATUS" 1
  assert_not_contains "$OUTPUT" "spoofed"
}

test_yes_needs_a_terminal_or_dothey_itself() {
  local HEY_INTERNAL_CALL=""
  hey link -y
  assert_failure
  assert_equal "$STATUS" 5
  assert_no_file "$SANDBOX/AGENTS.md"
  HEY_INTERNAL_CALL=1
  hey link -y
  assert_success
  assert_link_to "$SANDBOX/AGENTS.md" "$DOTHEY/AGENTS.md"
}

test_plugin_links_into_protected_paths_are_reported_and_never_applied() {
  hey plugins:new acme/widgets widgets
  manifest "$SANDBOX/widgets" "append:plugin.json->@hey:AGENTS.md"
  validate_guarded acme/widgets widgets
  assert_success "a protected destination is only reported"
  assert_contains "$ERRORS" ".hey/AGENTS.md"
  add_plugin acme/widgets widgets
  hey plugins:link acme/widgets -y
  hey link -y
  assert_success
  assert_not_contains "$(cat "$DOTHEY/AGENTS.md")" "acme/widgets"
  core "hey::use framework.helpers.json framework.helpers.fs
    framework.helpers.json::set \"\$(cat '$DOTHEY/hey.json')\" .plugins.denyLinkDestination '[]' | framework.helpers.fs::write '$DOTHEY/hey.json'"
  hey link -y
  assert_success
  assert_contains "$(cat "$DOTHEY/AGENTS.md")" "<!-- acme/widgets -->"
  core "hey::use framework.helpers.json framework.helpers.fs
    framework.helpers.json::set \"\$(cat '$DOTHEY/hey.json')\" .plugins.denyLinkOrigin '[\"@plugin:acme.widgets:*\"]' | framework.helpers.fs::write '$DOTHEY/hey.json'"
  hey link -y
  assert_contains "$ERRORS" "denyLinkOrigin"
}

test_nothing_links_or_appends_to_the_projects_env() {
  hey plugins:new acme/widgets widgets
  printf 'HEY_GH_TOKEN=evil\n' > "$SANDBOX/widgets/dothey/token.env"
  add_plugin acme/widgets widgets
  links "append:@plugin:acme.widgets:token.env->.env" "link:@hey:AGENTS.md->.env"
  hey link -y
  assert_failure
  assert_equal "$STATUS" 1
  assert_no_file "$SANDBOX/.env"
}

test_appends_never_delete_files_they_did_not_create() {
  : > "$SANDBOX/empty.md"
  links "append:@hey:STANDARDS.md->empty.md->made.md"
  hey link -y
  assert_success
  links "skip:@hey:STANDARDS.md->empty.md->made.md"
  hey link -y
  assert_success
  assert_file "$SANDBOX/empty.md"
  assert_no_file "$SANDBOX/made.md"
}

test_one_plugin_region_per_destination_is_reported() {
  hey plugins:new acme/widgets widgets
  add_plugin acme/widgets widgets
  links "append:@plugin:acme.widgets:plugin.json->notes.conf" "append:@plugin:acme.widgets:commands/hello.sh->notes.conf"
  hey link -y
  assert_failure
  assert_equal "$STATUS" 1
}


test_plugin_archives_may_not_leave_their_folder() {
  mkdir -p "$SANDBOX/evil/dothey"
  printf 'x\n' > "$SANDBOX/evil/escape"
  (cd "$SANDBOX/evil" && tar -czf "$SANDBOX/good.tar.gz" dotHey && tar -czPf "$SANDBOX/bad.tar.gz" dotHey "$SANDBOX/evil/escape")
  core "guards::archive '$SANDBOX/good.tar.gz'"
  assert_success
  core "guards::archive '$SANDBOX/bad.tar.gz'"
  assert_failure
  assert_equal "$STATUS" 1
}

validate_guarded() {
  core "hey::use core.system.plugins.service core.system.plugins.manifest
    core.system.plugins.service::fetch $1 '' $2
    core.system.plugins.manifest::validate \"\$PLUGIN_SOURCE\" $1"
}
