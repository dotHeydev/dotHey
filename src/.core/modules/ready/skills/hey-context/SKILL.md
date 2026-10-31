---
name: hey-context
description: Prepares the project's context in dotHey — turns what the user tells you about the project, its tech, the company, and their rules into the context files at the top of .hey/. Use it when `grep -qE '"isReady": *true' .hey/hey.json` exits non-zero, or when the user asks to prepare, fill, refine, or change the project's context or one file of it (e.g. "let's write PRODUCT.md"). Linking harnesses and the rest of setup is `hey-setup`'s job, not this one's.
license: MIT
metadata:
  internal: true
  author: dotHey
---

# Project Context

Output exactly:
```
🧭🧭🧭 PREPARING PROJECT CONTEXT
```

## Goal
Short, accurate, project-specific context files, derived from the user talking freely — not from a questionnaire, and not from them writing the files.

## Scope
The Markdown files at the top of `.hey/`. Survey them with `bash hey frontmatter:show .hey/`: `ignore: true` marks a file still to fill. Read a file in full only once something goes into it.

- `RULES.md`, `SECURITY.md`, and `STANDARDS.md` ship as dotHey's opinionated defaults, active from the start: keep them, only extend them and replace placeholders. A user who wants one off sets `ignore: true` in its frontmatter.
- `USER.md` holds the user's personal preferences: fill it only with what they say about how they like to work.
- Out of scope: `AGENTS.md` and `.core/DOTHEY.md` (dotHey's), `SCHEMA.md` (generated), and plugin regions (between `<!-- <owner>/<name> -->` markers).

## 1. Know where you start
Two answers, each from a command:

- **Prepared before:** `grep -qE '"isReady": *true' .hey/hey.json` exits zero.
- **Existing project:** `bash hey adopt --scan --json` lists `items`, or `ls package.json composer.json go.mod Cargo.toml pyproject.toml Gemfile pom.xml 2>/dev/null` prints anything.

## 2. Invite
One friendly plain chat message, not the Interview Tool, then wait for the answer.

- **The user named one file:** ask about that file's topics only.
- **Prepared before:** say so, and ask what they'd like to add or change.
- **Existing project:** don't wait for the user to describe what the project already says. Read cheap signals only: the scan's `items`, the manifests, the README, the CI config, and a two-level tree. Never read source wholesale, and ask before reading anything beyond these. Draft from them (step 3), then invite the user to confirm or correct the draft in one pass.
- **Otherwise:** invite them to talk, e.g. "Tell me about your project: what it is and who it's for, the tech it's built with, the company behind it, how you like to work, and any rules I must always follow. Write as much or as little as you like, in any order — pasting existing docs works too."

## 3. Derive
Sorting is your job, not theirs: place each piece of what they shared into the section it belongs to, in whichever file.

- `COMPANY.md`, `PRODUCT.md`, `DESIGN.md`: one to three short declarative sentences per section, no bullets, no marketing language.
- Every other file: short bullets, one fact or rule each. `TECHSTACK.md` → Commands lists the exact commands, read from the manifests and scripts.
- Never invent. A section nothing fits keeps its placeholder; a topic no section fits gets a new section.
- A fact drawn from the project's files rather than the user's words is marked *(inferred)* until the user confirms it.
- The project's own instruction files (`CLAUDE.md`, `.cursor/rules/`, `.github/copilot-instructions.md`, ...): follow `setup.type` from the scan. With `parallel`, take in only what the user confirms, as a summary or a reference. With `centralize`, splitting them is `hey-setup`'s `split:` item: don't do it here.
- Flag every conflict with dotHey's rules or another file; never resolve one silently.
- Replace a section's italic `_..._` prompt with the real content; leave sections already written alone, unless the user asked to change them.
- Remove `ignore: true` from a file once its main sections hold real content.

The Interview Tool stays available whenever a choice is genuinely clearer as options — e.g. two statements that conflict — never as a survey.

## 4. Mark it ready
Only after a pass over the whole context, not a single-file request:

- Set `state.isReady` to `true` in `.hey/hey.json`, changing nothing else in the file.
- If the scan's `setup.pending` lists `context`, run `bash hey setup:done context`.

## 5. Report
In the reply format of `DOTHEY.md`:

- ✅ The files prepared.
- ⚠️ Only the gaps that would weaken the work — a file still empty, or a section too thin to guide decisions (e.g. no tech stack, no audience for the product) — each with what would make it sound. Don't list every empty section, and don't ask questions for their own sake; the user can add more anytime by just saying it.

Output exactly:
```
✅✅✅ PROJECT CONTEXT READY
```

Then stop: touch no other file and code nothing. Go on with the next start-up check in `DOTHEY.md`.
