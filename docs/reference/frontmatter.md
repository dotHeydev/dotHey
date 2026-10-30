---
title: bash hey frontmatter:*
description: Every frontmatter command, with its usage, options, and examples.
order: 6
---

# bash hey frontmatter:*

## `frontmatter:show`

Print just the frontmatter of dotHey's docs.

```text
Prints each Markdown file's frontmatter, without its body, so a directory of
docs can be surveyed cheaply before reading any of them in full.

Usage:
  bash hey frontmatter:show <path>

Arguments:
  <path>       A directory (every *.md directly in it) or one Markdown file,
               inside .hey/; relative to .hey/ wherever you run it.

Options:
  --json       Optional. [{"file", "frontmatter": {<key>: <value>} or null}],
               one per file.
  -h, --help   Show this help.

Examples:
  bash hey frontmatter:show Features
  bash hey frontmatter:show Decisions/d002--no-soft-deletes.md

Notes:
  - A file without frontmatter shows as (no frontmatter).
```
