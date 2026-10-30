# Extending dotHey

How to write plugins: new commands, skills, agents, context, and project files, built on dotHey's public API. To use dotHey, see [Using dotHey](usage.md).

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

A plugin is a GitHub repo, `<owner>/<name>`, with a `dothey/` directory. That directory is all dotHey installs, into `.hey/.plugins/<owner>/<name>/`; the rest of the repo is yours.

A plugin can bring:

- **Commands**, run as `bash hey <owner>:<command>`.
- **Skills and agents**, linked where the harness reads them.
- **Context**, appended to dotHey's docs (`STANDARDS.md`, `TECHSTACK.md`, …).
- **Stubs**, appended to files in the project.
- **Code**, organized as you like and loaded through dotHey's module system.

Everything that touches the project is a *suggestion*: it lands under `"inactive"` in the links, and only the user takes it, with `bash hey plugins:link`.

Harness plugins, like `dotHeydev/claude-code`, are ordinary plugins that link dotHey's skills, agents, and docs where one agent reads them.

**Instructions reach agents through the root `AGENTS.md`**, which `bash hey setup` always provides: linked to dotHey's, or with dotHey's section appended to the project's own. Link a plugin's context into dotHey's docs (or append to `AGENTS.md`), never into a harness's own instructions file. Claude Code is the one exception to know: it skips `AGENTS.md` whenever a `CLAUDE.md` exists, so setup always gives it a `CLAUDE.md` importing `@AGENTS.md` (appended to the project's `CLAUDE.md` or `.claude/CLAUDE.md`, or a new `CLAUDE.md`). Anything reaching `AGENTS.md` therefore reaches Claude Code too, with nothing more to link.

---

## Creating a plugin

```sh
bash hey plugins:new acme/widgets               # scaffolds ./widgets, one example of each part
bash hey plugins:add acme/widgets --from ./widgets
bash hey acme:hello dotHey                      # → ✓ Hello, dotHey!
```

`--from` installs from a local copy inside the project: as committed when it's a git repo, as it is on disk otherwise. Rerun `plugins:update acme/widgets` after each change.

```text
widgets/
└── dothey/
    ├── plugin.json
    ├── commands/        # <owner>:<command>
    ├── context/         # *.md appended to dotHey's docs
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

---

## Commands

Each `dothey/commands/<name>.sh` is a command; subdirectories become namespaces (`commands/db/seed.sh` runs as `bash hey acme:db:seed`; one level of subdirectories at most). A command declares a `DESCRIPTION`, a `usage` function for `--help`, and a `handle` function that receives the arguments. dotHey sources every file, never runs it on its own, so a file starts with `# shellcheck shell=bash` instead of a shebang and needs no executable bit:

```bash
# shellcheck shell=bash

DESCRIPTION="Seed the database with sample data."

hey::use framework.console.args framework.console.output

usage() {
  cat <<USAGE
Seeds the database with the plugin's sample data.

Usage:
  bash hey $HEY_COMMAND [--fresh]

Options:
  --fresh      Empty the database first.
  -h, --help   Show this help.

Examples:
  bash hey $HEY_COMMAND --fresh
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

- `DESCRIPTION` is one short line, shown in `bash hey`. `HIDDEN=true` keeps a command out of that list; it still runs.
- `usage` follows the layout of every dotHey help page: a short description, then `Usage:`, `Arguments:`, `Options:`, `Examples:`, and `Notes:` when they help. dotHey styles it at a terminal; keep it plain text.
- `--flag=value` reaches `handle` as `--flag value`, already split.
- An argument error via `framework.console.args::invalid` or `::unexpected` shows the first usage line and where the help is.

Commands are refused when their owner is one of dotHey's command names, or when another plugin already has them. `plugins.unprefixedCommandOwners` lets an owner's commands run without the prefix, never over dotHey's own.

---

## Context, skills, agents, and stubs

| Directory | Suggested as |
|---|---|
| `context/<Doc>.md` | An append to `.hey/<Doc>.md`, created when dotHey has none |
| `skills/<name>/` | A link into `.agents/skills/` |
| `agents/<name>.md` | A link into `.agents/agents/` |
| `stubs/<path>.stub` | An append to `<path>` in the project |

- Appends go between markers naming the plugin, so they never collide with dotHey's or another plugin's, and are taken back cleanly on removal.
- A skill or agent with the same name as dotHey's or another plugin's is reported; wherever both link to one place, the first declared wins.

---

## Settings and secrets

A plugin's settings live in the project's `.hey/hey.json` under `plugins["<owner>/<name>"]`. Adding or updating the plugin writes each key its `plugin.json` declares and `hey.json` lacks, with its default; keys already there stay.

```bash
url=$(hey::plugin_setting apiUrl)                         # its own, from hey.json
strict=$(hey::plugin_setting strict false)                # with a default
hey::save_plugin_setting lastRun '"2026-10-27"'           # JSON values
timezone=$(hey::setting general.timezone "")              # dotHey's, read only
```

Text prints raw; booleans, numbers, lists, and objects print as JSON (`framework.helpers.json::values "$value" '.[]'` lists one entry per line). An unset setting prints the default when one is given, and stops with how to set it otherwise.

Secrets live in the project's `.env`, named `HEY_<OWNER>_<FOLDER>__<KEY>` (its folder's name, see [the public API](#the-public-api) on names and folders), and only their plugin can read them:

```bash
token=$(hey::secret HEY_ACME_WIDGETS__TOKEN)
hey::save_secret HEY_ACME_WIDGETS__TOKEN "$token"
hey::remove_secret HEY_ACME_WIDGETS__TOKEN
```

Leave passwords and passphrases to the system's own prompts (ssh-add, gpg, the keychain): never ask for them yourself. For a secret no system prompt takes, use `framework.console.prompt::pinentry "<description>" ["<label>"]`: gpg's pinentry asks for it on the terminal only (`pinentry-curses` or `pinentry-tty`, never a window), and you get it on stdout to pipe on, never through an argument, the environment, or a file. It fails, asking nothing, with no one at a terminal or no terminal pinentry installed.

---

## The public API

Plugin code may use this, and only this; `hey::use` refuses anything else.

**The `hey::` functions:**

| Function | Does |
|---|---|
| `hey::use <module>...` | Load modules |
| `hey::path project\|dothey\|plugin` | The project's, dotHey's, or the plugin's directory |
| `hey::relative <path>` | A path relative to the project, for messages |
| `hey::setting <path> [default]` | Read one of dotHey's settings (never `state.*`) |
| `hey::state <path> [default]` | Read dotHey's own state (`state.*`: the installed commit, `isReady`, `setup.*`); only dotHey writes it |
| `hey::version` | dotHey's release (`state.version`, `N.N.N`), for display |
| `hey::plugin_setting <key> [default]`, `hey::save_plugin_setting <key> <json>` | Read and write its own settings |
| `hey::secret`, `hey::save_secret`, `hey::remove_secret` | Its own secrets |
| `hey::plugin_key <name>`, `hey::plugin_name <key>` | A plugin's `<owner>/<folder>` from its name, and back |
| `hey::call <command> [args]` | Run another `bash hey` command |
| `hey::raise <message> [next step]...`, `hey::abort …` | Report an error (and exit) |
| `hey::on_exit <command> [<argument>...]` | Run cleanup when the command ends; each argument stays one word, never code |

**Modules:**

- `framework.helpers.*`: `fs`, `text`, `kv`, `date`, `frontmatter`, `template`, `record`, `json`, `net`, `emoji`, `secrets`.
- `framework.console.*`: `output`, `prompt`, `terminal`, `args`.
- `framework.ui.*`: `theme`, `screen`, and the components `banner`, `box`, `message`, `list`, `rule`, `select`, `checkbox`, `confirm`, `progress`, `steps`, `spinner`.
- `framework.integrations.<name>.service`: `github`.
- Its own code: `plugins.<owner>.<folder>.<path>`.

Every function is named after its module: `framework.console.output::success`, `plugins.acme.widgets.db::seed`.

**A plugin's name is its GitHub repo's**, `<owner>/<name>` in lowercase, as GitHub tells repos apart: `acme/my-plg`, `acme/my.plg`, and `acme/my_plg` are three plugins, `acme/MyPlg` and `acme/myplg` one. Commands, settings (`plugins["acme/my.plg"]`), links, and the lock use the name. Its **folder** in `.hey/.plugins/<owner>/` is the name too, unless the name can't be a folder and module name (anything but letters, digits, and `-`, or a name Windows reserves): then it is the name with those characters as `-` and a random noun (`my-plg---otter`), and dotHey says so as it installs. The lock records it as `directory`. The folder names the plugin's modules (`plugins.acme.my-plg---otter.db`) and its secrets' prefix; `hey::plugin_key` and `hey::plugin_name` turn one into the other. dotHey's `core.*` modules, `internal` parts of the framework, and other plugins are off limits.

---

## Output conventions

Print through `framework.console.output`, never with raw `echo`: every line passes one point that masks secrets, styles the output at a terminal, and keeps it plain for agents.

```bash
framework.console.output::success "Seeded the database."                  # ✓
framework.console.output::error "Couldn't reach the API." "Please check apiUrl in .hey/hey.json."
framework.console.output::fail  "Couldn't reach the API." "Please try again later."   # and exit
framework.console.output::warn  "The API is slow today."                  # !
framework.console.output::info  "Pushing to staging…"                     # ℹ
framework.console.output::next  "Run it again with --fresh."              # →
framework.console.output::entry green "$UI_MARK_ADDED" ".agents/skills/acme-review"    # a listed change
```

- **One message, one line** when it fits: what happened, then at most one `→` next step.
- **The voice is plain and friendly:** "Couldn't…", "Please…", "Do you want to…?"; never "Invalid", "Error:", or "the user".
- **Commands, paths, and values are styled for you** at a terminal: write `bash hey link`, `.hey/hey.json`, and `"value"` as they are.
- **When something needs a person**, end with `"$OUTPUT_MANUAL_RUN bash hey <command>"`: people read "Please run the command manually:", agents "Please ask the user to run it in a terminal:".
- **Questions** go through `framework.console.prompt::confirm "Do you want to…?"`, which needs a terminal.

### Styling

Styles compose in three levels, and nest freely: an inner style ends without ending the one around it, and a style spanning several lines carries onto each.

| Level | Helpers |
|---|---|
| Primitives | `bold`, `italic`, `dim`, `red`, `green`, `yellow`, `blue`, `cyan`, `gray`, `light_blue`, or `style <name> <text>` |
| What text is | `path`, `command`, `value`, `setting`, `code`, `heading`, `note` |
| Messages | `success`, `error`, `fail`, `warn`, `info`, `next`, `entry`, `change`, `title` |

```bash
framework.console.output::warn "Kept $(framework.console.output::path "$file"); see $(framework.console.output::command "bash hey link -v")."
framework.console.output::line "$(framework.console.output::bold acme/widgets) $(framework.console.output::note "from ./widgets")"
```

Each helper returns markup, not escape codes. The markup becomes escape codes only as a line prints, and only at a terminal; to print styled text another way (a `read -p` prompt, say), pass it through `framework.console.output::render <descriptor> <text>` first.

---

## UI components

`framework.ui.*` draws interfaces for people from plain arguments. For agents, CI, pipes, `--json`, and dumb terminals, it falls back on its own to plain lines with the same content. Load each component you use: `hey::use framework.ui.select framework.ui.progress`.

- **Ask:** `select`, `checkbox`, and `confirm` print the answer, or return it as their status. Without a terminal that reads keys, they ask for a typed answer; with no one to answer, they return 1, so fall back to your flags.
- **Cancel:** Esc, q, or Ctrl-C stops the command (status 130) and says so. Set the next steps it shows with `framework.ui.screen::on_cancel <step>...`.
- **Look:** every icon, glyph, color, size, and label is in `framework/ui/theme.sh`, with ASCII stand-ins for terminals without Unicode. Override one for a single call, as in `UI_PROGRESS_STYLE=fat framework.ui.progress::show 3 6`. `HEY_UI=plain` turns the drawing off.
- **Preview:** `bash hey tui:view` shows every component; `bash hey tui:view select,progress` runs those; `bash hey tui:view all` runs them all in one flow.

### banner

```bash
framework.ui.banner::show "dotHey setup" "Let's link your harnesses."
```

```text
╭──────────────────────────────╮
│  dotHey setup                │
│  Let's link your harnesses.  │
╰──────────────────────────────╯
```

### box

`box::show <title> <line>...`, the title optional (`""`). `box::wrap <title> <input> [argument...]` draws an input inside one.

```bash
framework.ui.box::show "WHAT'S LINKED" "Claude Code: 12 skills" "Cursor: 12 skills"
picked=$(framework.ui.box::wrap "SELECT ANY" framework.ui.checkbox::ask "Which skills?" review deploy)
```

```text
╭──────────────────────────╮
│  WHAT'S LINKED           │
│                          │
│  Claude Code: 12 skills  │
│  Cursor: 12 skills       │
╰──────────────────────────╯
```

### message

One line, and up to two more: indented for `info`, `success`, and `warning`; next steps for `error`.

```bash
framework.ui.message::success "Linked dotHey to Claude Code." "Your skills show up there now."
framework.ui.message::info "Cursor reads the same skills."
framework.ui.message::warning "Codex has no agents folder yet."
framework.ui.message::error "Couldn't read .hey/hey.json." "Check that the file is valid JSON."
```

```text
✓ Linked dotHey to Claude Code.
   Your skills show up there now.
i Cursor reads the same skills.
! Codex has no agents folder yet.
✗ Couldn't read .hey/hey.json.
   → Check that the file is valid JSON.
```

### list

```bash
framework.ui.list::item "Claude Code" "detected"
framework.ui.list::show Cursor Codex
```

```text
  • Claude Code  (detected)
  • Cursor
  • Codex
```

### rule

As wide as the terminal, or the width given.

```bash
framework.ui.rule::show 20
```

```text
────────────────────
```

### select

One option, picked with ↑/↓ (or its number) and Enter, printed.

```bash
harness=$(framework.ui.select::ask "Which harness do you use most?" "Claude Code" Cursor Codex) || exit
```

```text
Which harness do you use most?
› ◉ Claude Code
  ○ Cursor
  ○ Codex
↑/↓ move · Enter selects
```

Once answered, the frame becomes one line: `Which harness do you use most? › Claude Code`.

### checkbox

Any options, toggled with Space, confirmed with Enter, printed one per line.

```bash
skills=$(framework.ui.checkbox::ask "Which skills should we link?" review deploy release) || exit
```

```text
Which skills should we link?
  ☑ review
› ☐ deploy
  ☑ release
↑/↓ move · Space toggles · Enter confirms
```

### confirm

Yes or no, `y` or `n` the default; ←/→ to change, Enter to confirm, or y/n straight away. Status 0 for yes.

```bash
framework.ui.confirm::ask "Link Cursor too?" y && link_cursor
```

```text
Link Cursor too?  ›  Yes   No
```

The chosen one sits on green (Yes) or red (No), or in brackets without colors. The answer stays as one line, green or red: `Link Cursor too? › Yes`.

### progress

`progress::show <done> <total> [label]`, called again as work goes on; redrawn in place, its line ended at total. `UI_PROGRESS_STYLE` is `thin` (the default), `fat`, or `count`.

```bash
for ((done = 1; done <= total; done++)); do
  link_one "$done"
  framework.ui.progress::show "$done" "$total" "Linking"
done
```

```text
Linking  ━━━━━━━━━━──────────   50%      thin
Linking  ██████████░░░░░░░░░░   50%      fat
Linking  10/20                           count
```

### steps

`steps::run <label> <function> <item>...` calls the function with each item, marking the current one; it stops at the first that fails and returns its status. `steps::show <current> <label> <item>...` draws them as they stand, for loops of your own. `UI_STEPS_CURRENT=loader` turns the `›` into a loader (`⠋⠙⠹…`) while `steps::run` works.

```bash
link() { link_one "$1"; }
UI_STEPS_CURRENT=loader framework.ui.steps::run "Linking" link skills agents rules
```

```text
Linking:
  ✓ skills
  ⠙ agents
  • rules
```

### spinner

A spinner beside the label while the command runs; its errors print once it's done.

```bash
framework.ui.spinner::run "Downloading dotHey…" download "$version"
```

```text
Downloading dotHey… ·●
```

---

## Architecture

```text
.hey/.core/
├── system/          # what dotHey needs to run
│   ├── bin/hey      # the entry point
│   ├── boot.sh      # module loading and the hey:: API
│   ├── kernel.sh    # the command registry and dispatch
│   ├── paths.sh     # where everything is
│   ├── guards.sh    # the policy every action is checked against
│   └── link/  plugins/  update/  migrations/
├── modules/         # what dotHey can do
│   └── onboarding/  ready/  setup/  frontmatter/  housekeeping/  notes/
│       xrays/  features/  decisions/  tasks/  release/
├── harnesses/       # one folder per harness, and capabilities/ shared by them
├── framework/       # the only shared code
│   ├── helpers/     # project-agnostic building blocks
│   ├── console/     # command-line input and output
│   └── integrations/  # external services, each behind service.sh
└── hey.defaults.json
```

- **System parts** load as `core.system.<part>.*`, **modules** as `core.modules.<module>.*`, **harnesses** as `core.harnesses.<id>.*` (from anywhere in the core, never from a plugin), the **framework** as `framework.*`.
- Every system part and module uses only the framework and its own code; it reaches another one through `hey::call`.
- An integration exposes only its `service.sh`; its `internal/` parts load from inside it alone.
- Migrations (`system/migrations/NNNN-<slug>.sh`, each with `DESCRIPTION` and `migrate()`) convert the files dotHey keeps when a new version changes their format; `state.migrations` lists those applied.
- Everything runs on bash 3.2+ with standard Unix tools.

---

## Security model

- **Every guard is a predicate in `guards.sh`**, called where dotHey acts: where links and appends may go, what plugins may declare, which settings and secrets code may touch, when `-y` may skip a confirmation.
- **At boot, dotHey's functions and its path variables become read-only**, so no plugin or edited file can switch a guard off during a run.
- **dotHey never runs plugin code while adding it**, and refuses archives with paths outside the plugin, symlinks, or stubs for `.git/`.
- **Changes need a person:** adding, updating, and removing plugins, linking, updating, and migrating all ask at a terminal, so no agent or script can approve them.
- **Secrets never surface:** they're read from `.env` alone, every printed line is masked, and releases refuse to ship anything that looks like one.

> [!CAUTION]
> These guards protect what *dotHey* does, not what a plugin's own code does: a plugin runs with your permissions. Deciding whom to trust at `plugins:add` stays the real boundary.

---

## Publishing

1. Push the repo to `github.com/<owner>/<name>`, with the plugin in its `dothey/` directory.
2. Tag versions, so users can pin one: `bash hey plugins:add <owner>/<name>@v1.0.0`.
3. Keep `requires` in `plugin.json` in step with the plugin API you build against.

Private repos work too, for users with `gh` signed in or a `HEY_GH_TOKEN` that can read them.
