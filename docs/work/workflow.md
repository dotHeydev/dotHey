---
title: The workflow
description: How agents onboard, and how a feature goes from idea to tested code.
order: 1
---

# The workflow

## Onboarding

Every session starts with the `hey-onboard` skill (agents run it when you say *"hey"*, after a context compaction, or as a fresh subagent). The root `AGENTS.md` points every agent to dotHey's kernel (`.hey/.core/KERNEL.md`), and the skill walks it through the project, its rules, where the context lives, and the tools at hand.

If `.hey/hey.json` says the context isn't ready yet (`state.isReady`), the agent offers to run `hey-ready`, which turns your answers into the context files.

## The feature workflow

Features go through four stages, each written down before the next begins:

| Stage | Skill | Result |
|---|---|---|
| 1. Specify | `hey-document-feature` | `.hey/Features/fNNN--slug.md`, its specification in Given/When/Then |
| 2. Plan | `hey-draft-feature-plan` | An implementation plan in that same file |
| 3. Test | `hey-write-feature-tests` | Tests derived from the specification, failing before any code exists |
| 4. Build | `hey-implement-feature` | Code written against those tests, one at a time |

`hey-build-full-feature` chains all four and enters wherever the work actually is. The order is the point: the specification is what the tests come from, and the failing tests are what say the work is done.
