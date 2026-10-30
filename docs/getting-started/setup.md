---
title: Setup and harnesses
description: Linking dotHey into the harnesses your project uses, and what setup leaves for your agent.
order: 2
---

# Setup and harnesses

The installer places dotHey, then hands over to `bash hey setup`, which puts dotHey where your harnesses read it, out of the box, for Amp, Antigravity, Claude Code, Codex, Cursor, Factory Droid, GitHub Copilot, Grok Build, Junie, Kiro, OpenCode, Pi, Zed, and `.agents/`. With no one at a terminal, the installer links only `AGENTS.md`, so any agent finds dotHey, and names the setup command.

```sh
curl -fsSL https://raw.githubusercontent.com/dotHeydev/dotHey/main/install.sh | bash      # install, then set up
curl … | bash -s -- --harness claude,cursor --type parallel --yes                           # install and set up
bash hey setup                                       # look, ask, show the plan, apply
bash hey setup --harness claude --type centralize --preview
bash hey adopt --scan --json                         # what the project already holds
```

Setup first looks through the project ("Getting dotHey ready for your project…"): what each harness already holds (instructions, skills, agents, rules; `adopt --scan` also lists other top-level docs as *unsure*, for `hey-ready` to raise with you). Then it asks its questions, numbered (1/4), only those that apply: which harnesses to link, the detected ones checked; what happens to existing skills and agents, when there are any; and where dotHey lives, when `.agents/` holds more than skills or is linked into. It shows the plan, condensed by what changes in your project and in dotHey, and applies it once you agree, as a list of steps ticking off. Esc, q, or Ctrl-C stops at any question, changing nothing.

- **In parallel** (`--type parallel`, the default): they stay where they are, and dotHey's are linked beside them.
- **Centralize** (`--type centralize`): they move into `.hey/Skills/` and `.hey/Agents/` and are linked back into every chosen harness, so they're edited in `.hey/` from then on. An agent in a harness's own format is taken into dotHey's (Codex's TOML becomes Markdown). The same item in several harnesses moves once, its identical copies replaced by links; a copy that differs, a name dotHey already uses, a link leading elsewhere, or a file that can't be read as an agent is left in place.

A harness that reads only one instructions file gets dotHey in that one: Zed reads the first of `.rules`, `.cursorrules`, `.windsurfrules`, `.clinerules`, `.github/copilot-instructions.md`, `AGENT.md`, and `AGENTS.md`, and Junie reads `.junie/AGENTS.md` before `AGENTS.md`, so when the project has an earlier one, dotHey's `AGENTS.md` is appended to it.

> **Tip:** some harnesses also read other tools' folders (Cursor reads `.claude/agents/`, GitHub Copilot and Amp read `.claude/skills/` and `CLAUDE.md`, ...). Choose them together with Claude Code and they may show dotHey's skills, agents, or instructions twice. That's harmless; if it bothers you, link only the harnesses you use.

A harness's own instructions file is never replaced: dotHey appends an import of `AGENTS.md` in that harness's syntax, or links `AGENTS.md` where the harness reads one. Claude Code skips `AGENTS.md` whenever a `CLAUDE.md` exists (and some sessions can't read it at all), so it always gets a `CLAUDE.md` importing the root `AGENTS.md` (`@AGENTS.md`): appended to the first of `CLAUDE.md` and `.claude/CLAUDE.md` that exists, or a new `CLAUDE.md` when there's none. Setup changes only the harnesses' rows in the [links](../configuration/linking.md#the-links) (what a harness's data describes) and lets `bash hey link` do the linking, so everything is previewed, backed up, and reversible; your own rows and your skips stay as they are. Run it again to change the choice: harnesses no longer chosen lose their rows, and link removes what those linked. It records the choice in dotHey's state (`state.setup.harnesses` and `state.setup.type` in `.hey/hey.json`), and what only your agent can finish in `state.setup.pending`: the context, with centralize the split of your instruction files and a check that every harness reads what moved, and any unsure docs to ask you about. While it applies the choice, `state.setup.pending` holds `apply`: a setup stopped halfway shows it, and running setup again finishes it. Your agent picks it up at its next session, confirms with you once, finishes it, and marks each item with `bash hey setup:done <item>`; the default setup leaves it only the context.

| Flag | Meaning |
|---|---|
| `--harness <a,b>` | The harnesses to link; without it, a terminal asks |
| `--type parallel\|centralize` | What happens to the project's own skills and agents |
| `--dir <path>` | Where dotHey lives afterwards ([Relocating](../maintenance/relocating.md)) |
| `--preview`, `-y` | Show only, or apply without asking (at a terminal) |

Each harness is a folder in `.hey/.core/harnesses/<id>/`: `harness.json` keeps three things apart: `detect`, what tells for sure the harness is in use: its own folders and files only (`.claude/`, `CLAUDE.md`, `.zed/`, `.rules`, `.agents/mcp_config.json` for Antigravity), never a place several harnesses read, like `AGENTS.md` or `.agents/skills/`, and never a folder holding only dotHey's links, so only those are checked from the start; where dotHey links what it brings (`skills`, `agents.dir`, `instructions`), `.agents/skills/` for every harness that reads it; and what the scan looks at (`instructions.existing`, and `context` by kind: `skill`, `rule`, `command`, `mcp`, `setting`, `plugin`), each path checked against the harness's own docs. dotHey links only skills, agents, and instructions; the rest is found and reported, never written, `harness.sh` answers setup's standard calls (`detect`, `scan`, `rows`, `destinations`, `build`), and the folder's own scripts handle what the data can't express (Codex's `agents-toml.sh`). Each capability's shared logic lives once in `harnesses/capabilities/<capability>.sh`, so changing the data changes the behaviour with no code to touch, and a new capability (MCP, settings) is one more module.

**Agents** are written once, in Claude's Markdown format (`name`, `description`, the prompt), in `.hey/Agents/` or a module's `agents/`, and ported where each harness reads them, linked wherever the format allows:

| Harness | Agents |
|---|---|
| Claude Code, Cursor, OpenCode | linked as they are into `.claude/agents/`, `.cursor/agents/`, `.opencode/agents/` |
| GitHub Copilot | linked as `.github/agents/<name>.agent.md` |
| Codex | rendered as TOML into `.codex/agents/<name>.toml` (`name`, `description`, `developer_instructions`) |

A format belongs to the folder a harness reads: whatever links agents into `.codex/agents/` or `.github/agents/` gets them in that harness's format, whoever wrote the row, and a folder several harnesses read (`.agents/`) gets them as they are. `bash hey link` builds them into `.hey/.harnesses/<id>/` and links them from there, so they follow every change, and deletes what no row uses any more. `tools` and `model` don't port: each harness writes them its own way, so keep them out of an agent meant for more than one, or check it on each.

## Typing `hey` instead of `bash hey`

`bash hey alias:add` adds one line to the rc file of each shell you pick (bash, zsh, fish, ksh, or tcsh; yours, from `$SHELL`, checked; `--shell <a,b>` to name them), after showing each and asking: `hey` then runs `./hey`, or dotHey's own entry when that link is missing. Run it again after moving dotHey; `bash hey alias:remove` takes it back. Setup ends with this tip, and for any other shell shows the line to add yourself.
