---
name: hey-xray
description: Holds an extensive discussion with the user in an xray file (.hey/Xrays/xNNN--slug.md) instead of the chat, following the bundled xray template — topics, questions, propositions, one point per line, outcomes — so nothing gets lost and every point can be answered on its own. Use it when the user asks for an xray or adds --x / --xray to a message ("let's discuss this in an xray", "move this to an xray", "x004 has my replies"), to move a chat or an interview into one, to bring an xray back into the chat ("show x004 here", "--chat"), and on your own whenever an answer would hold several questions, options to weigh, or a design to agree on. Quick questions and short back-and-forth stay in the chat or the question tool.
license: MIT
metadata:
  author: dotHey
---

# Xray

An xray is the project's place to discuss a topic at length: the chat is for short messages, the xray for anything with several questions, options, or points to answer one by one.

**Follow the template's format exactly, in every xray and every edit of one.** Its spacing, blank lines, rules, marks, and nesting are deliberate, so the file reads and answers well in any editor: never tidy, reflow, or normalize its Markdown, even where it looks unusual or a linter would complain.

## Chat, question tool, or xray

- **Chat:** a quick clarification, a suggestion, a short back-and-forth.
- **Question tool** (the harness's, e.g. AskUserQuestion): a few quick questions with clear options. When you ask two or more, make the first one "Move this to an xray?", with "No, answer here" first and "Yes, open an xray" second.
- **Xray:** anything longer, or anything the user wants kept.

## Open one

1. Check it isn't open already: `bash hey frontmatter:show Xrays` (status, description).
2. Create it: `bash hey xrays:create "<Title>" --description "<what it settles, and why>"`. It prints the path.
3. Fill it from the template (`xray-template.md`, next to this skill):
   - One topic (`## I.`) per subject, one question (`### 1.`) per decision to make.
   - **Context:** only what the question needs.
   - **Propositions:** the recommended one first, as A.
   - **Discussion:** one point per line, each a single reason, question, pro, or con, never a whole take in one line. Your points start with 🤖; the user's have no mark.
   - Mark with 🛎️ every point that needs the user's answer.
   - Keep the template's spacing: two blank lines before a question, a rule (`---`) between questions, five blank lines before a new topic.
4. Reply in the chat with the path only: `✅ Xray: <full path>`, plus the number of 🛎️ points waiting. Never repeat its content in the chat.

## Move a chat or an interview into one

When the user replies with just `--x`, says so ("move this to an xray"), notes it in an interview answer, or picks "Yes, open an xray":

1. Open an xray on the topic, as above.
2. Carry over what was said, nothing more: each question asked becomes a question, its options become propositions, and each answer or remark becomes a point (the user's unmarked, yours with 🤖). Tick `[x]` on what is already settled.
3. Set its status to `discussing`, and reply with the path only.

## Continue one

When the user says they replied ("check x004", "replied in the xray"):

1. Read the xray; answer only what is new or marked 🛎️ for you.
2. Reply under the exact point, as a nested 🤖 point. Edit in place with small edits; never rewrite the file or reorder points.
3. Tick `[x]` on the points you actioned, and on the proposition chosen.
4. Write the **Outcome** once a question is settled, and set the topic mark (✅ decided, ⛔️ blocked, ⏸️ paused). Update the frontmatter `status` and `modified` when the whole xray moves on (`decided` once every question is, `done` once its next steps are).
5. Reply in the chat with the path and what changed, in one line.

## Bring one back into the chat

When the user asks for it ("show x004 here", `--chat`), for when no editor is at hand:

1. Show only what is open, compactly: per question its reference (`I1`), the question, the propositions as `A`/`B`, and the 🛎️ points waiting, each with its reference (`I1--2`).
2. Ask them to reply by reference ("I1: B", "I1--2: agreed, but…").
3. Write each answer into the xray under its point, exactly as with a reply in the file, then reply with the path and what changed.

## Link it

- An outcome that produces a decision, a feature, or a task links it in **Outcome** (`[d007](../Decisions/d007--slug.md)`), and that record cites the xray back where it explains its origin.
- Refer to a point as `I2--3.1.1` (topic, question, point) in the same xray, or `x004 I2--3.1.1` from anywhere else.
- An xray is discussion, not commitment: the work it settles goes through features, decisions, and tasks as usual.
