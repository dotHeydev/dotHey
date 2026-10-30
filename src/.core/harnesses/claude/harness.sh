# shellcheck shell=bash

# The harness interface, each function taking the harness id first: its data
# in harness.json drives the shared handler; what the data can't express goes
# in this folder's own scripts, called from here.

hey::use core.harnesses.harness

core.harnesses.claude.harness::detect() { core.harnesses.harness::detect "$@"; }
core.harnesses.claude.harness::scan() { core.harnesses.harness::scan "$@"; }
core.harnesses.claude.harness::rows() { core.harnesses.harness::rows "$@"; }
core.harnesses.claude.harness::destinations() { core.harnesses.harness::destinations "$@"; }
