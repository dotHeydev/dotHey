---
name: hey-onboarding
description: Onboards you to this project the way a team would onboard a new engineer — what the project is, the rules that bind your work, where the context lives, which tools and skills you have, and how work flows from feature to plan to tests to code. Use it at the start of a session, right after a context compaction, and whenever you are spawned as a subagent with no prior context — before touching code, answering a question about the codebase, or picking up a task.
license: MIT
metadata:
  internal: true
  author: dotHey
---

# Onboarding

Output exactly:
```
👋👋👋 STARTING MY ONBOARDING
```

## 1. Learn how dotHey works
Read `.hey/.core/DOTHEY.md` unless it is already in your context: the layers, the context files, the tools, how work flows, the voice and reply format, and the start-up checks. Everything below assumes it.

## 2. Load the session's context
Run `bash hey frontmatter:show .hey/`, then read the files `DOTHEY.md` lists for every session, skipping those already in your context and those with `ignore: true` (their placeholders are not facts).

Nothing else: don't scan the repository to work out what the project is; file trees describe structure, not intent.

`RULES.md` and `SECURITY.md` are not advisory: their **Never**, **Always**, and **Ask First** lists are the difference between work that ships and work that gets reverted. Treat anything in Ask First as a genuine stop: asking costs one message, guessing wrong costs the user's trust.

## 3. Know what's at hand
- **Context on demand:** the survey from step 2 says when each other context file is the one to read; survey `.hey/Features/` and `.hey/Decisions/` the same way before you assume something is undocumented.
- **Commands:** `bash hey` lists them, and `bash hey plugins:list` the plugins that add more (`bash hey <owner>:<command>`).
- **Skills:** dotHey's `hey-*` skills and the ones plugins add. Invoke one whenever the task is the one it covers.

State in one or two sentences what this project is and what rules, standards, and security constraints control you.

Output exactly:
```
🚀 Onboarded and ready to build!
```

Then go on with the user's request. If nothing was asked yet, stop.
