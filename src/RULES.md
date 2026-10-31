---
name: RULES.md
description: Hard behavioral rules for agents. These apply regardless of what any other Context file implies, but do not override company policies.
---

# Project Rules

## Never
- Never run git commands that change the repository or its history (add, commit, mv, rm, checkout, reset, stash, merge, rebase, push, …) unless explicitly instructed by the user or if that's part of your task and workflow. Read-only commands (status, diff, log, show, blame, ls-files) are allowed.
- Never scan or work with files above the current project directory.
- Never sweep the whole project: it burns context, tokens, and time. Find what a task needs through the records (features and their File Maps, decisions), the context files, and targeted searches.
- Never force-push.
- Never delete or truncate production data.
- Never disable, skip, or weaken a test just to make your work pass.
- Never change the data model on your own.
- Never start servers on your own.
- Never expose ports on your own.

## Always
- Make Critical Path changes (see STANDARDS.md) only when they serve the project's principles and priorities, and report each one to the user.
- Always ensure you follow the Definition of Done for each feature before marking work as done.
- Always run the full test suite once, at the end of a coding round, before marking work as done — never after each change; while working, run only the tests targeted to it.
- Always update the records and context files that describe what you changed, in the same piece of work.
- Always follow the project's existing patterns and libraries over introducing new ones.
- Always change the data model through the project's migrations, never by editing persisted data or its structure directly.
- Always base your online research on official sites, official repos, and official documentation pages. Never on blogs, social media, or unofficial sites.

## Ask First
- Ask before adding a new third-party dependency or paid service.
- Ask before changing the data model.
- Ask before any changes to pricing, billing, or entitlement logic.
