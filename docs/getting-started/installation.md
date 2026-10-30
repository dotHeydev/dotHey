---
title: Installation
description: Installing dotHey into a project.
order: 1
---

# Installation

dotHey runs on bash 3.2+ with standard Unix tools, macOS included. From your project's root:

```sh
curl -fsSL https://raw.githubusercontent.com/dotHeydev/dotHey/main/install.sh | bash
```

Rather read it first? Download `install.sh`, read it, then run `bash install.sh`.

The installer creates `.hey/` and the `hey` command at the root, then hands over to [setup](setup.md), which asks a few questions and links dotHey where your harnesses read it. With no one at a terminal, it links only `AGENTS.md`, so any agent finds dotHey, and names the setup command to run later.

To install somewhere other than `.hey/`, pass `--dir`, as in `--dir .agents/.hey` (see [Relocating](../maintenance/relocating.md)).

Next: [set up your harnesses](setup.md).
