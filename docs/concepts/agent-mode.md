---
title: Agent mode
description: How the hey command behaves when an AI agent runs it, and why agents can't approve changes for you.
order: 4
---

# Agent mode

When an AI agent runs `bash hey`, output turns plain: no colors, highlighting, or spinner, nothing ever prompts (even in a terminal), and anything that needs a person asks the agent to hand it over. It switches on by itself when `AI_AGENT` or `CLAUDECODE=1` is set, or with `--agent` on any command. `--no-input` (automatic under `CI`) does the same for scripts.

Commands that change what you'd want to review (linking, plugins, migrations, deletions) always need a confirmation by a person at a terminal; `bash hey upgrade` doesn't, so it can run unattended. `-y` skips the question but still needs one, so no agent can approve a change for you; `--preview` shows any of those changes to anyone, agents included.
