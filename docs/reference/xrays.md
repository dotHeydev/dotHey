---
title: bash hey xrays:*
description: Every xrays command, with its usage, options, and examples.
order: 11
---

# bash hey xrays:*

## `xrays:create`

Open a new xray to discuss a topic in a file.

```text
Creates the next numbered xray in Xrays/ from the xray template,
ready for its topics and questions.

Usage:
  bash hey xrays:create <title> --description <text>

Arguments:
  <title>                The xray's title; becomes its file name.

Options:
  --description <text>   Required. One sentence: what it settles, and why it
                         matters.
  --json                 Optional. Print {"id", "path"}.
  -h, --help             Show this help.

Examples:
  bash hey xrays:create "Existing project adoption" \
    --description "How dotHey moves into a project with its own harness setup."

Notes:
  - At a terminal, a missing title or --description is asked for.
```
