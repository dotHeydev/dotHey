# shellcheck shell=bash

# The harness interface, each function taking the harness id first: its data
# in harness.json drives the shared handler; what the data can't express goes
# in this folder's own scripts, called from here.

dot::use core.harnesses.harness

core.harnesses.opencode.harness::detect() { core.harnesses.harness::detect "$@"; }
core.harnesses.opencode.harness::scan() { core.harnesses.harness::scan "$@"; }
core.harnesses.opencode.harness::rows() { core.harnesses.harness::rows "$@"; }
core.harnesses.opencode.harness::destinations() { core.harnesses.harness::destinations "$@"; }
