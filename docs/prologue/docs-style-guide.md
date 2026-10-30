---
title: Docs style guide
description: How dotHey's documentation is written and organized.
order: 5
---

# Docs style guide

The [Google developer documentation style guide](https://developers.google.com/style) is the base. On top of it:

## Voice

- Friendly and casual, yet professional. Talk to the reader as "you".
- Present tense, active voice, everyday words. No jargon where a plain word does, no filler.
- One idea per paragraph, and short paragraphs.

## Pages

- One topic per page, in `docs/<section>/<page>.md`, listed in order in `docs/nav.json`.
- Every page starts with frontmatter (`title`, `description`, `order`), then one `# Title` that matches `title`.
- Task pages lead with the goal, then the steps, then the result.
- Link with relative paths only (`../configuration/linking.md#the-links`), so the docs read the same on GitHub and on a generated site.
- Describe what readers can rely on; leave out dotHey's internals unless the page is about extending it.

## Examples

- Every command and code example runs as written.
- Comments in examples say what a line does, aligned when they sit in a column.
- Use `acme` for a plugin owner and `widgets` for a plugin name.
