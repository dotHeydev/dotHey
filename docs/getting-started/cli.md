---
title: The hey command
description: The one entry point for you and your agents, and the conventions every command follows.
order: 5
---

# The hey command

`hey` at your project root is the one entry point for you and your agents. Run `bash hey` for the list, and `--help` on any command for its usage, options, and examples.

| Area | Commands |
|---|---|
| dotHey itself | `link`, `upgrade`, `migrate`, `version` |
| Links | `plugins:link`, `plugins:unlink` |
| Plugins | `plugins:add`, `plugins:update`, `plugins:remove`, `plugins:list`, `plugins:new` |
| Records | `features:create`, `decisions:create`, `decisions:update`, `decisions:impact`, `decisions:citers`, `decisions:check`, `notes:create`, `xrays:create`, `frontmatter:show` |
| Tasks | `tasks:initialize`, `tasks:create`, `tasks:update`, `tasks:get`, `tasks:list`, `tasks:delete`, `tasks:todo`, `tasks:doing`, `tasks:paused`, `tasks:done`, `tasks:discarded` |
| Releases | `release:create`, `release:push`, `release:token`, `release:token:delete` |

Every command follows the same conventions:

- What it acts on is a parameter (`<id>`, `<owner>/<name>`, `<version>`); how it acts is a flag.
- Flags take their value after a space or an `=`: `--status done` or `--status=done`.
- Common flags have short forms: `-y, --yes`, `-v, --verbose`, `-s, --status`, `-l, --limit`, `-p, --page`, `-h, --help`; `bash hey -v` is the version: the release (`dotHey 1.2.0`, `state.version`, written by the release that shipped it), with the installed commit too under `--json`.
- What changes things can be looked at first with `--preview` (also `--dry-run`); `--overwrite` (also `--force`) replaces what's already there.
- At a terminal, a missing required value is asked for, then the full command is shown to reuse; without one, it fails naming the flag.
- Data commands take `--json`: the result alone on stdout; on stderr, one JSON object per line for everything else, an error as `{"error": {"code", "exitCode", "message", "run", "next"}}`, and a warning, notice, or next step as `{"warning" | "notice" | "next": {"message", "run"}}` (`run`: the dotHey command it names, or `null`). `bash hey --json` lists the commands, and `bash hey help <command> --json` describes one; both hold everything their help page says (`about`, `usage`, `arguments`, `options`, `notes`, `examples`, and any other section under `sections`).
- Exit statuses: `0` success (an empty result too), `1` failure (or problems found, for `decisions:check`), `2` wrong usage, `4` not found, `5` needs something first (a person at a terminal, a clean tree…), `130` interrupted.
- A mistyped command suggests the closest one; a wrong argument shows the usage line and where the help is. Each help ends with a link to these docs.
