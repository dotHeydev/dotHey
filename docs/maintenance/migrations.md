---
title: Migrations
description: How dotHey converts the files it keeps when a new release changes their format.
order: 2
---

# Migrations

When a release changes the format of a file dotHey keeps (`hey.json`, a record's frontmatter), it ships a migration that converts it. After an upgrade, every other command asks for it first:

```sh
bash hey migrate               # runs the pending migrations, in order, after asking
bash hey migrate -y            # without asking, at a terminal
```

`state.migrations` in `.hey/hey.json` lists the migrations already applied, so each runs once. `bash hey upgrade` runs `migrate` for you when one is pending.
