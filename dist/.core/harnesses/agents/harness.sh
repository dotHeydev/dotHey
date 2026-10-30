# shellcheck shell=bash

# The harness interface, each function taking the harness id first: its data
# in harness.json drives the shared handler; what the data can't express goes
# in this folder's own scripts, called from here.

dot::use core.harnesses.harness

core.harnesses.agents.harness::detect() { core.harnesses.harness::detect "$@"; }
core.harnesses.agents.harness::scan() { core.harnesses.harness::scan "$@"; }
core.harnesses.agents.harness::rows() { core.harnesses.harness::rows "$@"; }
core.harnesses.agents.harness::destinations() { core.harnesses.harness::destinations "$@"; }
