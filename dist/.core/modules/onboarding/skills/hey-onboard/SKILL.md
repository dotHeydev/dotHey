---
name: hey-onboard
description: Onboards you to this project the way a team would onboard a new engineer — what the project is, the rules that bind your work, where the context lives, which tools and skills you have, and how work flows from feature to plan to tests to code. Run this at the start of a session, immediately after a context compaction, and whenever you are spawned as a subagent with no prior context — before touching code, answering a question about the codebase, or picking up a task. If you are unsure whether you have been onboarded in this session, you have not; run it.
license: MIT
metadata:
  internal: true
  author: dotHey
---

# Onboarding

## Before Start

Output exactly: 👋👋👋 STARTING MY ONBOARDING

## 0. Is dotHey ready?

This skill onboards you; finishing dotHey's setup is `hey-ready`'s job, not this one's. Run `bash hey adopt --scan --json` once and read its `setup`: the user's choices (`harnesses`, `type`, `location`) and what is left (`pending`); `state.isReady` in `.hey/hey.json` says whether the context was prepared.

- **Something is left** (`harnesses` empty, `pending` not empty, or `state.isReady` not `true`): in one plain message, say what the user chose and what is left (e.g. "You set dotHey up for two harnesses, centralizing your skills and agents. I'll finish it: write the context, propose how to split your instructions file, and check every harness reads what moved. Go ahead?"). Once they agree, or their message already asks for it, invoke `hey-ready`; when it hands back, go on with step 1. If they decline, go on, keeping in mind that files marked `ignore: true` hold placeholders, not facts.
- **Nothing is left,** or `hey-ready` already ran in this session: go on with step 1. Never invoke `hey-ready` twice in one session; what it left is the user's choice.

## 1. Learn how dotHey works

Read `.hey/.core/KERNEL.md` unless it is already in your context: the layers, the context files, the tools, how work flows, and how to keep it all in sync. Everything below assumes it.

## 2. Load the session's context

Read the files the kernel lists for every session (`GUIDELINES`, `RULES`, `SECURITY`, `USER`, `PRODUCT`), skipping those already in your context and those with `ignore: true`. Nothing else: don't scan the repository to work out what the project is; file trees describe structure, not intent.

`RULES.md` and `SECURITY.md` are not advisory: their **Never**, **Always**, and **Ask First** lists are the difference between work that ships and work that gets reverted. Treat anything in Ask First as a genuine stop: asking costs one message, guessing wrong costs the user's trust.

## 3. Know what's at hand

- **Context on demand:** `bash hey frontmatter:show .hey/` surveys the other context files; `.hey/Features/` and `.hey/Decisions/` the same way, before you assume something is undocumented.
- **Commands:** `bash hey` lists them, and `bash hey plugins:list` the plugins that add more (`bash hey <owner>:<command>`).
- **Skills:** dotHey's `hey-*` skills and the ones plugins add. Invoke one whenever the task is the one it covers.

## Finishing

State in one or two sentences what this project is and what you understand the task to be. Confirm you've read the rules. Then continue with the user's request. If nothing was asked yet, say you're ready and stop.

Then output exactly: 🤘🤘🤘 FINISHED MY ONBOARDING!
