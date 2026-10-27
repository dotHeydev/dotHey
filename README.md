# dotdot

A model-agnostic distro for AI coding agents.

## Installation

1. From your project's root, run `curl -fsSL https://raw.githubusercontent.com/dotdot-sh/dotdot/main/install.sh | bash`

2. Tell your coding agent you're using dotdot: it will ask about your project and prepare dotdot's context from your answers (the `dot-ready` skill).

3. Start building!

The installer will create the `.dot/` directory and the handy `dot` command at your project root. Then it'll link the context with your harness.

## Objective

Define instructions, tools, and rules that help AI coding agents work in compliance with project requirements, organization policies, and personal user preferences.

## Core Principles

1. **Simplicity** — prefer the smallest set of instructions that achieves the goal.
2. **Reliability** — instructions must produce consistent agent behavior across sessions and models.
3. **Efficiency** — minimize the instructions, context, and steps an agent needs to do the right thing.

## Taxonomy

dotdot covers 3 categories that cover the basic elements of AI coding agent work:

- **Context**: The information the agent needs to understand the project, its goals, and its constraints (desitions, standards, rules, …).
- **Tools**: The tools available to help the agent work faster, more effectively, and reliably (skills, binaries, harness settings, …).
- **Work**: The specifications and operational artifacts that guide how the agent should work (ideas, feature specifications, plans, …).

Each category is present as contextual, instructional, and tooling artifacts: MD files, scripts, skills, specifications, plans, and templates.

## Rules

**dotdot is not a harness**, so it does not define or enforce a rules hierarchy on its own. It assumes you, your team, or your organization provisions a set of hierarchical shared instructions, and that dotdot's material lives beneath whatever rules your organization defines.

Since not all harnesses enforce rule hierarchies and contributors can edit dotdot locally, its content can fully drive agent behavior in practice. As a safeguard, dotdot directs agents to flag rule conflicts to the user rather than resolve them silently.

The list below is a recommended way to think about rules precedence, not one dotdot enforces. In order of precedence:

1. **Organization Policies**: Configurations and instructions defined by your organization and provisioned in your local system. Ideally read-only by you, fully enforced with top precedence by your agent.
2. **Project Guidelines** (dotdot): All information necessary to understand and work productively in the given project. Ideally agreed and committed by the team in the project repository.
3. **User Preferences**: Your individual user preferences for your local agents within this project. Ideally not tracked by your SCM tool and defined in the .dot/USER.md file.

## Delivery Model

dotdot is an opinionated starting point, not a long-term dependency. A one-time init step copies the `.dot/` directory into the parent project and symlinks dotdot sources into harness-specific instruction files (e.g. `CLAUDE.md`, `AGENTS.md`, `.claude/*`). From that point on, the project fully owns the result, and you're free to edit, extend, or remove any of it. It is recommended to track dotdot in your SCM.

## Settings

Every dotdot setting lives in `.dot/dot.json`, nested by domain, and is read through one helper, `dot::setting <path> [default]` (e.g. `tasks.githubRepo`), from dotdot's code and plugins' alike, as `env()` reads a variable in a dotenv library: text prints raw; a boolean, a number, a list, or an object prints as JSON (`framework.helpers.json::values "$value" '.[]'` lists one entry per line). An unset or empty setting prints the default when one is given, else stops with how to set it. A value comes from `.dot/dot.json` (a `null` counts as absent), else from `.dot/.core/dot.defaults.json`, dotdot's defaults, which list every setting and are replaced by `bash dot update`.

A plugin's own settings live in `.dot/dot.json` under `plugins["<owner>/<name>"]`. Adding or updating the plugin writes there each key its `plugin.json` `"settings"` declares and `dot.json` lacks, with its default; a key already there, yours, stays. Its code reads them with `dot::plugin_setting <key> [default]`, the same way, from `dot.json` only.

```json
{
  "general":  { "timezone": "@env:MY_TIMEZONE" },
  "tasks":    { "service": "file", "githubRepo": "" },
  "plugins":  { "unprefixedCommandOwners": ["acme"], "acme/widgets": { "apiUrl": "https://…" } },
  "links":    { "@dot:AGENTS.md": ["AGENTS.md"], "append": {}, "remove": {}, "inactive": {} },
  "release":  { "signingKey": "", "authorName": "", "authorEmail": "", "destination": ".ignore/release", "branch": "main",
                "remotes": { "github": "https://github.com/<owner>/<repo>.git" }, "exclude": [".dot/", "dot", "AGENTS.md"] },
  "state":    { "version": "<commit>", "isReady": true, "migrations": ["0001-<slug>"] }
}
```

- `general.timezone` — IANA name or a fixed offset like `UTC+2`, applied to every date dotdot writes.
- `tasks.service` (`file` or `github`) and `tasks.githubRepo` — set by `bash dot tasks:initialize`.
- `plugins.unprefixedCommandOwners` — plugin owners whose commands run without the `<owner>:` prefix; a command that collides with dotdot's or an earlier plugin's keeps its prefix.
- `plugins.<owner>/<name>.<key>` — a plugin's own settings, written with their defaults when it is added or updated.
- `plugins.denyLinkOrigin`, `plugins.denyLinkDestination` — what no plugin's links may link or append from or to: each entry an origin (`@plugin:acme.tools:*`) or a destination (`@dot:AGENTS.md`, `.claude/settings.json`), exact, a folder (ending in `/`), or a start (ending in `*`). Adding or updating a plugin reports any of its links they catch, and `bash dot link` leaves those out of its active group. Your own general links are never caught. dotdot's defaults protect the docs that steer every agent: `AGENTS.md`, `RULES.md`, `SECURITY.md`, and `USER.md`. dotdot itself always keeps links out of `.git/`, `.dot/`, the `.env`, and the `dot` entry point, whatever these say.
- `links` — what `bash dot link` links and appends (see below).
- `release.signingKey` — the private SSH key's file name in `~/.ssh/` (its `.pub` next to it) that signs release commits.
- `release.authorName`, `release.authorEmail` — the author of release commits; the email must belong to the account holding the signing key for GitHub to show "Verified".
- `release.destination` — the release repo's directory, from the project root.
- `release.branch` — the branch in the release repo.
- `release.remotes` — `{<name>: <https url>}`, at least one, each pushed with its own token (see Secrets). dotdot's default holds an example with `_USER_`/`_REPO_`, which is never used.
- `release.exclude` — paths left out of the release, from the project root; `"!<path>"` includes a git-ignored one, copied from disk.
- `state.version`, `state.isReady`, `state.migrations` — dotdot's own: the commit installed, whether the context is prepared, the migrations applied.

### Values from `.env`

Any string in `.dot/dot.json` written as `"@env:<KEY>"` (a whole value, a value inside an object, or an element of a list) is read from the host project's `.env` (at the project root; only the file is read, never the process environment), as `env()` does in any dotenv library, so each person can set it apart from the committed file:

```json
{ "general": { "timezone": "@env:MY_TIMEZONE" },
  "release": { "remotes": { "github": "@env:GITHUB_REMOTE" }, "exclude": "@env:RELEASE_EXCLUDE" } }
```

- `.env` holds plain strings; dotdot casts each by its syntax alone: `true` and `false` become booleans, a number (`12`, `-3`, `1.5`) a number, valid JSON in `[ ]` or `{ }` that list or object (`RELEASE_EXCLUDE=[".dot/", "dot", "!build"]`), `null` unset; anything else, or anything in quotes (`"12"`), is text.
- `.env` is read as dotenv libraries read it: the first line setting a key wins, `export` is allowed, a quoted value is taken as written between its quotes, and an unquoted one ends at a ` #` comment.
- A missing or commented-out `<KEY>` leaves a whole value unset, so the default applies, and a value inside one `null`.
- References belong in `.dot/dot.json` only: never in `dot.defaults.json` or a plugin's `plugin.json`, and dotdot never writes one itself.
- JSON only, refusing any reference in them: `links` and `state`.

### Secrets and reserved keys

Secrets live in the host project's `.env` alone, read with `dot::secret`, never through settings, so a missing one is never filled in from elsewhere. Their keys are reserved: no `"@env:"` reference may use one (`Invalid .env reference for general.timezone: the key DOT_GH_TOKEN is reserved, use a different one.`).

- `DOT_GH_TOKEN` — the GitHub token (see GitHub access).
- `DOT_RELEASE_TOKEN_<REMOTE>` — a release remote's token, `<REMOTE>` its name in `release.remotes` upper-cased with `-` as `_`; written encrypted by `bash dot release:token`, never by hand.
- `DOT_<OWNER>_<NAME>__<KEY>` — a plugin's secrets (any `DOT_` key holding `__`), each readable by that plugin alone.

Every other key, `DOT_`-prefixed or not, is free for references. dotdot stores a secret only while git ignores `.env`, never links or appends to it, and `bash dot release:create` refuses an export holding it or anything that looks like a token. Every line dotdot prints passes through one point, `framework.console.output`, which masks anything that looks like a token or a secret-named value (`API_KEY=F4k3******`), so not even an error message can show one.

## Supported Harnesses

What gets linked where is yours to decide in the `"links"` of `.dot/dot.json`, as JSON. By default it links `AGENTS.md` into the project root and each of dotdot's skills into `.claude/skills/`. Every plugin adds its links under `"inactive"`, for you to activate with `bash dot link:activate <owner>/<name>`. A harness plugin wires it into a coding agent, suggesting links for dotdot's and its own skills and agents into the harness's directories, and for the docs where the harness reads them:

- [x] Claude Code — `bash dot plugins:add dotdot-sh/claude-code` (source in this repo's `.ignore/claude-code/`)
- [ ] OpenCode
- [ ] Codex
- [ ] Copilot
- [ ] Cursor

## `dot` command

The `dot` at your project root is dotdot's handy command line. It gives you and your agents a straightforward way to manage common dotdot actions such as creating notes, features, decisions, and tasks, scanning docs, managing plugins, and linking or updating dotdot itself. Run `bash dot` to list the available commands, and pass `--help` to each to learn more about their usage.

> **Tip:** To run the command simply as `dot` instead of `bash dot`, consider adding `dot() { bash dot "$@"; }` to your shell.

Examples:
```sh
dot link                               # link what the links list into your harness, after adding or renaming skills
dot notes:create "Cache idea"          # a new note in .dot/Notes/
dot tasks:list                         # the project's tasks
```

## Plugins

dotdot ships with what it needs: notes, feature specifications, decisions, tasks, releases, and Claude Code settings are all part of its core. A plugin adds more, from any GitHub repo you choose: there is no catalog, and nobody vets plugins for you.

```sh
bash dot plugins:add acme/laravel           # github.com/acme/laravel, its dotdot/ folder
bash dot plugins:add acme/svelte@v1.0.0     # at a branch, tag, or commit
bash dot plugins:update --all               # every installed plugin, each reviewed again
bash dot plugins:remove acme/laravel
```

A plugin is code and instructions from its author. It can run anything on your machine and steer your agents, so every add and update shows a warning and the full list of what changes (scripts flagged), and goes ahead only when you confirm at a terminal; `--yes` skips the question but still needs a terminal, so no agent or script can add or update a plugin. dotdot never runs plugin code while adding it.

Only the repo's `dotdot/` folder is installed, into `.dot/.plugins/<owner>/<name>/`. Its commands run as `bash dot <owner>:<command>`, or without the prefix for an owner listed in the `plugins.unprefixedCommandOwners` setting (one whose name dotdot or an earlier plugin already has keeps its prefix, so dotdot's own are never overridden); a plugin whose owner is one of dotdot's own command names, or whose commands another plugin already has, is refused, each refusal says why. A skill or agent with the name of dotdot's or another plugin's is only reported (first come, first served), as is a link it suggests onto a destination you or another plugin link already, or one `plugins.denyLinkDestination` protects. Wherever two entries link one destination, `bash dot link` keeps the first declared (the general links before any plugin's, then the plugins' groups in their order) and reports the other.

Adding or updating a plugin links and appends nothing. dotdot writes its links into the map under `"inactive"` → `"<owner>/<name>"`, which is never applied. `bash dot link:activate <owner>/<name>` moves them into the plugin's own group, `"<owner>/<name>"`, placed right before `"inactive"`, and the next `bash dot link` applies them; `bash dot link:deactivate <owner>/<name>` moves the group back to the end of `"inactive"` (what it linked stays until removed or broken). An update rewrites only its inactive links; its active group stays, and `bash dot link:activate <owner>/<name> --replace-active` takes the new ones. Removing a plugin deletes its folder, drops its groups (active or not) and the entries taken from it, prunes its broken links, and removes what it appended to the files the links append to. What is left, its settings, secrets, and the directories holding its records, is listed for you to review and remove yourself.

```json
{
  "@dot:AGENTS.md": ["AGENTS.md", ".claude/CLAUDE.md"],
  "@dotdotSkills": [".claude/skills/"],
  "append": { "@dot:STANDARDS.md": ["docs/STANDARDS.md"] },
  "remove": { "@dot:RULES.md": ["old/rules.md"] },
  "acme/tools": {
    "@plugin:acme.tools:skills/*": [".agents/skills/"],
    "append": { "@plugin:acme.tools:context/STANDARDS.md": ["@dot:STANDARDS.md"] },
    "remove": {}
  },
  "inactive": {
    "acme/lint": { "@plugin:acme.lint:skills/*": [".agents/skills/"], "append": {} }
  }
}
```

- `"<origin>": [destinations]`: the general links, at the top. Each destination becomes a symlink to the origin.
- `"<owner>/<name>"`: a plugin's active group, with its links, `"append"` and `"remove"` in the same shape.
- `"inactive"`: each plugin's links as it suggests them, never applied until `bash dot link:activate` moves them into its group.
- When two entries link the same destination, the general links win over a plugin's, and otherwise the first declared wins; `bash dot link` reports each one left out (`Skipped acme/tools's link to .claude/CLAUDE.md: the general links already link it …; append to it instead if both are needed`).
- `"append"`: the origin's file is appended to each destination between `<!-- <owner>/<name> -->` markers (`dotdot` for its own files, `#` outside Markdown), creating the file when it is missing. Into Markdown it goes under a `---` rule and a `## <owner>/<name>` heading, with the origin's frontmatter description quoted below it (`> description: …`), then its body. A `.json` destination takes no markers, so it is only created when missing. Appends never collide: each owner keeps its own region in a file, so several append to the same one; only two entries of one owner into the same file are refused.
- `"remove"`: wins over the rest. A destination still linked to the origin is unlinked, and what the origin's plugin (or dotdot) appended there is removed, along with the file when that append created it and nothing else is left.
- Paths read the same everywhere dotdot takes one, in links and settings alike: `<path>` is that path; `<path>/` that folder (as a link destination, a single origin goes inside it under its own name); `<path>/*` everything inside the folder, one by one; and, in the deny lists only, `<start>*` anything starting with `<start>`.
- Origins: `@dot:<path>` (anything in `.dot/`), `@module:<name>:<path>`, `@plugin:<owner>.<name>:<path>`, `@dotdotSkills` / `@dotdotAgents`, and `@pluginsSkills` / `@pluginsAgents`. A `/*` ending takes each entry inside one by one.
- Destinations: project paths outside `.dot/` and `.git/`, never `.env`. Appends may also go to `@dot:<Doc>.md`.
- An origin appears once per group: JSON keeps only the last of duplicate keys, so give one origin all its destinations (`"@dot:AGENTS.md": ["AGENTS.md", ".claude/CLAUDE.md"]`).
- Until the settings have links, dotdot's default stands in, and the first `bash dot link` writes it in. A settings file that doesn't parse is refused, never overwritten.
- dotdot edits only what it changes (a plugin's inactive links, an activated group, the entries of a removed plugin) and leaves the rest of the file as you wrote it. New links are written in jq's default layout.

### GitHub access

Everything dotdot does on GitHub (plugin downloads, tasks kept as issues) goes through one service, `framework.integrations.github.service`, which picks the route:

1. `gh`, as your logged-in account, or, with `DOT_GH_TOKEN` set in the project's git-ignored `.env`, as that token's owner. A token always takes precedence over the login, for this project only; dotdot hands it to each `gh` call alone, so your shell's `gh` is unaffected.
2. When `gh` is missing or fails and `DOT_GH_TOKEN` is set, GitHub's API with the same token. It never falls back to the login once a token is set.
3. When every route fails, one error names each attempt, why it failed (not found or no access, not authorized, rate-limited, no connection), and what to do: `gh auth login`, set `DOT_GH_TOKEN`, renew it, or check access.

A plugin download tries GitHub's public archive first, which needs no one, then the routes above, for private repos. The token's scopes limit what dotdot can do (private repos need read access, tasks need issues, labels need write access). It covers github.com only. Releases don't use it: each remote pushes with its own token (see `bash dot release:token --help`).

### Writing a plugin

`bash dot plugins:new <owner>/<name>` scaffolds a repo. Everything dotdot installs lives in its `dotdot/` folder; the rest of the repo is yours:

- `dotdot/plugin.json` — `"description"`, the one key it must have, then, each optional and refused only when malformed: `"requires"` (the plugin API, 3; a plugin needing another one is refused), `"depends"` (a list of binaries or `framework.integrations.<name>`, reported but never installed), `"settings"` (its own settings with their defaults, camelCase keys, never `"@env:"`; written into `.dot/dot.json` when it is added or updated, see Settings), and its suggestions for the links:
  - `"link"` and `"append"` are `{origin: [destinations]}`, as in the links. An origin is one of:
    - a path in the plugin, written into the links as `@plugin:<owner>.<name>:<path>`;
    - the plugin's own `@plugin:<owner>.<name>:<path>`;
    - `@dot:<Doc>.md`, one of dotdot's top-level docs;
    - `@dotdotSkills` / `@dotdotAgents`, dotdot's own skills and agents, for a harness plugin.

    Nothing else is allowed (no other plugin, no module, no `@pluginsSkills`). Link destinations are project paths outside `.dot/` and `.git/`, never `.env`. Append destinations may also be `@dot:<Doc>.md`; one `plugins.denyLinkDestination` protects (by default `AGENTS.md`, `RULES.md`, `SECURITY.md`, `USER.md`) is reported and never applied.
- `dotdot/commands/*.sh` — commands, run as `bash dot <owner>:<command>` (`commands/db/seed.sh` is `<owner>:db:seed`).
- `dotdot/context/*.md` — suggested for appending to the dotdot doc of the same name, which the append creates when dotdot has none.
- `dotdot/skills/`, `dotdot/agents/` — suggested for linking into `.agents/skills/` and `.agents/agents/`. Any name the skills standard allows; one that clashes with dotdot's or another plugin's is reported, and wherever both are linked the first declared wins.
- `dotdot/stubs/<path>.stub` — suggested for appending to `<path>` in the project.
- dotdot suggests what it finds in `skills/`, `agents/`, `context/`, and `stubs/` only for a folder `plugin.json` doesn't place itself: once any `"link"` or `"append"` origin lies in a folder (`"skills/acme-review": [".claude/skills/acme-review"]`), that folder's default suggestions are left out, and only what `plugin.json` declares is suggested for it. The other folders are still found.
- Anything else, organized as you like, loaded with `dot::use plugins.<owner>.<name>.<path>`.

Try it locally with `bash dot plugins:add <owner>/<name> --from ./<repo-directory>`, then publish it as `github.com/<owner>/<name>`.

A command declares a `DESCRIPTION`, a `usage` function for its `--help`, and a `handle` function that receives the arguments:

```bash
#!/usr/bin/env bash

DESCRIPTION="Seed the database."

dot::use framework.console.args framework.console.output

usage() {
  framework.console.output::line "bash dot $DOT_COMMAND [--fresh]"
}

handle() {
  [ $# -le 1 ] || framework.console.args::unexpected "$2"
  framework.console.output::success "Seeded."
}
```

Plugin code may use, and only use:

- `dot::use`, `dot::path project|dotdot|plugin`, `dot::setting <path> [default]` (dotdot's settings, read only; see Settings), `dot::plugin_setting <key> [default]` and `dot::save_plugin_setting <key> <json>` (its own, in `.dot/dot.json`), `dot::secret` / `dot::save_secret` / `dot::remove_secret` (its own, named `DOT_<OWNER>_<NAME>__…`), `dot::relative`, `dot::call`, `dot::raise`, `dot::abort`, `dot::on_exit`.
- `framework.helpers.*` — `fs`, `text`, `kv`, `date`, `frontmatter`, `template`, `record`, `json`, `net`, `emoji`, `secrets`.
- `framework.console.*` — `output`, `prompt`, `terminal`, `args`.
- `framework.integrations.<name>.service` — `github`.
- its own `plugins.<owner>.<name>.*`.

`dot::use` refuses anything else (dotdot's `core.*` modules, any `internal` part of a framework module, another plugin), and every function is named after its module: `framework.console.output::success`, `plugins.acme.laravel.db::seed`.

## Structure

- `.dot/*.md` and `.dot/Features/`, `Decisions/`, `Tasks/`, `Notes/` — the project's context and records, owned by the project.
- `.dot/dot.json` — the project's settings (see Settings), including the links: every link, append and removal `bash dot link` makes, written from dotdot's default at install. Each plugin's links sit under `"links"` → `"inactive"` until `bash dot link:activate` moves them into its group: written when it is added or updated, and dropped with its group by the first `bash dot link` after it is removed. Edit it freely; `bash dot link --refresh-plugin <owner>/<name>` rewrites a plugin's inactive links.
- `.dot/.core/` — dotdot itself, refreshed by `bash dot update`:
  - `system/` — what dotdot needs to run: `bin/dot`, `boot.sh` (module loading and the `dot::` API, the only API plugins may use), `kernel.sh` (the command registry, listing, and dispatch; it stops every command but `migrate` and `update` while a migration is pending), `paths.sh`, `guards.sh` (the policy every action is checked against: where links and appends may go, what plugins may declare, which settings and secrets code may touch, when `-y` may skip a confirmation), and `plugins`, `link`, `update`, `migrations` (one file per migration, `migrations/NNNN-<slug>.sh`, each with `DESCRIPTION` and `migrate()`, run in order by `bash dot migrate`; `state.migrations` lists those applied, and the installer lists every one), loaded as `core.system.<part>.*`.
  - `modules/` — what dotdot can do: `onboarding`, `ready`, `frontmatter`, `housekeeping`, `notes`, `features`, `decisions`, `tasks`, `release`, each with its commands and skills, loaded as `core.modules.<module>.*`.
  - `framework/` — the only shared code, loaded as `framework.*` by the system, the modules, and plugins alike: `helpers/` (project-agnostic building blocks), `console/` (command-line input and output), and `integrations/` (external services, each exposing only `service.sh`; its `internal/` parts load only from inside that integration).
  - `dot.defaults.json` — dotdot's default settings.
  - Every system part and module loads only from inside its own folder.
- `.dot/.plugins/<owner>/<name>/` — installed plugins, with `plugins-lock.json` (each plugin's id, origin, ref, and commit, in the order they were added: the ref `plugins:update` fetches again, and the commit installed, so an update knows when it is up to date; a local plugin that is a git repo of its own is recorded as a GitHub one is, any other local folder with `-` for both). A plugin writes nothing outside its folder; everything else is a suggestion in the links that only you can take.

Every guard is a predicate in `.core/system/guards.sh`, called where dotdot acts. At boot, dotdot's own functions (and its modules' as they load) and the variables that say where things are become read-only, so no plugin or edited file can switch a guard off during a run. That protects what dotdot does, not what a plugin's own code does: a plugin runs with your permissions, so the trust decision at `plugins:add` stays the real boundary.

Everything runs on bash 3.2+ with standard Unix tools (macOS included).

## Agents Brevity Flags

Agents are instructed to reply concisely by settings, however, you can also add a flag to your prompt to adjust its output mode for that specific reply:

- `--short` / `--s`: the concise answers.
- `--expand` / `--xp`: a little more detail than usual, while the default remains unchanged.
