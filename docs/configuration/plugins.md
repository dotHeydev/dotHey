---
title: Using plugins
description: Adding, linking, updating, and removing plugins, and what they may touch.
order: 6
---

# Using plugins

dotHey ships with everything it needs. A plugin adds more, from any GitHub repo you choose: there's no catalog, and nobody vets plugins for you.

```sh
bash hey plugins:add acme/laravel                 # github.com/acme/laravel
bash hey plugins:add acme/svelte@v1.0.0           # at a branch, tag, or commit
bash hey plugins:add https://github.com/acme/svelte/tree/v1.0.0   # or by its URL
bash hey plugins:link acme/laravel               # take its suggested links
bash hey link                                     # and apply them
bash hey plugins:update acme/laravel              # or --all
bash hey plugins:remove acme/laravel
```

> [!WARNING]
> A plugin is code and instructions from its author: once added, it can run anything on your machine and steer your agents. Every add and update previews each file (scripts flagged) and goes ahead only when you confirm at a terminal.

- **Adding links nothing.** A plugin's suggested links go under `"inactive"` in `.hey/hey.json`; `bash hey plugins:link <owner>/<name>` links them (only them), and `plugins:unlink` takes them back.
- **Updating** rewrites only its inactive links. `plugins:link <owner>/<name> --overwrite` takes the new ones.
- **Removing** takes back everything it linked and appended, and its settings in `.hey/hey.json`. What's left (its secrets in `.env`, and the records it made) is listed for you to review.
- **Its commands** run as `bash hey <owner>:<command>`, or bare for an owner listed in `plugins.unprefixedCommandOwners`. dotHey's own commands are never overridden.
- **Protected destinations** (`plugins.denyLinkDestination`; by default `AGENTS.md`, `GUIDELINES.md`, `RULES.md`, `SECURITY.md`, `USER.md`) are never touched by a plugin's links.
