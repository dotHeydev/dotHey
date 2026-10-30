# shellcheck shell=bash
# Shared by f002's tests: the links map edited as a user does, and harnesses
# that fail on purpose.

. "$(dirname -- "${BASH_SOURCE[0]}")/../f001--install-plug-and-play/helpers.sh"

# Deletes <path> (under .links) from .hey/hey.json, as a user does by hand.
delete_link() {
  core "hey::use framework.helpers.json; framework.helpers.json::delete \"\$(cat '$DOTHEY/hey.json')\" '.links$1' --keep-format > '$DOTHEY/hey.json.new' && mv '$DOTHEY/hey.json.new' '$DOTHEY/hey.json'"
  assert_success "delete .links$1"
}

# An agent dotHey owns, in Claude's format.
owned_agent() {
  mkdir -p "$DOTHEY/Agents"
  printf -- '---\nname: %s\ndescription: %s\n---\n\n%s\n' "$1" "${2:-Reviews changes.}" "${3:-You review code.}" > "$DOTHEY/Agents/$1.md"
}

# Codex's renderer made to fail, as a broken harness script would.
failing_codex_render() {
  printf '\ncore.harnesses.codex.harness::agents_render() { return 1; }\n' >> "$DOTHEY/.core/harnesses/codex/harness.sh"
}
