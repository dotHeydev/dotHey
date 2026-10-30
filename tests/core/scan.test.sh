# shellcheck shell=bash

test_scan_frontmatter_stays_inside_dotdot() {
  dot notes:create scanned
  dot scan:frontmatter Notes
  assert_success
  assert_contains "$OUTPUT" "n001--scanned.md"
  dot scan:frontmatter ../..
  assert_failure
  assert_equal "$STATUS" 1
  ln -s / "$DOTDOT/escape"
  dot scan:frontmatter escape
  assert_failure
  assert_equal "$STATUS" 1
}

test_frontmatter_show_prints_json() {
  dot xrays:create "Shown" --description "A \"quoted\" one."
  dot notes:create bare
  dot frontmatter:show Xrays --json
  assert_success
  assert_equal "$(json_value "$OUTPUT" '.[0].frontmatter.name')" shown
  assert_equal "$(json_value "$OUTPUT" '.[0].frontmatter.description')" 'A "quoted" one.'
  dot frontmatter:show Notes --json
  assert_equal "$(json_value "$OUTPUT" '.[0].frontmatter')" ""
  dot frontmatter:show Nowhere
  assert_equal "$STATUS" 4
}
