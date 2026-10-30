# shellcheck shell=bash

DOCS_DIR="$REPOSITORY_DIR/docs"

# Every "<file><TAB><target>" relative link outside code, in <files>.
docs_links() {
  awk '
    FNR == 1 { fence = 0 }
    /^```/ { fence = !fence; next }
    fence { next }
    {
      line = $0
      gsub(/`[^`]*`/, "", line)
      while (match(line, /\]\([^) ]+\)/)) {
        target = substr(line, RSTART + 2, RLENGTH - 3)
        line = substr(line, RSTART + RLENGTH)
        if (target !~ /^[a-z]+:/) print FILENAME "\t" target
      }
    }
  ' "$@"
}

# The anchors of <file>'s headings, as GitHub makes them.
docs_anchors() {
  awk '/^```/ { fence = !fence; next } !fence && /^#+ / { sub(/^#+ /, ""); print }' "$1" \
    | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 _-]//g; s/ /-/g'
}

docs_pages() {
  (cd "$DOCS_DIR" && find . -name '*.md' ! -name index.md | sed 's|^\./||' | sort)
}

test_every_docs_link_and_anchor_resolves() {
  local file target path anchor files=("$REPOSITORY_DIR/README.md")
  while IFS= read -r file; do files+=("$file"); done < <(find "$DOCS_DIR" -name '*.md')
  while IFS=$'\t' read -r file target; do
    path="${target%%#*}"
    anchor=""
    [ "$path" = "$target" ] || anchor="${target#*#}"
    [ -n "$path" ] && path="$(dirname -- "$file")/$path" || path="$file"
    [ -e "$path" ] || { fail "${file#"$REPOSITORY_DIR"/} links to $target, which doesn't exist"; continue; }
    [ -z "$anchor" ] || [ "${path##*.}" != md ] || docs_anchors "$path" | grep -qxF -- "$anchor" \
      || fail "${file#"$REPOSITORY_DIR"/} links to $target, which has no such heading"
  done < <(docs_links "${files[@]}")
}

test_the_docs_nav_lists_every_page_once() {
  local listed
  listed=$(awk -F'"dir": "' 'NF > 1 { split($2, a, "\""); dir = a[1]; sub(/.*"pages": \[/, ""); sub(/\].*/, ""); gsub(/[" ]/, ""); n = split($0, p, ","); for (i = 1; i <= n; i++) if (p[i] != "") print dir "/" p[i] ".md" }' "$DOCS_DIR/nav.json" | sort)
  assert_equal "$listed" "$(docs_pages)"
}

test_every_docs_page_has_frontmatter_matching_its_title() {
  local page title
  while IFS= read -r page; do
    title=$(sed -n '2,/^---$/s/^title: //p' "$DOCS_DIR/$page")
    [ -n "$title" ] || { fail "$page has no title in its frontmatter"; continue; }
    grep -qxF "# $title" "$DOCS_DIR/$page" || fail "$page's heading isn't its title, $title"
  done < <(docs_pages)
}
