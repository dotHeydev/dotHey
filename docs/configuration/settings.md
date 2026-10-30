---
title: Settings
description: Every setting in .hey/hey.json, and where each value comes from.
order: 1
---

# Settings

Every setting lives in `.hey/hey.json`, nested by area. A value comes from there, else from dotHey's defaults (`.hey/.core/hey.defaults.json`, which lists every setting).

```json
{
  "featureFlags": { "release": true },
  "general": { "timezone": "Europe/Madrid" },
  "tasks":   { "service": "file", "githubRepo": "" },
  "plugins": { "unprefixedCommandOwners": ["acme"], "acme/widgets": { "apiUrl": "https://…" } },
  "links":   { "@hey:AGENTS.md": ["AGENTS.md"], "append": {}, "skip": {}, "inactive": {} },
  "release": { "destination": ".ignore/release", "branch": "main", "remotes": { "github": "https://github.com/<owner>/<repo>.git" } },
  "state":   { "version": "1.2.0", "commit": "<commit>", "isReady": true, "migrations": ["0001-<slug>"], "setup": { "harnesses": ["claude"], "type": "parallel", "pending": [], "done": ["context"] } }
}
```

| Setting | Meaning |
|---|---|
| `featureFlags.*` | [Feature flags](../configuration/feature-flags.md) |
| `general.timezone` | An IANA name or a fixed offset (`UTC+2`), for every date dotHey writes |
| `tasks.service`, `tasks.githubRepo` | Where tasks live; set by `bash hey tasks:initialize` |
| `plugins.unprefixedCommandOwners` | Plugin owners whose commands run without the `<owner>:` prefix |
| `plugins.denyLinkOrigin`, `plugins.denyLinkDestination` | What no plugin may link or append from, or to |
| `plugins["<owner>/<name>"]` | A plugin's own settings, written with their defaults when it's added |
| `links` | What `bash hey link` links and appends ([Linking](../configuration/linking.md)) |
| `release.*` | [Releases](../maintenance/releases.md) |
| `state.*` | dotHey's own, never a setting: the release installed (`version`, shown by `bash hey -v`) and its commit (what `bash hey upgrade` compares against), whether the context is ready, the migrations applied, and [setup](../getting-started/setup.md)'s record (`state.setup`: the harnesses chosen, the type, and what is left for the agent). dotHey writes it; it has no defaults and never reads from `.env` |
