---
title: bash hey alias:*
description: Every alias command, with its usage, options, and examples.
order: 3
---

# bash hey alias:*

## `alias:add`

Add the hey alias to your shell, to type hey instead of bash hey.

```text
Adds one line to the rc file of each shell you pick, so hey runs ./hey (or
dotHey's own entry when that link is missing) and you no longer type bash
first. It shows every file and line, and asks before writing; run it again
after moving dotHey to update the lines.

Usage:
  bash hey alias:add [--shell <a,b>] [-y, --yes]

Options:
  --shell <a,b>   Optional. The shells to add it to: bash zsh fish ksh tcsh.
                  Without it, a terminal asks, yours ($SHELL) checked; with -y,
                  yours.
  -y, --yes       Optional. Add it without asking. Only at a terminal, or when
                  dotHey itself runs it.
  -h, --help      Show this help.

Examples:
  bash hey alias:add
  bash hey alias:add --shell zsh,bash --yes

Notes:
  - mksh counts as ksh (~/.mkshrc), and csh as tcsh (~/.cshrc).
  - It works in new terminals, or in this one after: source <file>.
  - bash hey alias:remove takes it back.
```

## `alias:remove`

Take the hey alias back out of your shell.

```text
Removes the line bash hey alias:add put in your shells' rc files, from every
one that has it, and nothing else of them, after asking.

Usage:
  bash hey alias:remove [-y, --yes]

Options:
  -y, --yes    Optional. Remove it without asking. Only at a terminal, or when
               dotHey itself runs it.
  -h, --help   Show this help.

Examples:
  bash hey alias:remove
```
