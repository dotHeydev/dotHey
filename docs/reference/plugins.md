---
title: bash hey plugins:*
description: Every plugins command, with its usage, options, and examples.
order: 8
---

# bash hey plugins:*

## `plugins:add`

Add a plugin from a GitHub repo you trust.

```text
Installs the repo's dothey/ directory into .hey/.plugins/<owner>/<name>/,
after previewing every file and asking. Nothing gets linked: its links wait
in .hey/hey.json under "inactive" until you take them.

Usage:
  bash hey plugins:add <owner>/<name>[@<version>] [options]
  bash hey plugins:add <GitHub URL> [options]

Arguments:
  <owner>/<name>       The plugin's GitHub repo, as GitHub names it; dotHey
                       knows it by that name in lowercase, . and _ as -.
  @<version>           A branch, tag or commit (default: main).
  <GitHub URL>         The repo's address: https://github.com/<owner>/<name>,
                       .../tree/<version>, .../commit/<sha>, or its git@ form.

Options:
  --from <directory>   Optional. Install from a local copy inside the project,
                       to develop a plugin: as committed when it's a git repo,
                       else as is.
  --preview            Optional. Show what it would add, and stop; anyone may
                       run it, agents included. Also --dry-run.
  -y, --yes            Optional. Add without asking. It still needs a terminal.
  -h, --help           Show this help.

Examples:
  bash hey plugins:add acme/laravel
  bash hey plugins:add https://github.com/acme/laravel/tree/v2
  bash hey plugins:add acme/svelte@v1.0.0 --preview
  bash hey plugins:add acme/widgets --from ./widgets

Notes:
  - Plugins aren't vetted by anyone: only add one whose source you trust.
  - Its commands run as bash hey <owner>:<command>. A plugin whose owner is a
    dotHey command name, or whose commands are taken, is refused.
  - Private repos need gh signed in, or HEY_GH_TOKEN in .env.
  - Adding links nothing: its links wait under "inactive" in the links.
    Only the user takes them (bash hey plugins:link <owner>/<name>, which
    --preview shows first); never take them on their behalf.
  - Next: bash hey plugins:link <owner>/<name>.
```

## `plugins:link`

Link a plugin's waiting links, and make them active.

```text
Applies a plugin's links waiting under "inactive" in .hey/hey.json — only
those — after previewing them and asking, then moves them to active.
With no one at a terminal to ask, it only previews.

Usage:
  bash hey plugins:link <owner>/<name> [--overwrite] [--preview] [-y, --yes]

Arguments:
  <owner>/<name>       The plugin.

Options:
  --overwrite          Optional. Take new links over active ones (after a plugin
                       update), and replace destinations that already exist.
                       Also --force.
  --preview            Optional. Show the changes, and stop. Also --dry-run.
  -y, --yes            Optional. Apply without asking. Only at a terminal.
  -h, --help           Show this help.

Examples:
  bash hey plugins:link acme/widgets
  bash hey plugins:link acme/widgets --overwrite
```

## `plugins:list`

List the installed plugins.

```text
Lists each installed plugin with its source, version and commit.

Usage:
  bash hey plugins:list [--json]

Options:
  --json       Optional. [{"name", "origin", "ref", "commit"}].
  -h, --help   Show this help.
```

## `plugins:new`

Create a new plugin repo to build on.

```text
Creates a plugin repo with one example of each part, ready to fill and
publish as github.com/<owner>/<name>.

Usage:
  bash hey plugins:new <owner>/<name> [--into <directory>]

Arguments:
  <owner>/<name>       The plugin's future GitHub repo.

Options:
  --into <directory>   Optional. Where to create it, inside the project
                       (default: <name>). It must not exist yet.
  -h, --help           Show this help.

Examples:
  bash hey plugins:new acme/widgets
  bash hey plugins:new acme/widgets --into packages/widgets

Layout:
  Everything below lives under dothey/; the rest of the repo is yours.

  plugin.json   "requires" (plugin API 3), "description", "depends",
                "settings" (camelCase keys, with defaults), and its suggested
                "link" and "append" ({"<origin>": ["<destination>"]})
  commands/     <name>.sh, each with DESCRIPTION, usage() and handle()
  context/      *.md appended to dotHey's docs of the same name
  skills/       linked into .agents/skills/
  agents/       linked into .agents/agents/
  stubs/        <path>.stub appended to <path> in the project

Notes:
  - Try it with bash hey plugins:add <owner>/<name> --from ./<directory>.
  - Code may use framework.helpers.*, framework.console.* and
    framework.integrations.<name>.service, plus its own files.
  - Settings: hey::plugin_setting <key>. Secrets: hey::secret, named
    HEY_<OWNER>_<NAME>__<KEY> in .env.
```

## `plugins:remove`

Remove a plugin and everything it linked.

```text
Removes the plugin's files and lock entry, its links in .hey/hey.json,
everything it linked, and the sections it appended. Its settings, secrets and
records are listed for you to review.

Usage:
  bash hey plugins:remove <owner>/<name> [-y, --yes]

Arguments:
  <owner>/<name>   The plugin.

Options:
  -y, --yes        Optional. Remove without asking. It still needs a terminal.
  -h, --help       Show this help.

Examples:
  bash hey plugins:remove acme/widgets
```

## `plugins:unlink`

Take back a plugin's links, and set them aside.

```text
Takes back what a plugin's active links linked and appended — only those —
after previewing it and asking, then moves its links under "inactive" in
.hey/hey.json. With no one at a terminal to ask, it only previews.

Usage:
  bash hey plugins:unlink <owner>/<name> [--overwrite] [--preview] [-y, --yes]

Arguments:
  <owner>/<name>       The plugin.

Options:
  --overwrite          Optional. Replace the links already waiting under
                       "inactive". Also --force.
  --preview            Optional. Show the changes, and stop. Also --dry-run.
  -y, --yes            Optional. Apply without asking. Only at a terminal.
  -h, --help           Show this help.

Examples:
  bash hey plugins:unlink acme/widgets
  bash hey plugins:unlink acme/widgets --preview
```

## `plugins:update`

Update a plugin, after a review.

```text
Updates a plugin from where it was added, after previewing what changes and
asking. Its new links go under "inactive"; the active ones
stay as they are.

Usage:
  bash hey plugins:update <owner>/<name> [-y, --yes]
  bash hey plugins:update --all [-y, --yes]

Arguments:
  <owner>/<name>   The plugin.

Options:
  --all            Optional. Update every installed plugin, each reviewed in
                   turn.
  --preview        Optional. Show what it would change, and stop; anyone may run
                   it, agents included. Also --dry-run.
  -y, --yes        Optional. Update without asking. It still needs a terminal.
  -h, --help       Show this help.

Examples:
  bash hey plugins:update acme/widgets
  bash hey plugins:update --all
  bash hey plugins:update acme/widgets --preview

Notes:
  - Take the new links: bash hey plugins:link <owner>/<name> --overwrite.
```
