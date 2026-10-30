#!/usr/bin/env bash
# Shared by f002's tests: the links map edited as a user does, and harnesses
# that fail on purpose.

. "$(dirname -- "${BASH_SOURCE[0]}")/../f001--install-plug-and-play/helpers.sh"

# Deletes <path> (under .links) from .dot/dot.json, as a user does by hand.
delete_link() {
  core "dot::use framework.helpers.json; framework.helpers.json::delete \"\$(cat '$DOTDOT/dot.json')\" '.links$1' --keep-format > '$DOTDOT/dot.json.new' && mv '$DOTDOT/dot.json.new' '$DOTDOT/dot.json'"
  assert_success "delete .links$1"
}

# An agent dotdot owns, in Claude's format.
owned_agent() {
  mkdir -p "$DOTDOT/Agents"
  printf -- '---\nname: %s\ndescription: %s\n---\n\n%s\n' "$1" "${2:-Reviews changes.}" "${3:-You review code.}" > "$DOTDOT/Agents/$1.md"
}

# Codex's renderer made to fail, as a broken harness script would.
failing_codex_render() {
  printf '\ncore.harnesses.codex.harness::agents_render() { return 1; }\n' >> "$DOTDOT/.core/harnesses/codex/harness.sh"
}
