# Using dotdot

Everything you need to build with dotdot day to day. To extend it, see [Extending dotdot](plugins.md).

- [Concepts](#concepts)
- [Working with agents](#working-with-agents)
- [Records](#records)
- [The `dot` command](#the-dot-command)
- [Setting up](#setting-up)
- [Linking](#linking)
- [Using plugins](#using-plugins)
- [Settings](#settings)
- [Values from `.env`](#values-from-env)
- [Secrets](#secrets)
- [GitHub access](#github-access)
- [Releases](#releases)
- [Updating dotdot](#updating-dotdot)
- [Project layout](#project-layout)

---

## Concepts

### Context, tools, and work

dotdot covers the three things an agent needs to work well:

- **Context:** what the agent must know about the project: product, rules, security, standards, stack, data model, design, nomenclature. One Markdown file per concern, at the top of `.dot/`.
- **Tools:** what helps it work faster and reliably: skills, the `dot` command, harness settings.
- **Work:** the artifacts that guide the work: feature specifications, plans, decisions, tasks, notes, and xrays.

Each context file declares a `description` in its frontmatter saying when to read it, so agents survey them cheaply (`bash dot frontmatter:show .dot/`) and open in full only what a task needs.

### Rules precedence

**dotdot is not a harness**, so it doesn't enforce a hierarchy of rules on its own. It assumes your organization provisions its own policies, and that dotdot sits beneath them. When rules conflict, agents are told to flag the conflict, never to resolve it silently.

The recommended precedence, highest first:

1. **Organization policies.** Provisioned on your system by your organization; ideally read-only for you.
2. **Project guidelines** (dotdot). Agreed by the team and committed with the project.
3. **User preferences.** Yours alone, in `.dot/USER.md`, ideally not committed.

### Who owns what

dotdot is a starting point, not a dependency. The installer copies `.dot/` into your project and links its sources where your harness reads them (`AGENTS.md`, `.claude/`, and so on). From then on the project owns the result: edit, extend, or remove anything, and commit `.dot/` with your code.

Only `.dot/.core/` belongs to dotdot: `bash dot upgrade` replaces it, and leaves your context, records, and plugins alone.

---

## Working with agents

### Onboarding

Every session starts with the `dot-onboard` skill (agents run it when you say *"hey"*, after a context compaction, or as a fresh subagent). It walks the agent through the project, its rules, where the context lives, and the tools at hand.

If `.dot/dot.json` says the context isn't ready yet (`state.isReady`), the agent offers to run `dot-ready`, which turns your answers into the context files.

### The feature workflow

Features go through four stages, each written down before the next begins:

| Stage | Skill | Result |
|---|---|---|
| 1. Specify | `dot-document-feature` | `.dot/Features/fNNN--slug.md`, its specification in Given/When/Then |
| 2. Plan | `dot-draft-feature-plan` | An implementation plan in that same file |
| 3. Test | `dot-write-feature-tests` | Tests derived from the specification, failing before any code exists |
| 4. Build | `dot-implement-feature` | Code written against those tests, one at a time |

`dot-build-full-feature` chains all four and enters wherever the work actually is. The order is the point: the specification is what the tests come from, and the failing tests are what say the work is done.

### Skills

| Skill | What it does |
|---|---|
| `dot-onboard` | Onboards the agent to the project |
| `dot-ready` | Prepares the context from what you tell it |
| `dot-document-feature`, `dot-draft-feature-plan`, `dot-write-feature-tests`, `dot-implement-feature`, `dot-build-full-feature` | The feature workflow |
| `dot-document-decision` | Turns a settled question into a decision |
| `dot-create-task` | Turns a piece of work into a task |
| `dot-xray` | Holds a long discussion in a file |
| `dot-housekeeping` | Realigns docs, decisions, tests, and code |
| `dot-tools` | Points agents at `bash dot` for every dotdot operation, and at each command's `--help --json` |

### Reply flags

Agents reply concisely by default. Add a flag to your message to change that one reply:

- `--short` / `--s`: the bare minimum: the outcome and blockers.
- `--expand` / `--xp`: a little more detail than usual.
- `--xray` / `--x`: answer in an xray file instead of the chat, or move the conversation into one.
- `--chat`: bring an xray's open questions back into the chat.

### Agent mode

When an AI agent runs `bash dot`, output turns plain: no colors, highlighting, or spinner, nothing ever prompts (even in a terminal), and anything that needs a person asks the agent to hand it over. It switches on by itself when `AI_AGENT` or `CLAUDECODE=1` is set, or with `--agent` on any command. `--no-input` (automatic under `CI`) does the same for scripts.

Commands that change what you'd want to review (linking, plugins, migrations, deletions) always need a confirmation by a person at a terminal; `bash dot upgrade` doesn't, so it can run unattended. `-y` skips the question but still needs one, so no agent can approve a change for you; `--preview` shows any of those changes to anyone, agents included.

---

## Records

Records are the project's numbered documents, each in its own directory of `.dot/`, each created by a command that picks the next number and the file name for you.

| Record | Directory | Created with |
|---|---|---|
| Feature | `Features/fNNN--slug.md` | `bash dot features:create` |
| Decision | `Decisions/dNNN--slug.md` | `bash dot decisions:create` |
| Note | `Notes/nNNN--slug.md` | `bash dot notes:create` |
| Xray | `Xrays/xNNN--slug.md` | `bash dot xrays:create` |
| Task | `Tasks/tNNN--slug.md`, or GitHub issues | `bash dot tasks:create` |

### Features

A feature is a specification: what to build, its constraints, the decisions it relies on, and, once planned, how to build it. The template's sections become flags:

```sh
bash dot features:create "Password reset" \
  --description "Lets a user reset a forgotten password by email." \
  --specification "Given a registered user… When… Then…" \
  --related-features 7
```

### Decisions

A decision is a rule the project has settled, written as one first-person sentence anyone can obey: *"We keep the session JWT in an httpOnly cookie."* Decisions link the ones that shaped them and the features they affect, and dotdot keeps those links honest.

```sh
bash dot decisions:create "JWT in httpOnly cookie" \
  --statement "We keep the session JWT in an httpOnly cookie." \
  --explanation "Every authenticated response sets it as one." \
  --status accepted --influenced-by 002 --impacts 7

bash dot decisions:impact 002,005                  # the features citing these decisions
bash dot decisions:impact --term session,jwt       # the docs mentioning these terms
bash dot decisions:citers 004                      # the decisions pointing at 004
bash dot decisions:update 002 --status superseded --by 007
bash dot decisions:check                           # every link between decisions resolves
```

### Notes

A note parks an idea for later, with no commitment. Without a name it gets a random one, like `swift-otter`.

```sh
bash dot notes:create "Cache idea"
```

### Xrays

An xray is a discussion held in a file instead of the chat: topics, questions, propositions with the recommended one first, and a discussion broken down **one point per line**, so you can answer any point on its own. Agents open one when a topic is too big for the chat, or when you add `--x` to a message.

```markdown
## I. ⚠️ Caching

### 1. Where should we cache rendered pages?

**Propositions:**

- [ ] A — At the edge (recommended)
- [ ] B — In the app

**Discussion:**

1. 🤖 The edge keeps origin load flat during spikes.
2. 🤖 🛎️ Do we need per-user pages cached too?
   1. Only for logged-out users.

**Outcome:** A, logged-out pages only → [d012](../Decisions/d012--edge-cache.md)
```

- 🤖 marks the agent's points; yours have no mark.
- 🛎️ asks the other side for a reply.
- `[ ]` tracks what's to action; `[x]` what's done.
- Refer to a point as `I1--2.1`, or `x004 I1--2.1` from elsewhere.

The agent replies in the chat with the file's path only, answers in place, and can bring the open questions back into the chat (`--chat`) when you're away from an editor.

### Tasks

Tasks live in the service you choose with `bash dot tasks:initialize`: plain files in `.dot/Tasks/`, or GitHub issues labelled `task`. Every `tasks:*` command works the same either way.

```sh
bash dot tasks:create "Throttle failed logins" --description "Brute-force attempts aren't throttled."
bash dot tasks:list --status todo,doing --sort updated --order desc
bash dot tasks:doing t004
bash dot tasks:update t004 --done-when "- [x] lock after 5" --status done
```

---

## The `dot` command

`dot` at your project root is the one entry point for you and your agents. Run `bash dot` for the list, and `--help` on any command for its usage, options, and examples.

| Area | Commands |
|---|---|
| dotdot itself | `link`, `upgrade`, `migrate`, `version` |
| Links | `plugins:link`, `plugins:unlink` |
| Plugins | `plugins:add`, `plugins:update`, `plugins:remove`, `plugins:list`, `plugins:new` |
| Records | `features:create`, `decisions:create`, `decisions:update`, `decisions:impact`, `decisions:citers`, `decisions:check`, `notes:create`, `xrays:create`, `frontmatter:show` |
| Tasks | `tasks:initialize`, `tasks:create`, `tasks:update`, `tasks:get`, `tasks:list`, `tasks:delete`, `tasks:todo`, `tasks:doing`, `tasks:paused`, `tasks:done`, `tasks:discarded` |
| Releases | `release:create`, `release:push`, `release:token`, `release:token:delete` |

Every command follows the same conventions:

- What it acts on is a parameter (`<id>`, `<owner>/<name>`, `<version>`); how it acts is a flag.
- Flags take their value after a space or an `=`: `--status done` or `--status=done`.
- Common flags have short forms: `-y, --yes`, `-v, --verbose`, `-s, --status`, `-l, --limit`, `-p, --page`, `-h, --help`; `bash dot -v` is the version: the release (`dotdot 1.2.0`, `state.version`, written by the release that shipped it), with the installed commit too under `--json`.
- What changes things can be looked at first with `--preview` (also `--dry-run`); `--overwrite` (also `--force`) replaces what's already there.
- At a terminal, a missing required value is asked for, then the full command is shown to reuse; without one, it fails naming the flag.
- Data commands take `--json`: the result alone on stdout; on stderr, one JSON object per line for everything else, an error as `{"error": {"code", "exitCode", "message", "run", "next"}}`, and a warning, notice, or next step as `{"warning" | "notice" | "next": {"message", "run"}}` (`run`: the dotdot command it names, or `null`). `bash dot --json` lists the commands, and `bash dot help <command> --json` describes one; both hold everything their help page says (`about`, `usage`, `arguments`, `options`, `notes`, `examples`, and any other section under `sections`).
- Exit statuses: `0` success (an empty result too), `1` failure (or problems found, for `decisions:check`), `2` wrong usage, `4` not found, `5` needs something first (a person at a terminal, a clean tree…), `130` interrupted.
- A mistyped command suggests the closest one; a wrong argument shows the usage line and where the help is. Each help ends with a link to these docs.

---

## Setting up

The installer places dotdot, then hands over to `bash dot setup`, which puts dotdot where your harnesses read it, out of the box, for Amp, Antigravity, Claude Code, Codex, Cursor, Factory Droid, GitHub Copilot, Grok Build, Junie, Kiro, OpenCode, Pi, Zed, and `.agents/`. With no one at a terminal, the installer links only `AGENTS.md`, so any agent finds dotdot, and names the setup command.

```sh
curl -fsSL https://raw.githubusercontent.com/dotdot-sh/dotdot/main/install.sh | bash      # install, then set up
curl … | bash -s -- --harness claude,cursor --type parallel --yes                           # install and set up
bash dot setup                                       # look, ask, show the plan, apply
bash dot setup --harness claude --type centralize --preview
bash dot adopt --scan --json                         # what the project already holds
```

Setup first looks through the project ("Getting dotdot ready for your project…"): what each harness already holds (instructions, skills, agents, rules; `adopt --scan` also lists other top-level docs as *unsure*, for `dot-ready` to raise with you). Then it asks its questions, numbered (1/4), only those that apply: which harnesses to link, the detected ones checked; what happens to existing skills and agents, when there are any; and where dotdot lives, when `.agents/` holds more than skills or is linked into. It shows the plan, condensed by what changes in your project and in dotdot, and applies it once you agree, as a list of steps ticking off. Esc, q, or Ctrl-C stops at any question, changing nothing.

- **In parallel** (`--type parallel`, the default): they stay where they are, and dotdot's are linked beside them.
- **Centralize** (`--type centralize`): they move into `.dot/Skills/` and `.dot/Agents/` and are linked back into every chosen harness, so they're edited in `.dot/` from then on. An agent in a harness's own format is taken into dotdot's (Codex's TOML becomes Markdown). The same item in several harnesses moves once, its identical copies replaced by links; a copy that differs, a name dotdot already uses, a link leading elsewhere, or a file that can't be read as an agent is left in place.

A harness that reads only one instructions file gets dotdot in that one: Zed reads the first of `.rules`, `.cursorrules`, `.windsurfrules`, `.clinerules`, `.github/copilot-instructions.md`, `AGENT.md`, and `AGENTS.md`, and Junie reads `.junie/AGENTS.md` before `AGENTS.md`, so when the project has an earlier one, dotdot's `AGENTS.md` is appended to it.

> **Tip:** some harnesses also read other tools' folders (Cursor reads `.claude/agents/`, GitHub Copilot and Amp read `.claude/skills/` and `CLAUDE.md`, ...). Choose them together with Claude Code and they may show dotdot's skills, agents, or instructions twice. That's harmless; if it bothers you, link only the harnesses you use.

A harness's own instructions file is never replaced: dotdot appends an import of `AGENTS.md` in that harness's syntax, or links `AGENTS.md` where the harness reads one. Claude Code skips `AGENTS.md` whenever a `CLAUDE.md` exists (and some sessions can't read it at all), so it always gets a `CLAUDE.md` importing the root `AGENTS.md` (`@AGENTS.md`): appended to the first of `CLAUDE.md` and `.claude/CLAUDE.md` that exists, or a new `CLAUDE.md` when there's none. Setup changes only the harnesses' rows in the [links](#the-links) (what a harness's data describes) and lets `bash dot link` do the linking, so everything is previewed, backed up, and reversible; your own rows and your skips stay as they are. Run it again to change the choice: harnesses no longer chosen lose their rows, and link removes what those linked. It records the choice in dotdot's state (`state.setup.harnesses` and `state.setup.type` in `.dot/dot.json`), and what only your agent can finish in `state.setup.pending`: the context, with centralize the split of your instruction files and a check that every harness reads what moved, and any unsure docs to ask you about. While it applies the choice, `state.setup.pending` holds `apply`: a setup stopped halfway shows it, and running setup again finishes it. Your agent picks it up at its next session, confirms with you once, finishes it, and marks each item with `bash dot setup:done <item>`; the default setup leaves it only the context.

| Flag | Meaning |
|---|---|
| `--harness <a,b>` | The harnesses to link; without it, a terminal asks |
| `--type parallel\|centralize` | What happens to the project's own skills and agents |
| `--dir <path>` | Where dotdot lives afterwards ([Relocating](#relocating)) |
| `--preview`, `-y` | Show only, or apply without asking (at a terminal) |

Each harness is a folder in `.dot/.core/harnesses/<id>/`: `harness.json` keeps three things apart: `detect`, what tells for sure the harness is in use: its own folders and files only (`.claude/`, `CLAUDE.md`, `.zed/`, `.rules`, `.agents/mcp_config.json` for Antigravity), never a place several harnesses read, like `AGENTS.md` or `.agents/skills/`, and never a folder holding only dotdot's links, so only those are checked from the start; where dotdot links what it brings (`skills`, `agents.dir`, `instructions`), `.agents/skills/` for every harness that reads it; and what the scan looks at (`instructions.existing`, and `context` by kind: `skill`, `rule`, `command`, `mcp`, `setting`, `plugin`), each path checked against the harness's own docs. dotdot links only skills, agents, and instructions; the rest is found and reported, never written, `harness.sh` answers setup's standard calls (`detect`, `scan`, `rows`, `destinations`, `build`), and the folder's own scripts handle what the data can't express (Codex's `agents-toml.sh`). Each capability's shared logic lives once in `harnesses/capabilities/<capability>.sh`, so changing the data changes the behaviour with no code to touch, and a new capability (MCP, settings) is one more module.

**Agents** are written once, in Claude's Markdown format (`name`, `description`, the prompt), in `.dot/Agents/` or a module's `agents/`, and ported where each harness reads them, linked wherever the format allows:

| Harness | Agents |
|---|---|
| Claude Code, Cursor, OpenCode | linked as they are into `.claude/agents/`, `.cursor/agents/`, `.opencode/agents/` |
| GitHub Copilot | linked as `.github/agents/<name>.agent.md` |
| Codex | rendered as TOML into `.codex/agents/<name>.toml` (`name`, `description`, `developer_instructions`) |

A format belongs to the folder a harness reads: whatever links agents into `.codex/agents/` or `.github/agents/` gets them in that harness's format, whoever wrote the row, and a folder several harnesses read (`.agents/`) gets them as they are. `bash dot link` builds them into `.dot/.harnesses/<id>/` and links them from there, so they follow every change, and deletes what no row uses any more. `tools` and `model` don't port: each harness writes them its own way, so keep them out of an agent meant for more than one, or check it on each.

### Typing `dot` instead of `bash dot`

`bash dot alias:add` adds one line to the rc file of each shell you pick (bash, zsh, fish, ksh, or tcsh; yours, from `$SHELL`, checked; `--shell <a,b>` to name them), after showing each and asking: `dot` then runs `./dot`, or dotdot's own entry when that link is missing. Run it again after moving dotdot; `bash dot alias:remove` takes it back. Setup ends with this tip, and for any other shell shows the line to add yourself.

### Relocating

`bash dot relocate .agents/.dot` moves all of dotdot into the project's `.agents/` folder: it points `dot` at the new place, rewrites the paths in dotdot's files, and relinks everything. Setup offers it when the project has `.agents/`, and the installer takes `--dir .agents/.dot` to install there directly.

---

## Linking

`bash dot link` puts dotdot where your harness reads it: it symlinks files and appends sections, following the `"links"` in `.dot/dot.json`. It previews every change and asks before applying any; run it again whenever skills, agents, or docs are added, renamed, or removed.

```sh
bash dot link                       # preview, then apply
bash dot link -v                    # also list what stays as it is
bash dot link --overwrite    # replace taken destinations; files are backed up first
```

### The links

```json
{
  "@dot:AGENTS.md": ["AGENTS.md", ".claude/CLAUDE.md"],
  "@dotdotSkills": [".claude/skills/"],
  "append": { "@dot:STANDARDS.md": ["docs/STANDARDS.md"] },
  "skip": { "@dot:RULES.md": ["old/rules.md"] },
  "acme/tools": {
    "@plugin:acme.tools:skills/*": [".agents/skills/"],
    "append": { "@plugin:acme.tools:context/STANDARDS.md": ["@dot:STANDARDS.md"] },
    "skip": {}
  },
  "inactive": {
    "acme/lint": { "@plugin:acme.lint:skills/*": [".agents/skills/"], "append": {} }
  }
}
```

| Entry | Meaning |
|---|---|
| `"<origin>": [destinations]` | Symlink each destination to the origin |
| `"append"` | Append the origin's file to each destination, between markers naming its owner |
| `"skip"` | Yours alone: never link or append these, a plugin's and a harness's included; a destination still pointing at the origin is unlinked, and what was appended there taken back. It wins over the rest, and setup never writes or clears it |
| `"<owner>/<name>"` | A plugin's active links, in the same shape |
| `"inactive"` | A plugin's suggested links, never applied until `bash dot plugins:link` takes them |

**Origins:**

- `@dot:<path>`: anything in `.dot/`
- `@module:<name>:<path>`
- `@plugin:<owner>.<name>:<path>`
- `@dotdotSkills`, `@dotdotAgents`: each of dotdot's skills or agents
- `@pluginsSkills`, `@pluginsAgents`: every plugin's

A `/*` ending takes each entry inside one by one.

**Destinations** are project paths outside `.dot/` and `.git/`, never `.env`; appends may also go to `@dot:<Doc>.md`.

**Appends** go between `<!-- <owner>/<name> -->` markers (`#` outside Markdown). Into Markdown, they sit under a rule and a `## <owner>/<name>` heading, with the origin's description quoted. Each owner keeps its own section of a file, so appends never collide. A `.json` takes no markers, so it is only created when missing.

**Removing an entry** unlinks what it linked, and takes its appended section out, at the next `bash dot link`: link compares the disk with the links each run, in the folders it knows of (the links' own, every harness's, and the project's root). A link into `.dot/` there that no entry wants goes too, even one you made by hand; a link elsewhere, or your own file, is never touched. An entry whose folder nothing else names isn't found once deleted: skip it instead, or delete its link.

**When two entries claim one destination**, your own links win over a plugin's, then the first declared; the one left out is reported.

Paths read the same everywhere dotdot takes one: `<path>` is that path, `<path>/` that directory, `<path>/*` everything inside it, and, in the deny lists only, `<start>*` anything starting with `<start>`.

> [!NOTE]
> dotdot edits only the entries it changes and leaves the rest of `dot.json` as you wrote it. A file that doesn't parse is refused, never overwritten. JSON keeps only the last of two identical keys, so `link` offers to merge them.

---

## Using plugins

dotdot ships with everything it needs. A plugin adds more, from any GitHub repo you choose: there's no catalog, and nobody vets plugins for you.

```sh
bash dot plugins:add acme/laravel                 # github.com/acme/laravel
bash dot plugins:add acme/svelte@v1.0.0           # at a branch, tag, or commit
bash dot plugins:add https://github.com/acme/svelte/tree/v1.0.0   # or by its URL
bash dot plugins:link acme/laravel               # take its suggested links
bash dot link                                     # and apply them
bash dot plugins:update acme/laravel              # or --all
bash dot plugins:remove acme/laravel
```

> [!WARNING]
> A plugin is code and instructions from its author: once added, it can run anything on your machine and steer your agents. Every add and update previews each file (scripts flagged) and goes ahead only when you confirm at a terminal.

- **Adding links nothing.** A plugin's suggested links go under `"inactive"` in `.dot/dot.json`; `bash dot plugins:link <owner>/<name>` links them (only them), and `plugins:unlink` takes them back.
- **Updating** rewrites only its inactive links. `plugins:link <owner>/<name> --overwrite` takes the new ones.
- **Removing** takes back everything it linked and appended, and its settings in `.dot/dot.json`. What's left (its secrets in `.env`, and the records it made) is listed for you to review.
- **Its commands** run as `bash dot <owner>:<command>`, or bare for an owner listed in `plugins.unprefixedCommandOwners`. dotdot's own commands are never overridden.
- **Protected destinations** (`plugins.denyLinkDestination`; by default `AGENTS.md`, `RULES.md`, `SECURITY.md`, `USER.md`) are never touched by a plugin's links.

---

## Settings

Every setting lives in `.dot/dot.json`, nested by area. A value comes from there, else from dotdot's defaults (`.dot/.core/dot.defaults.json`, which lists every setting).

```json
{
  "featureFlags": { "release": true },
  "general": { "timezone": "Europe/Madrid" },
  "tasks":   { "service": "file", "githubRepo": "" },
  "plugins": { "unprefixedCommandOwners": ["acme"], "acme/widgets": { "apiUrl": "https://…" } },
  "links":   { "@dot:AGENTS.md": ["AGENTS.md"], "append": {}, "skip": {}, "inactive": {} },
  "release": { "destination": ".ignore/release", "branch": "main", "remotes": { "github": "https://github.com/<owner>/<repo>.git" } },
  "state":   { "version": "1.2.0", "commit": "<commit>", "isReady": true, "migrations": ["0001-<slug>"], "setup": { "harnesses": ["claude"], "type": "parallel", "pending": [], "done": ["context"] } }
}
```

| Setting | Meaning |
|---|---|
| `featureFlags.*` | [Feature flags](#feature-flags) |
| `general.timezone` | An IANA name or a fixed offset (`UTC+2`), for every date dotdot writes |
| `tasks.service`, `tasks.githubRepo` | Where tasks live; set by `bash dot tasks:initialize` |
| `plugins.unprefixedCommandOwners` | Plugin owners whose commands run without the `<owner>:` prefix |
| `plugins.denyLinkOrigin`, `plugins.denyLinkDestination` | What no plugin may link or append from, or to |
| `plugins["<owner>/<name>"]` | A plugin's own settings, written with their defaults when it's added |
| `links` | What `bash dot link` links and appends ([Linking](#linking)) |
| `release.*` | [Releases](#releases) |
| `state.*` | dotdot's own, never a setting: the release installed (`version`, shown by `bash dot -v`) and its commit (what `bash dot upgrade` compares against), whether the context is ready, the migrations applied, and [setup](#setting-up)'s record (`state.setup`: the harnesses chosen, the type, and what is left for the agent). dotdot writes it; it has no defaults and never reads from `.env` |

## Feature flags

Some of dotdot's modules are off until you turn their flag on in `.dot/dot.json`. A module that's off is off entirely: it lists no commands, running one stops with how to turn it on, and `bash dot link` neither links nor appends anything from it, removing what it linked before. Its command and skill names stay reserved, so no plugin takes them while it's off.

```json
{ "featureFlags": { "release": true } }
```

| Flag | Turns on |
|---|---|
| `featureFlags.release` | [Releases](#releases) |

## Values from `.env`

Any string in `dot.json` written as `"@env:<KEY>"` is read from the project's `.env`, so each person can set it apart from the committed file:

```json
{ "general": { "timezone": "@env:MY_TIMEZONE" },
  "release": { "exclude": "@env:RELEASE_EXCLUDE" } }
```

- `.env` is read the way dotenv libraries read it (the first line setting a key wins, `export` is allowed, quotes keep a value as written), and only the file is read, never the process environment.
- Values are cast by their syntax: `true`/`false`, numbers, JSON lists and objects (`RELEASE_EXCLUDE=[".dot/", "dot"]`), and `null` (unset). Anything else, or anything quoted, is text.
- A missing key leaves the value unset, so the default applies.
- References belong in `dot.json` only, and never in `links` or `state`.

## Secrets

Secrets live in the project's git-ignored `.env` alone, never in settings. Their keys are reserved, so no `"@env:"` reference can read one.

| Key | Holds |
|---|---|
| `DOT_GH_TOKEN` | The GitHub token ([GitHub access](#github-access)) |
| `DOT_RELEASE_TOKEN_<REMOTE>` | A release remote's token, encrypted by `bash dot release:token` |
| `DOT_<OWNER>_<NAME>__<KEY>` | A plugin's secrets, readable by that plugin alone |

dotdot stores a secret only while git ignores `.env`, never links or appends to it, and masks anything that looks like a secret in everything it prints.

---

## GitHub access

Everything dotdot does on GitHub (plugin downloads, tasks kept as issues) takes the first route that works:

1. **`gh`**, as your logged-in account, or as `DOT_GH_TOKEN`'s owner when that's set in `.env`. A token always wins over the login, for this project only.
2. **GitHub's API**, with `DOT_GH_TOKEN`, when `gh` is missing or fails.

When every route fails, one error names each attempt, why it failed, and what to do. Public plugins download without any of this; private repos need read access, and tasks need issues and labels. Releases use their own tokens.

---

## Releases

Releases are behind the `featureFlags.release` [feature flag](#feature-flags).

`bash dot release:create` turns the project into a clean, signed public history: each release is one commit in a separate release repo, holding every committed file but the ones you exclude.

```sh
bash dot release:token github                       # save the remote's push token, once
bash dot release:create 1.2.0                       # export, sign, tag; push nothing
bash dot release:create 1.2.0 --push --keep-tokens 15   # ...and push to every remote
bash dot release:push github                        # push, retry or finish a push
bash dot release:token:delete github                # forget a saved token
```

Tokens live in your system's keychain (macOS) or keyring (libsecret), which ask for them with their own prompt; elsewhere they're gpg-encrypted in `.env`, the token asked through pinentry on the terminal and the passphrase by gpg, also on the terminal. dotdot never prompts for a secret itself, and a push hands the token to git through a pipe into git's own credential cache, private to that push. The signing key's passphrase is ssh-add's to ask.

`--force` force-pushes, replacing a remote's history, only once you type that remote's name at a terminal. It stops on uncommitted changes in what it ships, a signing key that doesn't match, anything that looks like a secret, or a remote without a token. It runs no build or tests: do those in your own workflow first.

| Setting | Meaning |
|---|---|
| `release.destination` | The release repo's directory, from the project root |
| `release.exclude` | Paths left out; `"!<path>"` ships a git-ignored one (a build) |
| `release.versionFiles` | `{"<file>": "<JSON path>"}`: where the release writes its version into what it ships, e.g. `{"dist/dot.json": "state.version"}`; the source keeps whatever it holds |
| `release.branch` | The release repo's branch |
| `release.remotes` | `{"<name>": "<https url>"}`, each pushed with its own token |
| `release.signingKey` | The private SSH key's file name in `~/.ssh/`, with its `.pub` next to it |
| `release.authorName`, `release.authorEmail` | The author and committer of release commits |

> [!IMPORTANT]
> For GitHub to show **Verified**, add the signing key's `.pub` to your account as a **signing key**, and use an email verified on that account. dotdot sets the author and committer itself, so a host that overrides `GIT_COMMITTER_*` can't break the signature.

---

## Updating dotdot

```sh
bash dot upgrade                # upgrades in one step; offers bash dot link when the links need it
bash dot upgrade --link -y      # ...and relinks right after (options after --link are bash dot link's)
bash dot plugins:update --all   # plugins update on their own
```

- `upgrade` replaces `.dot/.core/` only; your context, records, and plugins are never touched.
- A file is deleted only when the installed version had it and the latest doesn't; one you edited is kept and listed.
- When a new version changes the format of a file dotdot keeps, `bash dot migrate` converts it. Until then, every other command asks for it first.

---

## Project layout

```text
your-project/
├── dot                     # the entry point: bash dot <command>
├── AGENTS.md               # linked from .dot/AGENTS.md
└── .dot/
    ├── AGENTS.md           # the working agreement every agent reads
    ├── PRODUCT.md  RULES.md  SECURITY.md  STANDARDS.md  TECHSTACK.md  …
    ├── USER.md             # your own preferences
    ├── dot.json            # the project's settings, links included
    ├── Features/  Decisions/  Notes/  Xrays/  Tasks/
    ├── .plugins/           # installed plugins, with plugins-lock.json
    └── .core/              # dotdot itself, replaced by bash dot upgrade
```

The inside of `.dot/.core/` is described in [Architecture](plugins.md#architecture).
