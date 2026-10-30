---
title: bash hey notes:*
description: Every notes command, with its usage, options, and examples.
order: 7
---

# bash hey notes:*

## `notes:create`

Create a new, numbered note.

```text
Creates the next numbered, empty note in Notes/; write the note into it
afterwards.

Usage:
  bash hey notes:create [<name>]

Arguments:
  <name>       A short name for the file ("Cache idea" becomes cache-idea).
               Without one, it gets a random one, like swift-otter.

Options:
  --json       Optional. Print {"id", "path"}.
  -h, --help   Show this help.

Examples:
  bash hey notes:create "Cache idea"
  bash hey notes:create
```
