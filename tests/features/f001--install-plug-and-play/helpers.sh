# shellcheck shell=bash
# Shared by f001's tests: projects in the states setup meets.

FEATURE_DIR=$(CDPATH='' cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# A skill the project already has, as a real directory.
own_skill() {
  mkdir -p "$SANDBOX/$1"
  printf -- '---\nname: %s\ndescription: The project'"'"'s own.\n---\n' "${1##*/}" > "$SANDBOX/$1/SKILL.md"
}

# The project's own instructions file, with a line dotHey must keep.
own_instructions() {
  mkdir -p "$(dirname -- "$SANDBOX/$1")"
  printf '# Ours\n\nKeep this line.\n' > "$SANDBOX/$1"
}

# What <path> selects in .hey/hey.json (or the hey.json at $2), one per line.
setting_value() {
  core "hey::use framework.helpers.json; framework.helpers.json::values \"\$(cat '${2:-$DOTHEY/hey.json}')\" '$1'"
  printf '%s' "$OUTPUT"
}

# A harness copied from <from> as <id>, its functions renamed to match.
copy_harness() {
  local from="$1" id="$2" file
  cp -R "$DOTHEY/.core/harnesses/$from" "$DOTHEY/.core/harnesses/$id"
  for file in "$DOTHEY/.core/harnesses/$id"/*.sh; do
    sed "s/core\.harnesses\.$from\./core.harnesses.$id./g" "$file" > "$file.new" && mv "$file.new" "$file"
  done
}

# Sets <key> of a harness's harness.json to the JSON <value>.
harness_data() {
  local file="$DOTHEY/.core/harnesses/$1/harness.json"
  core "hey::use framework.helpers.json; framework.helpers.json::set \"\$(cat '$file')\" '.$2' '$3' > '$file.new' && mv '$file.new' '$file'"
  assert_success "set $2 of harness $1"
}
