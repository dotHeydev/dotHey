---
title: Publishing
description: Shipping a plugin for others to add.
order: 12
---

# Publishing

1. Push the repo to `github.com/<owner>/<name>`, with the plugin in its `dothey/` directory.
2. Tag versions, so users can pin one: `bash hey plugins:add <owner>/<name>@v1.0.0`.
3. Keep `requires` in `plugin.json` in step with the plugin API you build against.

Private repos work too, for users with `gh` signed in or a `HEY_GH_TOKEN` that can read them.
