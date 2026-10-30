---
title: bash hey setup:*
description: Every setup command, with its usage, options, and examples.
order: 2
---

# bash hey setup:*

## `setup`

Set dotHey up for the project's harnesses.

```text
Finds the harnesses the project uses and what they already hold, then links
dotHey where the chosen ones read it: AGENTS.md (or an import into their own
instructions file), and dotHey's skills and agents. In parallel, the
project's own skills and agents stay where they are; centralized, they move
into .hey/Skills/ and .hey/Agents/ and are linked back.
It shows the plan and asks before changing anything; with no one at a
terminal to ask, it only shows the plan. Run it again to change the choice:
harnesses no longer chosen are unlinked.

Usage:
  bash hey setup [--harness <a,b>] [--type parallel|centralize] [--dir <path>]
                 [--preview] [-y, --yes]

Options:
  --harness <a,b>       Optional. The harnesses to link: agents amp antigravity
                        claude codex copilot cursor factory grok junie kiro
                        opencode pi zed Without it, a terminal asks, the
                        detected ones checked.
  --type <name>         Optional. parallel (the default): the project's skills
                        and agents stay where they are. centralize: they move
                        into dotHey and are linked back.
  --dir <path>          Optional. Where dotHey lives afterwards: .hey (now) or
                        .agents/.hey; see bash hey relocate.
  --preview             Optional. Show the plan, and stop. Also --dry-run.
  -y, --yes             Optional. Apply without asking: at a terminal, for an AI
                        agent, or when dotHey itself runs it.
  -h, --help            Show this help.

Examples:
  bash hey setup
  bash hey setup --harness claude,cursor --type parallel --yes
  bash hey setup --harness claude --type centralize --preview
```

## `setup:done`

Mark what setup left for the agent as finished.

```text
Marks items of what bash hey setup left for the agent (state.setup.pending, also
in bash hey adopt --scan --json) as finished, so they aren't raised again,
even after another setup.

Usage:
  bash hey setup:done <item>...

Arguments:
  <item>       context, split:<path>, unsure:<path>, or verify.

Options:
  -h, --help   Show this help.

Examples:
  bash hey setup:done context
  bash hey setup:done unsure:IDEAS.md split:CLAUDE.md
```
