---
title: Who owns what
description: What your project owns after installing dotHey, and the one part dotHey keeps.
order: 3
---

# Who owns what

dotHey is a starting point, not a dependency. The installer copies `.hey/` into your project and links its sources where your harness reads them (`AGENTS.md`, `.claude/`, and so on). From then on the project owns the result: edit, extend, or remove anything, and commit `.hey/` with your code.

Only `.hey/.core/` belongs to dotHey: `bash hey upgrade` replaces it, and leaves your context, records, and plugins alone.
