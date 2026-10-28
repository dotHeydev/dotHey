# Extending dotdot

How to write plugins: new commands, skills, agents, context, and project files, built on dotdot's public API. To use dotdot, see [Using dotdot](usage.md).

- [What a plugin is](#what-a-plugin-is)
- [Creating a plugin](#creating-a-plugin)
- [`plugin.json`](#pluginjson)
- [Commands](#commands)
- [Context, skills, agents, and stubs](#context-skills-agents-and-stubs)
- [Settings and secrets](#settings-and-secrets)
- [The public API](#the-public-api)
- [Output conventions](#output-conventions)
- [Architecture](#architecture)
- [Security model](#security-model)
- [Publishing](#publishing)

---

## What a plugin is

A plugin is a GitHub repo, `<owner>/<name>`, with a `dotdot/` directory. That directory is all dotdot installs, into `.dot/.plugins/<owner>/<name>/`; the rest of the repo is yours.

A plugin can bring:

- **Commands**, run as `bash dot <owner>:<command>`.
- **Skills and agents**, linked where the harness reads them.
- **Context**, appended to dotdot's docs (`STANDARDS.md`, `TECHSTACK.md`, …).
- **Stubs**, appended to files in the project.
- **Code**, organized as you like and loaded through dotdot's module system.

Everything that touches the project is a *suggestion*: it lands under `"inactive"` in the links, and only the user takes it, with `bash dot plugins:link`.

Harness plugins, like `dotdot-sh/claude-code`, are ordinary plugins that link dotdot's skills, agents, and docs where one agent reads them.

---

## Creating a plugin

```sh
bash dot plugins:new acme/widgets               # scaffolds ./widgets, one example of each part
bash dot plugins:add acme/widgets --from ./widgets
bash dot acme:hello dotdot                      # → ✓ Hello, dotdot!
```

`--from` installs from a local copy inside the project: as committed when it's a git repo, as it is on disk otherwise. Rerun `plugins:update acme/widgets` after each change.

```text
widgets/
└── dotdot/
    ├── plugin.json
    ├── commands/        # <owner>:<command>
    ├── context/         # *.md appended to dotdot's docs
    ├── skills/          # linked into .agents/skills/
    ├── agents/          # linked into .agents/agents/
    └── stubs/           # <path>.stub appended to <path>
```

---

## `plugin.json`

```json
{
  "requires": 3,
  "description": "Widgets for Acme projects.",
  "depends": ["jq", "framework.integrations.github"],
  "settings": { "apiUrl": "https://widgets.acme.test", "strict": false },
  "link": { "skills/acme-review": [".claude/skills/acme-review"] },
  "append": { "context/STANDARDS.md": ["@dot:STANDARDS.md"] }
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
- `@dot:<Doc>.md`, one of dotdot's top-level docs.
- `@dotdotSkills`, `@dotdotAgents`: dotdot's own skills and agents, for a harness plugin.

**Destinations:**

- Links go to project paths outside `.dot/` and `.git/`, never `.env`.
- Appends may also go to `@dot:<Doc>.md`.
- A destination protected by `plugins.denyLinkDestination` is reported and never applied.

> [!NOTE]
> For each of `skills/`, `agents/`, `context/`, and `stubs/`, dotdot suggests what it finds there, unless `plugin.json` places something from that directory itself. Once it does, only what `plugin.json` declares is suggested for that directory.

---

## Commands

Each `dotdot/commands/<name>.sh` is a command; subdirectories become namespaces (`commands/db/seed.sh` runs as `bash dot acme:db:seed`; one level of subdirectories at most). A command declares a `DESCRIPTION`, a `usage` function for `--help`, and a `handle` function that receives the arguments:

```bash
#!/usr/bin/env bash

DESCRIPTION="Seed the database with sample data."

dot::use framework.console.args framework.console.output

usage() {
  cat <<USAGE
Seeds the database with the plugin's sample data.

Usage:
  bash dot $DOT_COMMAND [--fresh]

Options:
  --fresh      Empty the database first.
  -h, --help   Show this help.

Examples:
  bash dot $DOT_COMMAND --fresh
USAGE
}

handle() {
  local fresh=false
  while [ $# -gt 0 ]; do
    case "$1" in
      --fresh) fresh=true ;;
      *) framework.console.args::unexpected "$1" ;;
    esac
    shift
  done
  framework.console.output::success "Seeded the database."
}
```

- `DESCRIPTION` is one short line, shown in `bash dot`.
- `usage` follows the layout of every dotdot help page: a short description, then `Usage:`, `Arguments:`, `Options:`, `Examples:`, and `Notes:` when they help. dotdot styles it at a terminal; keep it plain text.
- `--flag=value` reaches `handle` as `--flag value`, already split.
- An argument error via `framework.console.args::invalid` or `::unexpected` shows the first usage line and where the help is.

Commands are refused when their owner is one of dotdot's command names, or when another plugin already has them. `plugins.unprefixedCommandOwners` lets an owner's commands run without the prefix, never over dotdot's own.

---

## Context, skills, agents, and stubs

| Directory | Suggested as |
|---|---|
| `context/<Doc>.md` | An append to `.dot/<Doc>.md`, created when dotdot has none |
| `skills/<name>/` | A link into `.agents/skills/` |
| `agents/<name>.md` | A link into `.agents/agents/` |
| `stubs/<path>.stub` | An append to `<path>` in the project |

- Appends go between markers naming the plugin, so they never collide with dotdot's or another plugin's, and are taken back cleanly on removal.
- A skill or agent with the same name as dotdot's or another plugin's is reported; wherever both link to one place, the first declared wins.

---

## Settings and secrets

A plugin's settings live in the project's `.dot/dot.json` under `plugins["<owner>/<name>"]`. Adding or updating the plugin writes each key its `plugin.json` declares and `dot.json` lacks, with its default; keys already there stay.

```bash
url=$(dot::plugin_setting apiUrl)                         # its own, from dot.json
strict=$(dot::plugin_setting strict false)                # with a default
dot::save_plugin_setting lastRun '"2026-10-27"'           # JSON values
timezone=$(dot::setting general.timezone "")              # dotdot's, read only
```

Text prints raw; booleans, numbers, lists, and objects print as JSON (`framework.helpers.json::values "$value" '.[]'` lists one entry per line). An unset setting prints the default when one is given, and stops with how to set it otherwise.

Secrets live in the project's `.env`, named `DOT_<OWNER>_<NAME>__<KEY>`, and only their plugin can read them:

```bash
token=$(dot::secret DOT_ACME_WIDGETS__TOKEN)
dot::save_secret DOT_ACME_WIDGETS__TOKEN "$token"
dot::remove_secret DOT_ACME_WIDGETS__TOKEN
```

---

## The public API

Plugin code may use this, and only this; `dot::use` refuses anything else.

**The `dot::` functions:**

| Function | Does |
|---|---|
| `dot::use <module>...` | Load modules |
| `dot::path project\|dotdot\|plugin` | The project's, dotdot's, or the plugin's directory |
| `dot::relative <path>` | A path relative to the project, for messages |
| `dot::setting <path> [default]` | Read one of dotdot's settings |
| `dot::plugin_setting <key> [default]`, `dot::save_plugin_setting <key> <json>` | Read and write its own settings |
| `dot::secret`, `dot::save_secret`, `dot::remove_secret` | Its own secrets |
| `dot::call <command> [args]` | Run another `bash dot` command |
| `dot::raise <message> [next step]...`, `dot::abort …` | Report an error (and exit) |
| `dot::on_exit <function>` | Run cleanup when the command ends |

**Modules:**

- `framework.helpers.*`: `fs`, `text`, `kv`, `date`, `frontmatter`, `template`, `record`, `json`, `net`, `emoji`, `secrets`.
- `framework.console.*`: `output`, `prompt`, `terminal`, `args`.
- `framework.integrations.<name>.service`: `github`.
- Its own code: `plugins.<owner>.<name>.<path>`.

Every function is named after its module: `framework.console.output::success`, `plugins.acme.widgets.db::seed`. dotdot's `core.*` modules, `internal` parts of the framework, and other plugins are off limits.

---

## Output conventions

Print through `framework.console.output`, never with raw `echo`: every line passes one point that masks secrets, styles the output at a terminal, and keeps it plain for agents.

```bash
framework.console.output::success "Seeded the database."                  # ✓
framework.console.output::error "Couldn't reach the API." "Please check apiUrl in .dot/dot.json."
framework.console.output::fail  "Couldn't reach the API." "Please try again later."   # and exit
framework.console.output::warn  "The API is slow today."                  # !
framework.console.output::info  "Pushing to staging…"                     # ℹ
framework.console.output::next  "Run it again with --fresh."              # →
framework.console.output::entry green "+" ".agents/skills/acme-review"    # a listed change
```

- **One message, one line** when it fits: what happened, then at most one `→` next step.
- **The voice is plain and friendly:** "Couldn't…", "Please…", "Do you want to…?"; never "Invalid", "Error:", or "the user".
- **Commands, paths, and values are styled for you** at a terminal: write `bash dot link`, `.dot/dot.json`, and `"value"` as they are.
- **When something needs a person**, end with `"$OUTPUT_MANUAL_RUN bash dot <command>"`: people read "Please run the command manually:", agents "Please ask the user to run it in a terminal:".
- **Questions** go through `framework.console.prompt::confirm "Do you want to…?"`, which needs a terminal.

### Styling

Styles compose in three levels, and nest freely: an inner style ends without ending the one around it, and a style spanning several lines carries onto each.

| Level | Helpers |
|---|---|
| Primitives | `bold`, `italic`, `dim`, `red`, `green`, `yellow`, `blue`, `cyan`, `gray`, `light_blue`, or `style <name> <text>` |
| What text is | `path`, `command`, `value`, `setting`, `code`, `heading`, `note` |
| Messages | `success`, `error`, `fail`, `warn`, `info`, `next`, `entry`, `change`, `title` |

```bash
framework.console.output::warn "Kept $(framework.console.output::path "$file"); see $(framework.console.output::command "bash dot link -v")."
framework.console.output::line "$(framework.console.output::bold acme/widgets) $(framework.console.output::note "from ./widgets")"
```

Each helper returns markup, not escape codes. The markup becomes escape codes only as a line prints, and only at a terminal; to print styled text another way (a `read -p` prompt, say), pass it through `framework.console.output::render <descriptor> <text>` first.

---

## Architecture

```text
.dot/.core/
├── system/          # what dotdot needs to run
│   ├── bin/dot      # the entry point
│   ├── boot.sh      # module loading and the dot:: API
│   ├── kernel.sh    # the command registry and dispatch
│   ├── paths.sh     # where everything is
│   ├── guards.sh    # the policy every action is checked against
│   └── link/  plugins/  update/  migrations/
├── modules/         # what dotdot can do
│   └── onboarding/  ready/  frontmatter/  housekeeping/  notes/  xrays/
│       features/  decisions/  tasks/  release/
├── framework/       # the only shared code
│   ├── helpers/     # project-agnostic building blocks
│   ├── console/     # command-line input and output
│   └── integrations/  # external services, each behind service.sh
└── dot.defaults.json
```

- **System parts** load as `core.system.<part>.*`, **modules** as `core.modules.<module>.*`, the **framework** as `framework.*`.
- Every system part and module uses only the framework and its own code; it reaches another one through `dot::call`.
- An integration exposes only its `service.sh`; its `internal/` parts load from inside it alone.
- Migrations (`system/migrations/NNNN-<slug>.sh`, each with `DESCRIPTION` and `migrate()`) convert the files dotdot keeps when a new version changes their format; `state.migrations` lists those applied.
- Everything runs on bash 3.2+ with standard Unix tools.

---

## Security model

- **Every guard is a predicate in `guards.sh`**, called where dotdot acts: where links and appends may go, what plugins may declare, which settings and secrets code may touch, when `-y` may skip a confirmation.
- **At boot, dotdot's functions and its path variables become read-only**, so no plugin or edited file can switch a guard off during a run.
- **dotdot never runs plugin code while adding it**, and refuses archives with paths outside the plugin, symlinks, or stubs for `.git/`.
- **Changes need a person:** adding, updating, and removing plugins, linking, updating, and migrating all ask at a terminal, so no agent or script can approve them.
- **Secrets never surface:** they're read from `.env` alone, every printed line is masked, and releases refuse to ship anything that looks like one.

> [!CAUTION]
> These guards protect what *dotdot* does, not what a plugin's own code does: a plugin runs with your permissions. Deciding whom to trust at `plugins:add` stays the real boundary.

---

## Publishing

1. Push the repo to `github.com/<owner>/<name>`, with the plugin in its `dotdot/` directory.
2. Tag versions, so users can pin one: `bash dot plugins:add <owner>/<name>@v1.0.0`.
3. Keep `requires` in `plugin.json` in step with the plugin API you build against.

Private repos work too, for users with `gh` signed in or a `DOT_GH_TOKEN` that can read them.
