---
title: Context, skills, agents, and stubs
description: What a plugin's directories become in the project.
order: 5
---

# Context, skills, agents, and stubs

| Directory | Suggested as |
|---|---|
| `context/<Doc>.md` | An append to `.hey/<Doc>.md`, created when dotHey has none |
| `skills/<name>/` | A link into `.agents/skills/` |
| `agents/<name>.md` | A link into `.agents/agents/` |
| `stubs/<path>.stub` | An append to `<path>` in the project |

- Appends go between markers naming the plugin, so they never collide with dotHey's or another plugin's, and are taken back cleanly on removal.
- A skill or agent with the same name as dotHey's or another plugin's is reported; wherever both link to one place, the first declared wins.
