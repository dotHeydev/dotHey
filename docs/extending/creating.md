---
title: Creating a plugin
description: Scaffolding, installing, and iterating on a plugin locally.
order: 2
---

# Creating a plugin

```sh
bash hey plugins:new acme/widgets               # scaffolds ./widgets, one example of each part
bash hey plugins:add acme/widgets --from ./widgets
bash hey acme:hello dotHey                      # → ✓ Hello, dotHey!
```

`--from` installs from a local copy inside the project: as committed when it's a git repo, as it is on disk otherwise. Rerun `plugins:update acme/widgets` after each change.

```text
widgets/
└── dothey/
    ├── plugin.json
    ├── commands/        # <owner>:<command>
    ├── context/         # *.md appended to dotHey's docs
    ├── skills/          # linked into .agents/skills/
    ├── agents/          # linked into .agents/agents/
    └── stubs/           # <path>.stub appended to <path>
```
