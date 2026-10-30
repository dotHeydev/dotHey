---
title: Stack plugins
description: Plugins that add what is specific to one language, framework, or platform.
order: 14
---

# Stack plugins

dotHey's defaults hold for any language and framework. A stack plugin adds what one stack needs on top:

- **Context:** its conventions, appended to dotHey's docs: `context/STANDARDS.md` for its practices, `context/TECHSTACK.md` for its commands (build, test with its filters, lint, format, migrate), `context/NOMENCLATURE.md` for its naming.
- **Skills:** its specifics for dotHey's workflow, such as a write-tests skill for its test framework, which `hey-write-feature-tests` follows alongside its own steps.
- **Commands:** what the workflow needs from the stack, such as a schema dump into `SCHEMA.md` or a references search for File Maps.

Write context that refines dotHey's defaults rather than repeating them: only what is true for the stack and not already said. A stack plugin is an ordinary plugin: see [Creating a plugin](creating.md).
