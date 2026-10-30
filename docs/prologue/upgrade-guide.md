---
title: Upgrade guide
description: What to do when you move from one dotHey release to the next.
order: 3
---

# Upgrade guide

Upgrading is one command, and most releases need nothing more:

```sh
bash hey upgrade
```

It replaces `.hey/.core/` only, so your context, records, and plugins stay as they are. When a release changes the format of a file dotHey keeps, `bash hey migrate` converts it, and every other command asks for it first. See [Updating dotHey](../maintenance/updating.md) and [Migrations](../maintenance/migrations.md) for the details.

A release that asks anything more of you lists it here, under its version.
