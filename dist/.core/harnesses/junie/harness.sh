#!/usr/bin/env bash

# The harness interface, each function taking the harness id first: its data
# in harness.json drives the shared handler; what the data can't express goes
# in this folder's own scripts, called from here.

dot::use core.harnesses.harness

core.harnesses.junie.harness::detect() { core.harnesses.harness::detect "$@"; }
core.harnesses.junie.harness::scan() { core.harnesses.harness::scan "$@"; }
core.harnesses.junie.harness::rows() { core.harnesses.harness::rows "$@"; }
core.harnesses.junie.harness::destinations() { core.harnesses.harness::destinations "$@"; }
