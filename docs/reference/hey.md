---
title: bash hey <command>
description: Every core command, with its usage, options, and examples.
order: 1
---

# bash hey <command>

## `adopt`

Scan the project for harnesses and what they already hold.

```text
Lists each harness dotHey supports, the ones the project uses, and what their
places already hold (instructions, skills, agents, rules), with dotHey's
setup. Other top-level Markdown docs are listed as unsure: context the
project may want dotHey to take in. It reads paths and sizes only, never
.env, .git/, or anything a link leads outside the project, and changes
nothing.

Usage:
  bash hey adopt --scan [--json]

Options:
  --scan       Optional. Scan the project.
  --json       Optional. Print {"harnesses", "detected", "items", "setup",
               "invalid"}.
  -h, --help   Show this help.

Examples:
  bash hey adopt --scan
  bash hey adopt --scan --json
```

## `link`

Link dotHey and its plugins where your agents read them.

```text
Seeds .hey/USER.md, then links and appends what the "links" in
.hey/hey.json list. It previews every change and asks before applying any;
with no one at a terminal to ask, it only previews.

Usage:
  bash hey link [--overwrite] [--preview] [-v, --verbose] [-y, --yes] [--json]

Options:
  --overwrite          Optional. Replace destinations that already exist: a
                       symlink is replaced, a file is backed up as
                       <name>.bak-<time> first. A real directory is always
                       skipped. Also --force.
  --preview            Optional. Show the changes, and stop. Also --dry-run.
  -v, --verbose        Optional. List the entries that stay as they are, too.
  -y, --yes            Optional. Apply without asking. Only at a terminal, or
                       when dotHey itself runs it.
  --json               Optional. Print the changes as {"changes": [{"action",
                       "origin", "destination"}], "taken"}, and stop; with -y,
                       apply them and print {"linked", "removed", "appended",
                       "takenBack", "skipped", "failed"}.
  -h, --help           Show this help.

Examples:
  bash hey link
  bash hey link --preview
  bash hey link --overwrite -v

Links:
  "<origin>": ["<destination>", ...]   symlink each destination to the origin
  "append": {"<origin>": [...]}        append the file to each destination,
                                       between markers naming its owner
  "skip": {"<origin>": [...]}          never link or append these; what dotHey
                                       linked or appended there is taken back
  "<owner>/<name>": {...}              a plugin's active links, same shape
  "inactive": {"<owner>/<name>": ...}  a plugin's links, never applied until
                                       they are activated

  Origins: @hey:<path>, @module:<name>:<path>, @plugin:<owner>.<name>:<path>,
  @dotheySkills, @dotheyAgents, @pluginsSkills, @pluginsAgents; a /* ending
  links each entry inside. Destinations are project paths outside .hey/
  and .git/, never .env; appends may also go to @hey:<Doc>.md. When two entries
  claim one destination, your own links win, then the first declared.

Notes:
  - Link a plugin's own links with bash hey plugins:link.
  - Run it after installing dotHey, creating a git worktree, or adding,
    renaming or removing anything the links cover. Re-running is safe.
  - Links are relative, so they survive a clone, a move or a rebuild.
  - bash hey link -v lists every current link.
```

## `migrate`

Upgrade dotHey's own files to this version's format.

```text
Runs the migrations still pending, in order: each converts a file dotHey keeps
in .hey/ from an older format. While one is pending, every command but
upgrade asks for this one first.

Usage:
  bash hey migrate [-y, --yes]

Options:
  -y, --yes      Optional. Run without asking. Only at a terminal, or when
                 dotHey itself runs it.
  -h, --help     Show this help.

Notes:
  - state.migrations in .hey/hey.json lists the migrations applied.
```

## `relocate`

Move dotHey to another place in the project.

```text
Moves all of dotHey, as it is, to <dir> in the project (.agents/.hey, so it
sits in the project's .agents/ folder), points the hey entry at it, rewrites
the paths in dotHey's files, and relinks everything it linked. It previews
the move and asks first; with no one at a terminal to ask, it only previews.

Usage:
  bash hey relocate <dir> [--preview] [-y, --yes]

Arguments:
  <dir>        Where dotHey goes, from the project root; it must not exist,
               or be an empty directory.

Options:
  --preview    Optional. Show the move, and stop. Also --dry-run.
  -y, --yes    Optional. Move without asking. Only at a terminal, or when dotHey
               itself runs it.
  -h, --help   Show this help.

Examples:
  bash hey relocate .agents/.hey
  bash hey relocate .hey
```

## `upgrade`

Update dotHey's core to its latest version.

```text
Updates dotHey's core (.hey/.core/) from
https://github.com/dotHeydev/dotHey.git (main) in one step, showing both
versions. Plugins and your context files are never touched. When the links
need refreshing, it offers to (at a terminal), or says to run bash hey link.

Usage:
  bash hey upgrade [--link [<link options>...]]

Options:
  --link       Optional. Refresh the links right after, without asking: runs
               bash hey link with the options that follow, e.g. --link -y
               --overwrite. Options without --link are ignored, with a warning.
  -h, --help   Show this help.

Examples:
  bash hey upgrade
  bash hey upgrade --link -y

Notes:
  - A file is deleted only when the installed version had it and the latest
    doesn't; one you edited is kept and listed.
  - Without a known installed version (state.commit in .hey/hey.json), nothing
    is deleted: the files the latest no longer has are listed instead.
  - Plugins update with bash hey plugins:update.
```
