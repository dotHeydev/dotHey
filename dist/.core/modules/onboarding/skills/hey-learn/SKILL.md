---
name: hey-learn
description: Turns a correction or a lasting preference the user gave into one line in the right dotHey file, so every session, every harness, and the whole team keep it — alongside the harness's own memory, never instead of it. Use when the user corrects how you work ("don't do X", "always Y", "we never Z here"), states a preference meant to last, says "remember this" or "learn this", or when you just saved something to your harness's memory that the project should keep too.
license: MIT
metadata:
  internal: true
  author: dotHey
---

# Learn

## Goal
A lesson the user taught lives in the one dotHey file where agents already look for it, confirmed by the user, worded as a rule any agent can follow.

## Before Start
Output exactly: 🧠🧠🧠 BEGIN LEARNING

## Process

1. **Keep the harness's memory working.** If your harness has a memory, save the lesson there as it normally would. This skill adds the project's copy; it never replaces or moves the harness's.

2. **State the lesson as a rule.** One imperative line: what to do or avoid, and when. Add the reason in a few words when it isn't obvious. Generalize from the incident to the pattern, never beyond what the user said.

3. **Find its place.** Survey with `bash hey frontmatter:show .hey/` and pick the one file whose `description` claims it:
   - how this user likes to work → `USER.md`;
   - a hard rule for every agent (Never, Always, Ask First) → `RULES.md`;
   - an engineering practice → `STANDARDS.md`;
   - a security practice → `SECURITY.md`;
   - a name or term → `NOMENCLATURE.md`;
   - a command of the project (build, test filters, lint) → `TECHSTACK.md` → Commands;
   - a settled rule that constrains future work and carries a tradeoff → a decision, through `hey-document-decision`.

4. **Check it isn't there already.** Read the target section. If a line already says it, sharpen that line instead of adding one. If the lesson contradicts a line, or a higher layer (the organization's policies, then the project's files, then `USER.md`), stop and show the conflict; never resolve it silently.

5. **Confirm, then write.** Show the user the line and its file in one message, and write it only once they agree. Add it to the section it belongs to, matching the file's format; never append a loose list at the end.

6. **Report** per the reply format in `GUIDELINES.md`: ✅ the file and the line.

## Scope
One lesson per run. Never edit dotHey's own files (`.hey/.core/`), plugin regions (between `<!-- <owner>/<name> -->` markers), or records other than through their own skills.

## Finishing
Output exactly: ✅✅✅ DONE LEARNING
