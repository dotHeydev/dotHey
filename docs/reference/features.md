---
title: bash hey features:*
description: Every features command, with its usage, options, and examples.
order: 5
---

# bash hey features:*

## `features:create`

Document a new feature from the template.

```text
Creates the next numbered feature in Features/ from the feature template;
one flag per template section, and sections left out read "None". To change
it afterwards, edit its file.

Usage:
  bash hey features:create <title> --description <text> [--<section> <text>]...

Arguments:
  <title>                        The feature's title; becomes its file name.

Options:
  --description <text>           Required. A one-line summary.
  --specification <text>          Optional. Specification
  --constraining-rules <text>     Optional. Constraining Rules
  --related-project-decisions <text> Related Project Decisions
  --feature-specific-decisions <text> Feature-Specific Decisions
  --data-model <text>             Optional. Data Model
  --file-map <text>               Optional. File Map
  --technicalities <text>         Optional. Technicalities
  --related-features <text>       Optional. Related Features
  --implementation-plan <text>    Optional. Implementation Plan
  --json                         Optional. Print {"id", "path"}.
  -h, --help                     Show this help.

Examples:
  bash hey features:create "Password reset" \
    --description "Lets a user reset a forgotten password by email." \
    --specification "Given a registered user… When… Then…" \
    --related-features 7

Notes:
  - The section flags come from the feature template.
  - At a terminal, a missing title or --description is asked for.
```
