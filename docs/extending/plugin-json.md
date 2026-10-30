---
title: plugin.json
description: The plugin manifest: description, requirements, settings, and suggested links.
order: 3
---

# plugin.json

```json
{
  "requires": 3,
  "description": "Widgets for Acme projects.",
  "depends": ["jq", "framework.integrations.github"],
  "settings": { "apiUrl": "https://widgets.acme.test", "strict": false },
  "link": { "skills/acme-review": [".claude/skills/acme-review"] },
  "append": { "context/STANDARDS.md": ["@hey:STANDARDS.md"] }
}
```

| Key | Meaning |
|---|---|
| `description` | **Required.** One line, shown wherever the plugin is listed |
| `requires` | The plugin API it's built for (currently `3`); a mismatch is refused |
| `depends` | Binaries or `framework.integrations.<name>` it needs; reported, never installed |
| `settings` | Its own settings with their defaults, camelCase keys, never `"@env:"` |
| `link`, `append` | Its suggested links and appends, as `{"<origin>": ["<destination>"]}` |

**Origins** in `link` and `append`:

- A path in the plugin, written into the links as `@plugin:<owner>.<name>:<path>`.
- `@hey:<Doc>.md`, one of dotHey's top-level docs.
- `@dotheySkills`, `@dotheyAgents`: dotHey's own skills and agents, for a harness plugin.

**Destinations:**

- Links go to project paths outside `.hey/` and `.git/`, never `.env`.
- Appends may also go to `@hey:<Doc>.md`.
- A destination protected by `plugins.denyLinkDestination` is reported and never applied.

> [!NOTE]
> For each of `skills/`, `agents/`, `context/`, and `stubs/`, dotHey suggests what it finds there, unless `plugin.json` places something from that directory itself. Once it does, only what `plugin.json` declares is suggested for that directory.
