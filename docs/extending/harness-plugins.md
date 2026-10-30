---
title: Harness plugins
description: Plugins that add what is specific to one harness.
order: 13
---

# Harness plugins

dotHey links its instructions, skills, and agents into every harness it supports with no plugin at all. A harness plugin adds what only one harness has: its settings, hooks, commands, or MCP servers, and anything its agents need to know about it.

- **Instructions reach agents through the root `AGENTS.md`**, which `bash hey setup` always provides. Link a plugin's context into dotHey's docs, or append it to `AGENTS.md`, never into a harness's own instructions file. A harness that reads its own file instead (Claude Code reads `CLAUDE.md`) gets an import of `AGENTS.md` from setup, so anything reaching `AGENTS.md` reaches it too.
- **dotHey's skills and agents** are origins a harness plugin can link: `@dotheySkills` and `@dotheyAgents`.
- **Keep it to the harness:** what a harness plugin adds should be true for that harness alone, so projects using several harnesses never see each other's specifics.

A harness plugin is an ordinary plugin: see [Creating a plugin](creating.md).
