---
title: Feature flags
description: Turning optional modules on and off.
order: 2
---

# Feature flags

Some of dotHey's modules are off until you turn their flag on in `.hey/hey.json`. A module that's off is off entirely: it lists no commands, running one stops with how to turn it on, and `bash hey link` neither links nor appends anything from it, removing what it linked before. Its command and skill names stay reserved, so no plugin takes them while it's off.

```json
{ "featureFlags": { "release": true } }
```

| Flag | Turns on |
|---|---|
| `featureFlags.release` | [Releases](../maintenance/releases.md) |
