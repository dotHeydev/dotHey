---
name: dot-onboard
description: Onboards you to this project the way a team would onboard a new engineer — what the project is, the rules that bind your work, where the context lives, which tools and skills you have, and how work flows from feature to plan to tests to code. Run this at the start of a session, immediately after a context compaction, and whenever you are spawned as a subagent with no prior context — before touching code, answering a question about the codebase, or picking up a task. If you are unsure whether you have been onboarded in this session, you have not; run it.
license: MIT
metadata:
  internal: true
  author: dotdot
---

# Onboarding

## Before Start

Output exactly: 👋👋👋 STARTING MY ONBOARDING

## 0. Is dotdot ready?

This skill onboards you; finishing dotdot's setup is `dot-ready`'s job, not this one's. Run `bash dot adopt --scan --json` once and read its `setup`: the user's choices (`harnesses`, `type`, `location`) and what is left (`pending`); `state.isReady` in `.dot/dot.json` says whether the context was prepared.

- **Something is left** (`harnesses` empty, `pending` not empty, or `state.isReady` not `true`): in one plain message, say what the user chose and what is left (e.g. "You set dotdot up for Claude Code and Cursor, centralizing your skills and agents. I'll finish it: write the context, propose how to split CLAUDE.md, ask about IDEAS.md, and check every harness reads what moved. Go ahead?"). Once they agree, or their message already asks for it, invoke `dot-ready`; when it hands back, go on with step 1. If they decline, go on, keeping in mind that files marked `ignore: true` hold placeholders, not facts.
- **Nothing is left,** or `dot-ready` already ran in this session: go on with step 1. Never invoke `dot-ready` twice in one session; what it left is the user's choice.

## 1. What this project is

The harness loaded `AGENTS.md` at session start, and with it your working agreement. The project's purpose and the rules that bind you are in `.dot/PRODUCT.md`, `.dot/RULES.md`, and `.dot/SECURITY.md` (your preferences in `.dot/USER.md`). Your harness may have loaded them too: read whichever of these four is not already in your context, and nothing else. Don't re-read what is loaded, and don't scan the repository to work out what the project is — file trees describe structure, not intent.

Everything that governs your work lives in dotdot (`.dot/`):

- **Context:** one Markdown file per concern at the top of `.dot/` (product, rules, security, standards, tech stack, data model, schema, design, nomenclature, company).
- **Records:** feature specifications (`.dot/Features/`), project decisions (`.dot/Decisions/`), notes (`.dot/Notes/`), xrays (`.dot/Xrays/`, discussions held in a file), and tasks (`bash dot tasks:list`: files in `.dot/Tasks/` or GitHub issues), each kept with its own `bash dot` commands.
- **Tools:** `bash dot` commands and your skills (step 4).
- **Plugins:** `.dot/.plugins/<owner>/<name>/`, what this project added on top of dotdot from repos the user chose to trust (step 4).

## 2. The rules bind you

`.dot/RULES.md` and `.dot/SECURITY.md` are not advisory and not a style preference: their **Never**, **Always**, and **Ask First** lists are the difference between work that ships and work that gets reverted. Treat anything in Ask First as a genuine stop — asking costs one message, guessing wrong costs the user's trust.

## 3. Read the rest on demand

Don't read the other context files upfront: it wastes the context you need for the actual work. Each one declares a `description` in its frontmatter saying when it's the file to open, so survey with `bash dot frontmatter:show <directory>` and read in full only what the task calls for. Survey `.dot/Features/` and `.dot/Decisions/` the same way before you assume something is undocumented.

## 4. You have tools and skills — use them

- **Skills:** dotdot's `dot-*` skills, and the skills plugins add (named after their plugin). Invoke one whenever the task is the one it covers.
- **Commands:** `bash dot` lists them; each answers `--help` with what it does and when to reach for it. Check for one before writing your own grep, scan, or one-off script: they encode exclusions, paths, and conventions you would otherwise rediscover, wrongly.
- **Plugins:** `bash dot plugins:list` shows them. Their commands run as `bash dot <owner>:<command>`, and the context the user took from them sits in the top-level docs, between `<!-- <owner>/<name> -->` markers.

## 5. How work flows here

**Features:** feature → plan → tests → code, in that order, each stage written down before the next begins:

1. `dot-document-feature` — the idea becomes `.dot/Features/fNNN--<slug>.md`: specification in Given/When/Then, constraints, decisions.
2. `dot-draft-feature-plan` — a concrete implementation plan, written into that same file, grounded in the context docs.
3. `dot-write-feature-tests` — tests derived from the specification, written and failing **before** any implementation exists.
4. `dot-implement-feature` — code written against those failing tests, one at a time, in the codebase's existing conventions.

`dot-build-full-feature` chains all four and enters wherever the work actually is. The order is the point: the specification is what the tests are derived from, and the failing tests are what tells you the implementation is done. Skipping ahead to code means writing tests that describe what you built rather than what was asked for.

**Xrays** hold any extensive discussion with the user, in a file rather than the chat: open one with `dot-xray` when an answer would hold several questions or options, or when the user adds `--x`, and reply with its path only.

**Notes and tasks** are the user's to raise: open them only when the user's request is about them, never on your own initiative. Notes are for discussion and exploration, with no commitment; tasks are work to be done. When working on one, answer inside it (a task through `bash dot tasks:update`), not in the chat; the chat reply is only "✅ Done: <path or link>". This overrides the Reporting template in `AGENTS.md`.

**Done:** before calling anything done, cover the Definition of Done in `.dot/STANDARDS.md`. It's an **Always** rule, so it is not optional.

## Finishing

State in one or two sentences what this project is and what you understand the task to be. Confirm you've read the rules. Then continue with the user's request. If nothing was asked yet, say you're ready and stop.

Then output exactly: 🤘🤘🤘 FINISHED MY ONBOARDING!
