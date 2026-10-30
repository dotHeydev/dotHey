---
title: bash hey tasks:*
description: Every tasks command, with its usage, options, and examples.
order: 10
---

# bash hey tasks:*

## `tasks:create`

Create a task.

```text
Creates a task in the project's task service, its body built from the task
template. At a terminal, a missing title is asked for, and your editor opens
when no content is given.

Usage:
  bash hey tasks:create [<title>] [options]

Arguments:
  <title>                  One line. Required without a terminal.

Options:
  -s, --status <status>    Optional. todo doing paused done discarded (default:
                           todo).
  --body <markdown>        Optional. The whole body.
  --body-file <path>|-     Optional. The whole body, from a project file or
                           stdin.
  --description <text>     Optional. Description.
  --done-when <text>       Optional. Done When.
  --related-features <text>
                           Optional. Related Features.
  --related-decisions <text>
                           Optional. Related Decisions.
  --related-notes <text>   Optional. Related Notes.
  --related-files <text>   Optional. Related Files.
  -e, --edit               Optional. Open your editor on what was given, too.
  --no-edit                Optional. Never open the editor.
  --json                   Optional. Print {"id", "title", "status"}.
  -h, --help               Show this help.

Examples:
  bash hey tasks:create "Throttle failed logins" \
    --description "Brute-force attempts aren't throttled." \
    --done-when "- [ ] 5 failed attempts lock the route for a minute"
  bash hey tasks:create "Rewrite the README" --status doing

Notes:
  - Sections left out read "None"; a section flag goes on top of --body.
```

## `tasks:delete`

Delete a task for good.

```text
Deletes a task for good, after asking at a terminal. Moving it to done or
discarded is the usual way to end one.

Usage:
  bash hey tasks:delete <id> [-y, --yes]

Arguments:
  <id>                     The task's id (t004, #12).

Options:
  -y, --yes                Optional. Delete without asking. It still needs a
                           terminal.
  -h, --help               Show this help.

Examples:
  bash hey tasks:delete t004
```

## `tasks:discarded`

Move a task to discarded.

```text
Moves a task to discarded.

Usage:
  bash hey tasks:discarded <id>

Arguments:
  <id>         The task's id (t004, #12).

Options:
  -h, --help   Show this help.

Examples:
  bash hey tasks:discarded t004

Notes:
  - The same as bash hey tasks:update <id> --status discarded.
```

## `tasks:doing`

Move a task to doing.

```text
Moves a task to doing.

Usage:
  bash hey tasks:doing <id>

Arguments:
  <id>         The task's id (t004, #12).

Options:
  -h, --help   Show this help.

Examples:
  bash hey tasks:doing t004

Notes:
  - The same as bash hey tasks:update <id> --status doing.
```

## `tasks:done`

Move a task to done.

```text
Moves a task to done.

Usage:
  bash hey tasks:done <id>

Arguments:
  <id>         The task's id (t004, #12).

Options:
  -h, --help   Show this help.

Examples:
  bash hey tasks:done t004

Notes:
  - The same as bash hey tasks:update <id> --status done.
```

## `tasks:get`

Show a task.

```text
Shows a task as Markdown: its fields as frontmatter, then its body. At a
terminal it opens in less; anywhere else it's printed.

Usage:
  bash hey tasks:get <id> [--no-pager] [--json]

Arguments:
  <id>                     The task's id (t004, #12).

Options:
  --no-pager               Optional. Print it, even at a terminal.
  --json                   Optional. {"id", "title", "status", "created",
                           "updated", "body"}.
  -h, --help               Show this help.

Examples:
  bash hey tasks:get t004
```

## `tasks:initialize`

Choose where the project keeps its tasks.

```text
Sets up where this project keeps its tasks: the service given, or, at a
terminal, the one you choose. Running it again switches services; existing
tasks stay where they are.

Usage:
  bash hey tasks:initialize [--service <service>] [--repo <owner>/<name>]

Options:
  --service <service>      Optional. The service (below); asked for at a
                           terminal.
  --repo <owner>/<name>    Optional. With github: the repository for tasks;
                           asked for at a terminal (default there: this repo's
                           origin).
  -h, --help               Show this help.

Examples:
  bash hey tasks:initialize --service files
  bash hey tasks:initialize --service github --repo acme/app

Services:
  file         Plain Markdown files in .hey/Tasks/ (t001--slug.md).
  github       GitHub issues with the task label, through gh or HEY_GH_TOKEN.

Notes:
  - The first task command runs it for you.
  - The choice is saved as tasks.service in .hey/hey.json, shared by the
    project; set it to "@env:<KEY>" to let each person choose in .env.
```

## `tasks:list`

List the project's tasks.

```text
Lists the project's tasks, oldest first, 25 to a page.

Usage:
  bash hey tasks:list [options]

Options:
  -s, --status <status>    Optional. Only these, comma-separated: todo doing
                           paused done discarded.
  --sort <date>            Optional. created or updated (default: created).
  --order <order>          Optional. asc or desc (default: asc).
  -l, --limit <n>          Optional. Tasks per page (default: 25; 0 for all).
  -p, --page <n>           Optional. The page to show (default: 1).
  --plain                  Optional. One task per line, tab-separated: id,
                           status, created, updated, title; no header.
  --json                   Optional. {"tasks": [...], "total", "page", "pages",
                           "nextPage"}.
  -h, --help               Show this help.

Examples:
  bash hey tasks:list --status todo,doing,paused
  bash hey tasks:list --sort updated --order desc -l 5
  bash hey tasks:list --plain | cut -f1,5
```

## `tasks:paused`

Move a task to paused.

```text
Moves a task to paused.

Usage:
  bash hey tasks:paused <id>

Arguments:
  <id>         The task's id (t004, #12).

Options:
  -h, --help   Show this help.

Examples:
  bash hey tasks:paused t004

Notes:
  - The same as bash hey tasks:update <id> --status paused.
```

## `tasks:todo`

Move a task to todo.

```text
Moves a task to todo.

Usage:
  bash hey tasks:todo <id>

Arguments:
  <id>         The task's id (t004, #12).

Options:
  -h, --help   Show this help.

Examples:
  bash hey tasks:todo t004

Notes:
  - The same as bash hey tasks:update <id> --status todo.
```

## `tasks:update`

Change a task's title, content or status.

```text
Changes a task's title, content and status, in one step. At a terminal, with
nothing to change given, your editor opens on its current body.

Usage:
  bash hey tasks:update <id> [options]

Arguments:
  <id>                     The task's id (t004, #12).

Options:
  -t, --title <title>      Optional. Its new title.
  -s, --status <status>    Optional. todo doing paused done discarded.
  --body <markdown>        Optional. Replace the whole body.
  --body-file <path>|-     Optional. Replace the whole body, from a project file
                           or stdin.
  --description <text>     Optional. Description.
  --done-when <text>       Optional. Done When.
  --related-features <text>
                           Optional. Related Features.
  --related-decisions <text>
                           Optional. Related Decisions.
  --related-notes <text>   Optional. Related Notes.
  --related-files <text>   Optional. Related Files.
  -e, --edit               Optional. Open your editor on top of the changes,
                           too.
  --no-edit                Optional. Never open the editor.
  -h, --help               Show this help.

Examples:
  bash hey tasks:update t004 --status doing
  bash hey tasks:update t004 --done-when "- [x] lock after 5" --status done
  bash hey tasks:update '#12' --title "Throttle failed logins"

Notes:
  - A section flag replaces that section only; the rest stays as it is.
  - Statuses are todo, doing, paused, done, discarded; bash hey tasks:<status>
    <id> moves one, --status here alongside other changes.
  - Working on a task you were handed: move it to doing when you start, record
    progress and answers in its sections (ticking its Done When items), and
    move it to done once every item is checked.
```
