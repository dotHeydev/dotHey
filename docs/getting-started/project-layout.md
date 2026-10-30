---
title: Project layout
description: What dotHey adds to your project, and what each part is for.
order: 6
---

# Project layout

```text
your-project/
├── hey                     # the entry point: bash hey <command>
├── AGENTS.md               # linked from .hey/AGENTS.md: points agents to dotHey
└── .hey/
    ├── AGENTS.md           # the entry every agent reads first
    ├── GUIDELINES.md  RULES.md  SECURITY.md  STANDARDS.md
    ├── PRODUCT.md  TECHSTACK.md  DATAMODEL.md  …
    ├── USER.md             # your own preferences
    ├── hey.json            # the project's settings, links included
    ├── Features/  Decisions/  Notes/  Xrays/  Tasks/
    ├── .plugins/           # installed plugins, with plugins-lock.json
    └── .core/              # dotHey itself, replaced by bash hey upgrade
        └── KERNEL.md       # how every agent uses dotHey
```

The inside of `.hey/.core/` is described in [Architecture](../extending/architecture.md).
