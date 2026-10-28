---
name: dot-ready
description: Gets dotdot ready for this project — turns what the user tells you about the project, its tech, the company, and their rules into the context files at the top of .dot/. Use it when the user says they're using dotdot or just installed it, asks to set up, prepare, fill, or refine the project's context (or one file of it, e.g. "let's write PRODUCT.md"), or agrees to prepare it when onboarding finds dotdot not ready (state.isReady not true in .dot/dot.json), or says "set up dotdot". If it is true, the context was prepared before: offer to refine it instead.
metadata:
  internal: true
---

# Get dotdot ready

## Goal
Short, accurate, project-specific context files, derived from the user talking freely — not from a questionnaire, and not from them writing the files.

## Before Start
Output exactly: 🧭🧭🧭 GETTING DOTDOT READY

## Scope
The Markdown files at the top of `.dot/`. Survey them with the `dot-tool-scan-frontmatter` skill: `ignore: true` marks a file still to fill. Read a file in full only once something goes into it.

- `RULES.md`, `SECURITY.md`, and `STANDARDS.md` ship with defaults: keep them, only extend them and replace placeholders.
- `USER.md` holds the user's personal preferences: fill it only with what they say about how they like to work.
- Out of scope: `AGENTS.md`, `SCHEMA.md` (generated), and plugin regions (between `<!-- <owner>/<name> -->` markers).

## 0. Pick up where setup left off
Run `bash dot adopt --scan --json` once. Its `setup` holds the user's choices and `setup.pending` what is left for you, in order; work through it, and run `bash dot setup:done <item>` as each one is finished (also when the user decides to leave it), so nothing is raised twice. If `setup.harnesses` is empty, hand the user the setup first (`dot-tool-setup`), and carry on with the context meanwhile.

`setup.strategy` is how the user wants dotdot to treat the project's existing context:

- **combine:** the project's files stay the source. Leave them where they are; take into dotdot's docs only what the user confirms, as a summary or a reference to the file, never moving or deleting it.
- **own:** dotdot becomes the source. Once the user confirms, move a file's content into the dotdot docs it belongs to, and leave behind only what its harness needs (the import or link setup added).
- **`null`:** no one chose yet. Ask which of the two they intend before changing anything outside `.dot/`.

The items:

- **`context`:** steps 1 to 3 below.
- **`split:<path>`** (own): propose, part by part, where the file's content belongs (RULES, STANDARDS, TECHSTACK, ...); move what the user approves, leaving the file with only what its harness needs.
- **`unsure:<path>`:** a top-level doc no harness claims (`IDEAS.md`, `QUALITY.md`, ...). Raise all of them in one message, with your guess for each (fold into a context doc, reference it, keep it out, or a note), and ask whether they belong to the project's context; read one only once the user says it does, then act on it per the strategy.
- **`verify`** (own): check that the integration works: `bash dot link --preview` says everything is linked, and `bash dot adopt --scan --json` lists none of the moved items back in a harness's places as real files. Point out any agent in `.dot/Agents/` with `tools` or `model` in its frontmatter: those fields don't port between harnesses. Fix what isn't right with dotdot's commands, or tell the user what is wrong.

## 1. Invite
One friendly plain chat message, not the Interview Tool, then wait for the answer. If `state.isReady` is `true` in `.dot/dot.json`, say the context was prepared before and ask what they'd like to add or change. Otherwise, invite them to talk, for example:

"Tell me about your project: what it is and who it's for, the tech it's built with, the company behind it, how you like to work, and any rules I must always follow. Write as much or as little as you like, in any order — pasting existing docs works too."

If the user named one file, ask about that file's topics only.

**An existing project** (the scan lists `items`, or the project has code): don't wait for the user to describe what the project already says. Read cheap signals only: the scan's items, the manifests (`package.json`, `composer.json`, `go.mod`, ...), the README, the CI config, and a two-level tree. Never read source wholesale, and ask before reading anything beyond these. Then draft from it (step 2), and invite the user to confirm or correct the draft in one pass instead of starting from a blank page.

## 2. Derive
Sorting is your job, not theirs: place each piece of what they shared into the section it belongs to, in whichever file.

- `COMPANY.md`, `PRODUCT.md`, `DESIGN.md`: one to three short declarative sentences per section, no bullets, no marketing language.
- Every other file: short bullets, one fact or rule each.
- Never invent. A section nothing fits keeps its placeholder; a topic no section fits gets a new section.
- A fact drawn from the project's files rather than the user's words is marked *(inferred)* until the user confirms it.
- The project's own instruction files (`CLAUDE.md`, `.cursor/rules/`, `.github/copilot-instructions.md`, ...): propose where each part belongs (RULES, STANDARDS, TECHSTACK, ...) instead of copying them verbatim, and move it only once the user agrees. Flag every conflict with dotdot's rules or another file; never resolve one silently.
- Change links and files only with dotdot's commands (`bash dot setup`, `bash dot link`), never with your own scripts.
- Replace a section's italic `_..._` prompt with the real content; leave sections already written alone, unless the user asked to change them.
- Remove `ignore: true` from a file once its main sections hold real content.

The Interview Tool stays available whenever a choice is genuinely clearer as options — e.g. two statements that conflict — never as a survey.

Then set `state.isReady` to `true` in `.dot/dot.json`, changing nothing else in the file, and run `bash dot setup:done context` if it is pending.

## 3. Report
Tell the user, in the Reporting template of `AGENTS.md`, that the context is ready based on what they shared:

- ✅ The files prepared.
- ⚠️ Only the gaps that would weaken the work — a file still empty, or a section too thin to guide decisions (e.g. no tech stack, no audience for the product) — each with what would make it sound. Don't list every empty section, and don't ask questions for their own sake; they can add more anytime by just telling you.

## Finishing
Output exactly: ✅✅✅ DOTDOT IS READY

Then stop: don't touch any other file, nor code anything. If onboarding invoked you, it picks up from here.
