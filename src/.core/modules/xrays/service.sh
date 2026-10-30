# shellcheck shell=bash

hey::use framework.helpers.date framework.helpers.fs framework.helpers.record framework.helpers.text

XRAY_TEMPLATE="$MODULES_DIR/xrays/skills/hey-xray/xray-template.md"
XRAY_STATUSES="open discussing blocked decided done"
XRAY_DEFAULT_STATUS="open"

# Writes the next numbered xray from the template: its frontmatter filled,
# its title the name as given.
core.modules.xrays.service::create() {
  local name="$1" slug="$2" description="$3" path now
  path=$(framework.helpers.record::next_path "$XRAYS_DIR" "$XRAY_PREFIX" "$slug") || return 1
  now=$(framework.helpers.date::now)
  {
    printf -- '---\nname: %s\ndescription: %s\nstatus: %s\ncreated: %s\nmodified: %s\n---\n\n# %s\n' \
      "$slug" "$description" "$XRAY_DEFAULT_STATUS" "$now" "$now" "$name"
    awk 'started { print } /^# / && !started { started = 1 }' "$XRAY_TEMPLATE"
  } | framework.helpers.fs::write "$path" || return 1
  printf '%s\n' "$path"
}
