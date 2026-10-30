# shellcheck shell=bash

# The harness interface, each function taking the harness id first: its data
# in harness.json drives the shared handler; what the data can't express goes
# in this folder's own scripts, called from here.

dot::use core.harnesses.harness core.harnesses.codex.agents-toml

core.harnesses.codex.harness::detect() { core.harnesses.harness::detect "$@"; }
core.harnesses.codex.harness::scan() { core.harnesses.harness::scan "$@"; }
core.harnesses.codex.harness::rows() { core.harnesses.harness::rows "$@"; }
core.harnesses.codex.harness::destinations() { core.harnesses.harness::destinations "$@"; }
core.harnesses.codex.harness::agents_render() { core.harnesses.codex.agents-toml::render "$2" "$3"; }
core.harnesses.codex.harness::agents_import() { core.harnesses.codex.agents-toml::import "$2" "$3"; }
