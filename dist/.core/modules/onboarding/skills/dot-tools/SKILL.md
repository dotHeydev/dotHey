---
name: dot-tools
description: Does every dotdot operation through the bash dot command instead of by hand — records (features, decisions, notes, xrays), tasks, links, setup and scans of the project, plugins, frontmatter surveys. Use it whenever a task touches .dot/, its records, its links, or dotdot's settings, before grepping, globbing, or editing those files yourself, and whenever you need to know which command does something or how one is used.
license: MIT
metadata:
  internal: true
  author: dotdot
---

# dotdot's tools

Every dotdot operation has a `bash dot` command, and each command's help is its manual. Run them as an AI agent (`--agent`, automatic under `AI_AGENT` or `CLAUDECODE`): plain output, never a prompt.

1. **Find the command:** `bash dot --json` lists every one with what it does.
2. **Learn it:** `bash dot help <command> --json` gives its usage, arguments, options, and notes. Follow them: they say what it needs, what it changes, and what to tell the user.
3. **Run it,** with `--json` wherever the help offers it.

Prefer a command over doing its work by hand: it knows the paths, the exclusions, the numbering, and the rules. When one needs a person at a terminal, it says so with the exact command: hand that to the user rather than working around it.
