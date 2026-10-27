#!/usr/bin/env bash

DESCRIPTION="Check that every link between decisions resolves."

dot::use framework.console.args core.modules.decisions.service framework.console.output framework.helpers.text

usage() {
  cat <<EOF
Checks every reference in every decision, the "superseded by" link included,
and exits non-zero when any is broken, so it can gate a commit.

Usage:
  bash dot decisions:check

Options:
  -h, --help   Show this help.
EOF
}

handle() {
  local kind self target section checked=0 broken=0
  [ $# -eq 0 ] || framework.console.args::unexpected "$1"
  framework.console.output::line "Checking the links between decisions…"
  while IFS=$'\t' read -r kind self target section; do
    case "$kind" in
      checked) checked=$((checked + 1)) ;;
      missing) framework.console.output::detail "$OUTPUT_ERROR_ICON $self → $target ($section): no such decision"; broken=$((broken + 1)) ;;
      self) framework.console.output::detail "$OUTPUT_ERROR_ICON $self ($section) points at itself"; broken=$((broken + 1)) ;;
    esac
  done < <(core.modules.decisions.service::broken_links)
  if [ "$broken" -eq 0 ]; then
    framework.console.output::success "All $(framework.helpers.text::plural "$checked" link) resolve."
  else
    framework.console.output::fail "$broken of $(framework.helpers.text::plural "$checked" link) are broken."
  fi
}
