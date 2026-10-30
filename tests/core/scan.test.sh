# shellcheck shell=bash

test_scan_frontmatter_stays_inside_dothey() {
  hey notes:create scanned
  hey scan:frontmatter Notes
  assert_success
  assert_contains "$OUTPUT" "n001--scanned.md"
  hey scan:frontmatter ../..
  assert_failure
  assert_equal "$STATUS" 1
  ln -s / "$DOTHEY/escape"
  hey scan:frontmatter escape
  assert_failure
  assert_equal "$STATUS" 1
}

test_frontmatter_show_prints_json() {
  hey xrays:create "Shown" --description "A \"quoted\" one."
  hey notes:create bare
  hey frontmatter:show Xrays --json
  assert_success
  assert_equal "$(json_value "$OUTPUT" '.[0].frontmatter.name')" shown
  assert_equal "$(json_value "$OUTPUT" '.[0].frontmatter.description')" 'A "quoted" one.'
  hey frontmatter:show Notes --json
  assert_equal "$(json_value "$OUTPUT" '.[0].frontmatter')" ""
  hey frontmatter:show Nowhere
  assert_equal "$STATUS" 4
}
