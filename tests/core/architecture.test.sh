#!/usr/bin/env bash

FRAMEWORK_VARIABLES_PATTERN='\$\{?(BASE|DOTDOT_ROOT|DOTDOT_NAME|CORE_DIR|FRAMEWORK_DIR|BIN_DIR|DOT_BIN|PLUGINS_DIR|PLUGINS_LOCK|SETTINGS_FILE|SETTINGS_DEFAULTS|HOST_ENV_FILE|USER_FILE|USER_EXAMPLE_FILE|ENTRY_LINK)\b'

core_dir() {
  printf '%s\n' "$DOTDOT/.core"
}

search() {
  local pattern="$1"
  shift
  find "$@" -name '*.sh' -exec grep -nE "$pattern" {} + 2>/dev/null || true
}

module_path() {
  local file="$1" root="$2" prefix="$3" module
  module="${file#"$root"/}"
  module="${module%.sh}"
  printf '%s%s\n' "$prefix" "${module//\//.}"
}

misnamed_functions() {
  local root="$1" prefix="$2" file module
  shift 2
  while IFS= read -r file; do
    module=$(module_path "$file" "$root" "$prefix")
    grep -nE '^[a-z][a-z0-9_.-]*::[a-z0-9_]+\(\)' "$file" | grep -vE "^[0-9]+:$module::" | sed "s|^|$module: |"
  done < <(find "$root" -name '*.sh' "$@")
}

test_helpers_console_and_ui_know_nothing_about_dotdot() {
  local found
  found=$(search "core\.|plugins\.|integrations\.|$FRAMEWORK_VARIABLES_PATTERN" "$(core_dir)/framework/helpers" "$(core_dir)/framework/console" "$(core_dir)/framework/ui")
  [ -z "$found" ] || fail "helpers, console, and ui must stay project-agnostic:
$found"
}

test_framework_never_reaches_into_the_runtime_internals() {
  local found
  found=$(search "(kernel|paths)::|core\." "$(core_dir)/framework")
  [ -z "$found" ] || fail "framework code may use only the public dot:: API, never kernel::, paths::, or core modules:
$found"
}

test_integrations_expose_only_services() {
  local exposed
  exposed=$(find "$(core_dir)/framework/integrations" -name '*.sh' ! -path '*/internal/*' ! -name service.sh)
  [ -z "$exposed" ] || fail "integration code other than service.sh belongs in internal/:
$exposed"
}

test_services_never_talk_to_the_person() {
  local found
  found=$(find "$(core_dir)" \
    \( -name service.sh -o -path '*/drivers/*' ! -name '*-setup.sh' \) -exec grep -nE \
    'console\.(output|prompt|terminal)::|(^|[;&|[:space:]])exit([[:space:]]+[0-9$"]|[[:space:]]*$)|read( -[a-z]+)* -[a-z]*p' {} + || true)
  [ -z "$found" ] || fail "services return data and raise errors; they never print, prompt, or exit:
$found"
}

test_function_names_match_their_module_path() {
  local found
  local module
  found="$(misnamed_functions "$(core_dir)/framework" "framework." ! -path '*/commands/*')"
  for module in $(core_dir)/system/*/ $(core_dir)/modules/*/; do
    [ "$module" != "$(core_dir)/system/bin/" ] || continue
    module="${module%/}"
    found="$found$(misnamed_functions "$module" "core.$(basename -- "$(dirname -- "$module")").$(basename -- "$module")." ! -path '*/commands/*' ! -path '*/stubs/*' ! -path '*/migrations/*')"
  done
  found="$found$(grep -nE '^[a-z][a-z0-9_.-]*::[a-z0-9_]+\(\)' "$(core_dir)/system/kernel.sh" | grep -vE '^[0-9]+:kernel::' || true)"
  found="$found$(grep -nE '^[a-z][a-z0-9_.-]*::[a-z0-9_]+\(\)' "$(core_dir)/system/paths.sh" | grep -vE '^[0-9]+:paths::' || true)"
  found="$found$(grep -nE '^[a-z][a-z0-9_.-]*::[a-z0-9_]+\(\)' "$(core_dir)/system/guards.sh" | grep -vE '^[0-9]+:guards::' || true)"
  [ -z "$found" ] || fail "functions must be named <module path>::<name>:
$found"
}

test_function_names_are_defined_once() {
  local duplicates
  duplicates=$(find "$(core_dir)" -name '*.sh' ! -path '*/commands/*' ! -path '*/stubs/*' ! -path '*/migrations/*' \
    -exec grep -hoE '^[a-z][a-z0-9_.-]*::[a-z0-9_]+\(\)' {} + | sort | uniq -d)
  [ -z "$duplicates" ] || fail "functions defined more than once:
$duplicates"
}

test_commands_declare_the_command_contract() {
  local file missing=""
  while IFS= read -r file; do
    grep -q '^DESCRIPTION="' "$file" && grep -q '^usage()' "$file" && grep -q '^handle()' "$file" || missing="$missing $file"
  done < <(find "$(core_dir)" -path '*/commands/*' ! -path '*/stubs/*' -name '*.sh')
  [ -z "$missing" ] || fail "commands without DESCRIPTION, usage, or handle:$missing"
}


test_guards_only_decide() {
  local found
  found=$(grep -nE 'console\.|exit|dot::(raise|abort|use)|read -[a-z]*p|>>? *"?\$|(^|[;&|[:space:]])(rm|mv|cp|ln|mkdir) ' "$(core_dir)/system/guards.sh" | grep -v '^[0-9]*: *#' || true)
  [ -z "$found" ] || fail "guards are predicates: no output, prompts, exits, loads, or writes:
$found"
}

test_migrations_declare_the_migration_contract() {
  local file missing=""
  for file in "$(core_dir)"/system/migrations/*.sh; do
    [ -f "$file" ] || continue
    [[ "${file##*/}" =~ ^[0-9]{4}-[a-z0-9-]+\.sh$ ]] && grep -q '^DESCRIPTION="' "$file" && grep -q '^migrate()' "$file" \
      || missing="$missing ${file##*/}"
  done
  [ -z "$missing" ] || fail "migrations must be NNNN-<slug>.sh with DESCRIPTION and migrate:$missing"
}

test_temporary_files_come_only_from_the_fs_helper() {
  local found
  found=$(search '(^|[^a-z_])mktemp( |$|\))' "$(core_dir)" | grep -v "/framework/helpers/fs.sh:" || true)
  [ -z "$found" ] || fail "temporary files go through framework.helpers.fs::make_temp_dir or make_temp_file, for their fallback:
$found"
}
