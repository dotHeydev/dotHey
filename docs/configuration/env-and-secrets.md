---
title: Values from .env and secrets
description: Reading settings from .env, and where secrets live.
order: 4
---

# Values from .env and secrets

## Values from `.env`

Any string in `hey.json` written as `"@env:<KEY>"` is read from the project's `.env`, so each person can set it apart from the committed file:

```json
{ "general": { "timezone": "@env:MY_TIMEZONE" },
  "release": { "exclude": "@env:RELEASE_EXCLUDE" } }
```

- `.env` is read the way dotenv libraries read it (the first line setting a key wins, `export` is allowed, quotes keep a value as written), and only the file is read, never the process environment.
- Values are cast by their syntax: `true`/`false`, numbers, JSON lists and objects (`RELEASE_EXCLUDE=[".hey/", "hey"]`), and `null` (unset). Anything else, or anything quoted, is text.
- A missing key leaves the value unset, so the default applies.
- References belong in `hey.json` only, and never in `links` or `state`.

## Secrets

Secrets live in the project's git-ignored `.env` alone, never in settings. Their keys are reserved, so no `"@env:"` reference can read one.

| Key | Holds |
|---|---|
| `HEY_GH_TOKEN` | The GitHub token ([GitHub access](../configuration/github-access.md)) |
| `HEY_RELEASE_TOKEN_<REMOTE>` | A release remote's token, encrypted by `bash hey release:token` |
| `HEY_<OWNER>_<NAME>__<KEY>` | A plugin's secrets, readable by that plugin alone |

dotHey stores a secret only while git ignores `.env`, never links or appends to it, and masks anything that looks like a secret in everything it prints.
