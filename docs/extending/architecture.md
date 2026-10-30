---
title: Architecture
description: How dotHey's core is organized.
order: 10
---

# Architecture

```text
.hey/.core/
├── system/          # what dotHey needs to run
│   ├── bin/hey      # the entry point
│   ├── boot.sh      # module loading and the hey:: API
│   ├── kernel.sh    # the command registry and dispatch
│   ├── paths.sh     # where everything is
│   ├── guards.sh    # the policy every action is checked against
│   └── link/  plugins/  update/  migrations/
├── modules/         # what dotHey can do
│   └── onboarding/  ready/  setup/  frontmatter/  housekeeping/  notes/
│       xrays/  features/  decisions/  tasks/  release/
├── harnesses/       # one folder per harness, and capabilities/ shared by them
├── framework/       # the only shared code
│   ├── helpers/     # project-agnostic building blocks
│   ├── console/     # command-line input and output
│   └── integrations/  # external services, each behind service.sh
├── KERNEL.md        # how every agent uses dotHey
└── hey.defaults.json
```

- **System parts** load as `core.system.<part>.*`, **modules** as `core.modules.<module>.*`, **harnesses** as `core.harnesses.<id>.*` (from anywhere in the core, never from a plugin), the **framework** as `framework.*`.
- Every system part and module uses only the framework and its own code; it reaches another one through `hey::call`.
- An integration exposes only its `service.sh`; its `internal/` parts load from inside it alone.
- Migrations (`system/migrations/NNNN-<slug>.sh`, each with `DESCRIPTION` and `migrate()`) convert the files dotHey keeps when a new version changes their format; `state.migrations` lists those applied.
- Everything runs on bash 3.2+ with standard Unix tools.
