---
title: Linking
description: How bash hey link puts dotHey where your harnesses read it, and the links that drive it.
order: 3
---

# Linking

`bash hey link` puts dotHey where your harness reads it: it symlinks files and appends sections, following the `"links"` in `.hey/hey.json`. It previews every change and asks before applying any; run it again whenever skills, agents, or docs are added, renamed, or removed.

```sh
bash hey link                       # preview, then apply
bash hey link -v                    # also list what stays as it is
bash hey link --overwrite    # replace taken destinations; files are backed up first
```

## The links

```json
{
  "@hey:AGENTS.md": ["AGENTS.md", ".claude/CLAUDE.md"],
  "@dotheySkills": [".claude/skills/"],
  "append": { "@hey:STANDARDS.md": ["docs/STANDARDS.md"] },
  "skip": { "@hey:RULES.md": ["old/rules.md"] },
  "acme/tools": {
    "@plugin:acme.tools:skills/*": [".agents/skills/"],
    "append": { "@plugin:acme.tools:context/STANDARDS.md": ["@hey:STANDARDS.md"] },
    "skip": {}
  },
  "inactive": {
    "acme/lint": { "@plugin:acme.lint:skills/*": [".agents/skills/"], "append": {} }
  }
}
```

| Entry | Meaning |
|---|---|
| `"<origin>": [destinations]` | Symlink each destination to the origin |
| `"append"` | Append the origin's file to each destination, between markers naming its owner |
| `"skip"` | Yours alone: never link or append these, a plugin's and a harness's included; a destination still pointing at the origin is unlinked, and what was appended there taken back. It wins over the rest, and setup never writes or clears it |
| `"<owner>/<name>"` | A plugin's active links, in the same shape |
| `"inactive"` | A plugin's suggested links, never applied until `bash hey plugins:link` takes them |

**Origins:**

- `@hey:<path>`: anything in `.hey/`
- `@module:<name>:<path>`
- `@plugin:<owner>.<name>:<path>`
- `@dotheySkills`, `@dotheyAgents`: each of dotHey's skills or agents
- `@pluginsSkills`, `@pluginsAgents`: every plugin's

A `/*` ending takes each entry inside one by one.

**Destinations** are project paths outside `.hey/` and `.git/`, never `.env`; appends may also go to `@hey:<Doc>.md`.

**Appends** go between `<!-- <owner>/<name> -->` markers (`#` outside Markdown). Into Markdown, they sit under a rule and a `## <owner>/<name>` heading, with the origin's description quoted. Each owner keeps its own section of a file, so appends never collide. A `.json` takes no markers, so it is only created when missing.

**Removing an entry** unlinks what it linked, and takes its appended section out, at the next `bash hey link`: link compares the disk with the links each run, in the folders it knows of (the links' own, every harness's, and the project's root). A link into `.hey/` there that no entry wants goes too, even one you made by hand; a link elsewhere, or your own file, is never touched. An entry whose folder nothing else names isn't found once deleted: skip it instead, or delete its link.

**When two entries claim one destination**, your own links win over a plugin's, then the first declared; the one left out is reported.

Paths read the same everywhere dotHey takes one: `<path>` is that path, `<path>/` that directory, `<path>/*` everything inside it, and, in the deny lists only, `<start>*` anything starting with `<start>`.

> [!NOTE]
> dotHey edits only the entries it changes and leaves the rest of `hey.json` as you wrote it. A file that doesn't parse is refused, never overwritten. JSON keeps only the last of two identical keys, so `link` offers to merge them.
