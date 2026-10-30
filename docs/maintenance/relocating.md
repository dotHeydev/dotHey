---
title: Relocating
description: Moving dotHey to another folder of the project.
order: 3
---

# Relocating

`bash hey relocate .agents/.hey` moves all of dotHey into the project's `.agents/` folder: it points `hey` at the new place, rewrites the paths in dotHey's files, and relinks everything. Setup offers it when the project has `.agents/`, and the installer takes `--dir .agents/.hey` to install there directly.
