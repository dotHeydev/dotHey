---
name: KERNEL.md
description: How dotHey works and how every agent uses it in this project. Always read, never skipped.
---

# dotHey

This project is guided by dotHey: its context, rules, tools, and records govern your work here. This file belongs to dotHey and is replaced on every upgrade; the project adapts everything else through the files in `.hey/`.

## The three layers

- **Context:** what you must know about the project, one Markdown file per concern at the top of `.hey/` (guidelines, rules, security, standards, product, tech stack, data model, schema, design, nomenclature, company, and the user's preferences).
- **Tools:** the `bash hey` commands and your skills, dotHey's (`hey-*`) and the ones plugins add.
- **Work:** the records that guide the work: features (`.hey/Features/`), decisions (`.hey/Decisions/`), notes (`.hey/Notes/`), xrays (`.hey/Xrays/`), and tasks (`bash hey tasks:list`).

## Context files

- Every context file declares a `description` in its frontmatter: when it is the file to read. Survey them with `bash hey frontmatter:show .hey/`, and read in full only what the task calls for.
- A file with `ignore: true` in its frontmatter is skipped: either it isn't filled in yet, so its placeholders are not facts, or the user switched it off. Read it only to fill it in.
- At the start of every session, read these unless they are already in your context: `.hey/GUIDELINES.md`, `.hey/RULES.md`, `.hey/SECURITY.md`, `.hey/USER.md`, and `.hey/PRODUCT.md`. Read the rest on demand.
- Instructions come in three layers, highest first: the organization's policies (provided by your system, outside the project), the project's (dotHey's files), and the user's preferences (`.hey/USER.md`). A higher layer wins outright. Never resolve a conflict silently: say which instruction was overridden, by what, and why. When it's unclear which layer an instruction belongs to, ask.
- Context a plugin adds sits in the top-level docs, between `<!-- <owner>/<name> -->` markers.

## Tools

- `bash hey` lists every command; each answers `--help` (and `--help --json`) with what it does, what it changes, and when to use it. Use a command wherever one exists instead of doing its work by hand: it knows the paths, the numbering, the exclusions, and the rules.
- When a command needs a person at a terminal, it says so with the exact command: hand that to the user rather than working around it.
- Invoke a skill whenever the task is the one it covers.

## How work flows

- **Features** go through four stages, each written down before the next begins: specification (`hey-document-feature`), plan (`hey-draft-feature-plan`), failing tests (`hey-write-feature-tests`), then code (`hey-implement-feature`). `hey-build-full-feature` chains them. The order is the point: the tests come from the specification, and the failing tests say when the code is done.
- **Decisions** record what the project has settled (`hey-document-decision`). Survey them before you assume something is undecided.
- **Xrays** hold any discussion with several questions or options, in a file instead of the chat (`hey-xray`).
- **Notes and tasks** are the user's to raise: open them only when the user's request is about them. Working on one, answer inside it (a task through `bash hey tasks:update`), and reply in the chat with `✅ Done: <path or link>` only.
- **Done** means the Definition of Done in `.hey/STANDARDS.md` is met.

## Keep everything in sync and in its place

- One fact, one place: put it in the file whose `description` claims it, and reference it from anywhere else instead of copying it.
- When behavior or scope changes, update what records it in the same piece of work: the feature and its File Map, the decisions, `DATAMODEL.md`, `SCHEMA.md`, and the context file that owns it.
- dotHey complements your harness; it never replaces what the harness does. Use the harness's memory, rules, plans, and subagents as it intends, and keep what dotHey records in step with them.

## Learning from corrections

When the user corrects you or states a lasting preference, apply it, save it to your harness's memory as you normally would, and offer once to make it durable for the project and every harness with `hey-learn`.

## Onboarding

Run the `hey-onboard` skill at the start of a session, after a context compaction, and when you start as a subagent with no prior context. Without skill support, follow `.hey/.core/modules/onboarding/skills/hey-onboard/SKILL.md` yourself.
