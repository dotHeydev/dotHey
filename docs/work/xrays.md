---
title: Xrays
description: Discussions held in a file, one point per line, so every point can be answered on its own.
order: 5
---

# Xrays

An xray is a discussion held in a file instead of the chat: topics, questions, propositions with the recommended one first, and a discussion broken down **one point per line**, so you can answer any point on its own. Agents open one when a topic is too big for the chat, or when you add `--x` to a message.

```markdown
## I. ⚠️ Caching

### 1. Where should we cache rendered pages?

**Propositions:**

- [ ] A — At the edge (recommended)
- [ ] B — In the app

**Discussion:**

1. 🤖 The edge keeps origin load flat during spikes.
2. 🤖 🛎️ Do we need per-user pages cached too?
   1. Only for logged-out users.

**Outcome:** A, logged-out pages only → [d012](../Decisions/d012--edge-cache.md)
```

- 🤖 marks the agent's points; yours have no mark.
- 🛎️ asks the other side for a reply.
- `[ ]` tracks what's to action; `[x]` what's done.
- Refer to a point as `I1--2.1`, or `x004 I1--2.1` from elsewhere.

The agent replies in the chat with the file's path only, answers in place, and can bring the open questions back into the chat (`--chat`) when you're away from an editor.
