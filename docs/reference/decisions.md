---
title: bash hey decisions:*
description: Every decisions command, with its usage, options, and examples.
order: 4
---

# bash hey decisions:*

## `decisions:check`

Check that every link between decisions resolves.

```text
Checks every reference in every decision, the "superseded by" link included,
and exits non-zero when any is broken, so it can gate a commit.

Usage:
  bash hey decisions:check [--json]

Options:
  --json       Optional. {"checked": <n>, "broken": [{"decision", "target",
               "section", "problem"}]}.
  -h, --help   Show this help.
```

## `decisions:citers`

List the decisions that point at a decision.

```text
Lists the decisions that cite a decision or name it in "superseded by", with
why each points at it, so you know what relies on it before it changes.

Usage:
  bash hey decisions:citers <decision>[,...]

Arguments:
  <decision>   Decisions, as 2, 002, or their file name; comma-separated or
               one per argument.

Options:
  -h, --help   Show this help.

Examples:
  bash hey decisions:citers 004
  bash hey decisions:citers 002,005

Notes:
  - bash hey decisions:impact lists the features citing a decision instead.
```

## `decisions:create`

Document a new decision from the template.

```text
Creates the next numbered decision in Decisions/ from the decision template;
one flag per template section.

Usage:
  bash hey decisions:create <name> --statement <text> --explanation <text>
                            [options]

Arguments:
  <name>                       Short name for the file (e.g. "JWT in httpOnly
                               cookie"); not the rule itself.

Options:
  --statement <text>           Required. The decision as a first-person rule,
                               able to stand alone; becomes the title and the
                               description.
  --explanation <text>         Required. One plain paragraph: what must happen,
                               to whom, and with what side effects.
  -s, --status <status>        Optional. draft proposed accepted rejected
                               deprecated (default: draft).
  --superseded-by <replacement>
                               Optional. Record it as already replaced by
                               <replacement>.
  --influenced-by <ref>         Optional. Influenced By: a decision per use.
  --impacts <ref>               Optional. Impacts: a feature per use.
  --json                       Optional. Print {"id", "path"}.
  -h, --help                   Show this help.

Examples:
  bash hey decisions:create "JWT in httpOnly cookie" \
    --statement "We keep the session JWT in an httpOnly cookie." \
    --explanation "Every authenticated response sets it as one." \
    --status accepted --influenced-by 002 --impacts 7

Notes:
  - At a terminal, a missing name, --statement or --explanation is asked for.
  - To change its status afterwards, use bash hey decisions:update; to change
    its prose, edit the file and bump "modified".
  - The section flags and statuses come from the decision template.
  - A <ref> is a number (2, 002) or a file name; it's checked to exist, and
    its link is built for you.
```

## `decisions:impact`

Find what a decision touches.

```text
Finds the features that cite decisions and the docs that mention its terms,
so you know what a new decision collides with.

Usage:
  bash hey decisions:impact <decision>[,...] [--term <text>[,...]]... [options]
  bash hey decisions:impact --term <text>[,...]... [options]

Arguments:
  <decision>       Decisions, as 2, 002, or their file name; comma-separated or
                   one per argument. Lists the features citing them under
                   "Related Project Decisions".

Options:
  --term <text>    Optional. Terms to look for in features and decisions,
                   comma-separated; repeatable. Case-insensitive, and "auth"
                   also finds "OAuth".
  --scope <what>   Optional. all, features or decisions (default: all), for
                   --term.
  --lines <n>      Optional. Matching lines shown per file (default: 3; 0 for
                   none).
  --json           Optional. {"features": [{"path", "cites", "description"}] or
                   null, "terms": [{"path", "matched", "lines", "hits",
                   "description", "matches"}] or null}.
  -h, --help       Show this help.

Examples:
  bash hey decisions:impact 002,005
  bash hey decisions:impact --term session,jwt,cookie --scope features

Notes:
  - Files are ranked by how many terms they match; prefer several precise terms.
  - No output means nothing documented is touched: a real answer.
  - bash hey decisions:citers lists the decisions that point at one.
  - bash hey decisions:check checks the links between decisions.
```

## `decisions:update`

Change a decision's status.

```text
Sets a decision's status and refreshes its "modified" date, in one step.

Usage:
  bash hey decisions:update <decision> --status <status>
  bash hey decisions:update <decision> --status superseded --by <replacement>

Arguments:
  <decision>        The decision, as 2, 002, or its file name.

Options:
  -s, --status <status>
                    Required. draft proposed accepted rejected deprecated, or
                    superseded.
  --by <replacement>
                    Optional. With superseded: the decision that replaces it
                    (checked to exist; the link is built for you).
  -h, --help        Show this help.

Examples:
  bash hey decisions:update 002 --status accepted
  bash hey decisions:update 002 --status superseded --by 007

Notes:
  - Only the status and the date change. To change the prose, edit the file
    and bump "modified".
```
