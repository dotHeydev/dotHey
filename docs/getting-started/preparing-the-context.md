---
title: Preparing the context
description: Turning what you know about the project into the context files every agent reads.
order: 3
---

# Preparing the context

Once dotHey is set up, tell your agent *"set up dotHey"* (or just *"I'm using dotHey"*). The `hey-ready` skill takes it from there:

1. It finishes whatever setup left for it, such as splitting your existing instruction files into dotHey's.
2. It invites you to talk about the project: what it is and who it's for, the tech, the company, how you like to work, and your rules. Write as much or as little as you like; pasting existing docs works too.
3. For an existing project, it reads cheap signals first (manifests, the README, the CI config) and drafts from them, so you correct a draft instead of starting from a blank page.
4. It places each piece where it belongs: `PRODUCT.md`, `TECHSTACK.md`, `RULES.md`, and the rest. Facts it inferred are marked *(inferred)* until you confirm them.

When it's done, `state.isReady` in `.hey/hey.json` is `true`, and every new session onboards with the full context. Tell your agent more at any time; it updates the right file.

Next: [build your first feature](your-first-feature.md).
