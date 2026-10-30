---
title: Updating dotHey
description: Upgrading dotHey's core and your plugins.
order: 1
---

# Updating dotHey

```sh
bash hey upgrade                # upgrades in one step; offers bash hey link when the links need it
bash hey upgrade --link -y      # ...and relinks right after (options after --link are bash hey link's)
bash hey plugins:update --all   # plugins update on their own
```

- `upgrade` replaces `.hey/.core/` only; your context, records, and plugins are never touched.
- A file is deleted only when the installed version had it and the latest doesn't; one you edited is kept and listed.
- When a new version changes the format of a file dotHey keeps, `bash hey migrate` converts it. Until then, every other command asks for it first.
