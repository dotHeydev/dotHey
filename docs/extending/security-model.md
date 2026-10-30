---
title: Security model
description: The guards dotHey enforces, and where your trust decision stays.
order: 11
---

# Security model

- **Every guard is a predicate in `guards.sh`**, called where dotHey acts: where links and appends may go, what plugins may declare, which settings and secrets code may touch, when `-y` may skip a confirmation.
- **At boot, dotHey's functions and its path variables become read-only**, so no plugin or edited file can switch a guard off during a run.
- **dotHey never runs plugin code while adding it**, and refuses archives with paths outside the plugin, symlinks, or stubs for `.git/`.
- **Changes need a person:** adding, updating, and removing plugins, linking, and migrating all ask at a terminal, so no agent or script can approve them.
- **Secrets never surface:** they're read from `.env` alone, every printed line is masked, and releases refuse to ship anything that looks like one.

> [!CAUTION]
> These guards protect what *dotHey* does, not what a plugin's own code does: a plugin runs with your permissions. Deciding whom to trust at `plugins:add` stays the real boundary.
