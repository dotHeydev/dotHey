---
title: What a plugin is
description: What a plugin can bring, and how it reaches the project.
order: 1
---

# What a plugin is

A plugin is a GitHub repo, `<owner>/<name>`, with a `dothey/` directory. That directory is all dotHey installs, into `.hey/.plugins/<owner>/<name>/`; the rest of the repo is yours.

A plugin can bring:

- **Commands**, run as `bash hey <owner>:<command>`.
- **Skills and agents**, linked where the harness reads them.
- **Context**, appended to dotHey's docs (`STANDARDS.md`, `TECHSTACK.md`, …).
- **Stubs**, appended to files in the project.
- **Code**, organized as you like and loaded through dotHey's module system.

Everything that touches the project is a *suggestion*: it lands under `"inactive"` in the links, and only the user takes it, with `bash hey plugins:link`.

Plugins that add what is specific to one harness or one tech stack are ordinary plugins too: see [Harness plugins](harness-plugins.md) and [Stack plugins](stack-plugins.md).
