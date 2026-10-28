#!/usr/bin/env bash
. "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"

# An agent dotdot owns, in Claude's format.
owned_agent() {
  mkdir -p "$DOTDOT/Agents"
  printf -- '---\nname: %s\ndescription: %s\ntools: Read, Grep\n---\n\n%s\n' "$1" "${2:-Reviews changes.}" "${3:-You review code.}" > "$DOTDOT/Agents/$1.md"
}

# Golden

test_agents_link_as_they_are_where_the_format_matches() {
  owned_agent reviewer
  dot setup --harness claude,cursor,opencode --yes
  assert_success
  assert_link_to "$SANDBOX/.claude/agents/reviewer.md" "$DOTDOT/Agents/reviewer.md"
  assert_link_to "$SANDBOX/.cursor/agents/reviewer.md" "$DOTDOT/Agents/reviewer.md"
  assert_link_to "$SANDBOX/.opencode/agents/reviewer.md" "$DOTDOT/Agents/reviewer.md"
}

test_copilot_reads_each_agent_under_its_own_file_name() {
  owned_agent reviewer
  dot setup --harness copilot --yes
  assert_success
  assert_equal "$(cat "$SANDBOX/.github/agents/reviewer.agent.md")" "$(cat "$DOTDOT/Agents/reviewer.md")"
  [ -L "$SANDBOX/.github/agents/reviewer.agent.md" ] || fail "Copilot's agent isn't a link to dotdot's"
}

test_codex_gets_each_agent_as_toml() {
  owned_agent reviewer "Reviews changes." "You review code."
  dot setup --harness codex --yes
  assert_success
  assert_file "$SANDBOX/.codex/agents/reviewer.toml"
  assert_contains "$(cat "$SANDBOX/.codex/agents/reviewer.toml")" 'name = "reviewer"'
  assert_contains "$(cat "$SANDBOX/.codex/agents/reviewer.toml")" 'description = "Reviews changes."'
  assert_contains "$(cat "$SANDBOX/.codex/agents/reviewer.toml")" 'You review code.'
  assert_contains "$(cat "$SANDBOX/.codex/agents/reviewer.toml")" 'developer_instructions = '
}

test_link_keeps_ported_agents_current() {
  owned_agent reviewer "Reviews changes."
  owned_agent gone
  dot setup --harness codex,copilot --yes
  owned_agent reviewer "Reviews every change."
  owned_agent tester "Writes tests."
  rm -- "$DOTDOT/Agents/gone.md"
  dot link -y
  assert_success
  assert_contains "$(cat "$SANDBOX/.codex/agents/reviewer.toml")" 'Reviews every change.'
  assert_file "$SANDBOX/.codex/agents/tester.toml"
  assert_file "$SANDBOX/.github/agents/tester.agent.md"
  assert_no_file "$SANDBOX/.codex/agents/gone.toml"
  assert_no_file "$SANDBOX/.github/agents/gone.agent.md"
}

test_own_takes_in_copilot_agents_in_dotdots_format() {
  mkdir -p "$SANDBOX/.github/agents"
  printf -- '---\nname: helper\ndescription: Helps.\n---\n\nHelp.\n' > "$SANDBOX/.github/agents/helper.agent.md"
  dot setup --harness copilot --strategy own --yes
  assert_success
  assert_file "$DOTDOT/Agents/helper.md"
  assert_equal "$(cat "$SANDBOX/.github/agents/helper.agent.md")" "$(cat "$DOTDOT/Agents/helper.md")"
}

# Edge

test_own_takes_codex_agents_into_dotdots_format() {
  mkdir -p "$SANDBOX/.codex/agents"
  printf 'name = "mine"\ndescription = "Mine: \\"quoted\\"."\ndeveloper_instructions = """\nYou help.\nAlways."""\n' > "$SANDBOX/.codex/agents/mine.toml"
  dot setup --harness codex --strategy own --yes
  assert_success
  assert_equal "$(core "dot::use framework.helpers.frontmatter; framework.helpers.frontmatter::body '$DOTDOT/Agents/mine.md'"; printf '%s' "$OUTPUT")" "$(printf 'You help.\nAlways.')"
  assert_contains "$(cat "$SANDBOX/.codex/agents/mine.toml")" 'developer_instructions = "You help.\nAlways."'
  assert_link_to "$SANDBOX/.codex/agents/mine.toml" "$DOTDOT/.harnesses/codex/agents/mine.toml"
}

test_own_leaves_a_codex_file_that_isnt_an_agent() {
  mkdir -p "$SANDBOX/.codex/agents"
  printf 'name = "half"\n' > "$SANDBOX/.codex/agents/half.toml"
  dot setup --harness codex --strategy own --yes
  assert_success
  [ -f "$SANDBOX/.codex/agents/half.toml" ] && [ ! -L "$SANDBOX/.codex/agents/half.toml" ] || fail "an unreadable agent was moved"
  assert_no_file "$DOTDOT/Agents/half.md"
}
test_an_agent_without_a_description_still_ports() {
  mkdir -p "$DOTDOT/Agents"
  printf 'You help.\n' > "$DOTDOT/Agents/plain.md"
  dot setup --harness codex --yes
  assert_success
  assert_contains "$(cat "$SANDBOX/.codex/agents/plain.toml")" 'name = "plain"'
  assert_contains "$(cat "$SANDBOX/.codex/agents/plain.toml")" 'You help.'
}

test_a_quoted_description_loses_its_yaml_quotes() {
  owned_agent quoted '"Reviews: changes."'
  dot setup --harness codex --yes
  assert_contains "$(cat "$SANDBOX/.codex/agents/quoted.toml")" 'description = "Reviews: changes."'
}

# Adversarial

test_agent_text_cannot_break_out_of_its_toml_strings() {
  owned_agent sly 'A "quote" \ and [table]' "\"\"\"
[evil]
x = 1"
  dot setup --harness codex --yes
  assert_success
  assert_contains "$(cat "$SANDBOX/.codex/agents/sly.toml")" 'description = "A \"quote\" \\ and [table]"'
  assert_not_contains "$(grep -n '^\[evil\]' "$SANDBOX/.codex/agents/sly.toml")" "[evil]"
}

test_an_agent_named_with_a_path_is_ported_under_its_file_name() {
  owned_agent safe
  printf -- '---\nname: ../../escape\ndescription: x\n---\n\nx\n' > "$DOTDOT/Agents/safe.md"
  dot setup --harness codex --yes
  assert_success
  assert_file "$SANDBOX/.codex/agents/safe.toml"
  assert_no_file "$SANDBOX/escape.toml"
  assert_no_file "$DOTDOT/escape.toml"
}
