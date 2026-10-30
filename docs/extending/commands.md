---
title: Commands
description: Writing a plugin command.
order: 4
---

# Commands

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
