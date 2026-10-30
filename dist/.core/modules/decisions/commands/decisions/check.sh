# shellcheck shell=bash

DESCRIPTION="Check that every link between decisions resolves."
DOCS="work/records#decisions"
JSON=true

hey::use framework.console.args core.modules.decisions.service framework.console.output framework.helpers.text framework.helpers.json

usage() {
  cat <<EOF
Checks every reference in every decision, the "superseded by" link included,
and exits non-zero when any is broken, so it can gate a commit.

Usage:
  bash hey decisions:check [--json]

Options:
  --json       {"checked": <n>, "broken": [{"decision", "target", "section", "problem"}]}.
  -h, --help   Show this help.
EOF
}

handle() {
  local kind self target section checked=0 broken=0 rows=""
  [ $# -eq 0 ] || framework.console.args::unexpected "$1"
  $HEY_JSON || framework.console.output::line "Checking the links between decisions…"
  while IFS=$'\t' read -r kind self target section; do
    case "$kind" in
      checked) checked=$((checked + 1)); continue ;;
      missing) $HEY_JSON || framework.console.output::detail "$(framework.console.output::paint "$UI_STYLE_ERROR" "$UI_ICON_ERROR") $self $UI_ARROW $target ($section): no such decision" ;;
      self) $HEY_JSON || framework.console.output::detail "$(framework.console.output::paint "$UI_STYLE_ERROR" "$UI_ICON_ERROR") $self ($section) points at itself" ;;
      *) continue ;;
    esac
    broken=$((broken + 1))
    rows="$rows${rows:+,}{\"decision\":$(framework.helpers.json::string "$self"),\"target\":$(framework.helpers.json::string "$target"),\"section\":$(framework.helpers.json::string "$section"),\"problem\":\"$kind\"}"
  done < <(core.modules.decisions.service::broken_links)
  if $HEY_JSON; then
    printf '{"checked":%s,"broken":[%s]}\n' "$checked" "$rows"
    [ "$broken" -eq 0 ] || exit "$EXIT_FAILURE"
  elif [ "$broken" -eq 0 ]; then
    framework.console.output::success "All $(framework.helpers.text::plural "$checked" link) resolve."
  else
    framework.console.output::fail "$broken of $(framework.helpers.text::plural "$checked" link) are broken."
  fi
}
