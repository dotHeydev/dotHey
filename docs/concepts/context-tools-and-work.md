---
title: Context, tools, and work
description: The three things an agent needs to work well, and how dotHey layers its instructions.
order: 1
---

# Context, tools, and work

dotHey covers the three things an agent needs to work well:

- **Context:** what the agent must know about the project: product, rules, security, standards, stack, data model, design, nomenclature. One Markdown file per concern, at the top of `.hey/`.
- **Tools:** what helps it work faster and reliably: skills, the `hey` command, harness settings.
- **Work:** the artifacts that guide the work: feature specifications, plans, decisions, tasks, notes, and xrays.

## How the instructions are layered

- **The kernel** (`.hey/.core/KERNEL.md`) teaches every agent what dotHey is and how to use it. It's dotHey's own: always read, and improved by every upgrade. The root `AGENTS.md` points agents to it.
- **The guidelines** are dotHey's opinionated defaults: `GUIDELINES.md` (how agents work and reply), `RULES.md`, `SECURITY.md`, and `STANDARDS.md`. They're active from the start, and yours to change.
- **The project's context** (`PRODUCT.md`, `TECHSTACK.md`, `DATAMODEL.md`, and the rest) describes your project. It ships empty, and your agent fills it with you through the `hey-ready` skill.

Each context file declares a `description` in its frontmatter saying when to read it, so agents survey them cheaply (`bash hey frontmatter:show .hey/`) and open in full only what a task needs.

A file with `ignore: true` in its frontmatter is skipped. The project's context files ship with it until they're filled in; add it to any other file to switch that file off.
