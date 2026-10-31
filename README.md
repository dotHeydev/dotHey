# dotHey

dotHey is a lean kit that turns AI coding agents into consistent teammates. It gives every agent the same project context, the same tools, and the same workflow, with any model and any harness.

dotHey is plain Markdown and Bash. A single install copies it into your project, and from then on your project owns it. No background process, no account, no vendor lock-in.

## Install

1. From your project's root, run the installer:

   ```sh
   curl -fsSL https://raw.githubusercontent.com/dotHeydev/dotHey/main/install.sh | bash
   ```

2. Select your harnesses from the list.

3. Tell your agent "Hey!". The agent onboards itself to your project, helps you define the context, and finishes the remaining setup.

From there, describe a feature and let the agent build it.

## Supported harnesses

| | | |
|---|---|---|
| Amp | Factory Droid | Kiro |
| Antigravity | GitHub Copilot | OpenCode |
| Claude Code | Grok Build | Pi |
| Codex | Junie | Zed |
| Cursor | `.agents/` | |

One copy of dotHey serves all of them. The setup links each file into the location every harness reads, and the root `AGENTS.md` covers most other agents.

## Why dotHey

dotHey gives agents a lasting memory of your project. Your product, rules, security policy, coding standards, and tech stack each live in their own Markdown file, and every agent reads them at the start of every session. Agents apply your conventions from the first prompt and keep applying them across sessions, models, and harnesses.

The decisions made by your team and the specifications of your features live in the repository as records. Agents consult them before they change anything, so the reasoning behind your project survives every chat, every model switch, and every new team member.

Agents also follow one workflow: specification, implementation plan, failing tests, then code. Each stage produces a document before the next one begins, so every feature arrives tested against its own specification.

Your team reviews, versions, and edits all of it like any other code.

## How it works

dotHey organizes its content in three layers:

- **Context:** one Markdown file per concern in `.hey/`. Each file declares in its frontmatter when an agent needs it, so agents load only the files a task requires and spend fewer tokens.
- **Tools:** the `hey` command and a set of agent skills. The command creates and numbers records, links files into each harness, and reports which features a decision affects. The skills guide agents through onboarding, planning, testing, and implementation.
- **Work:** records for features, decisions, notes, and tasks, plus xrays, which hold longer design discussions in a file instead of the chat.

Plugins add support for a specific harness or tech stack. `bash hey upgrade` previews every change of a new version before applying it. dotHey keeps secrets in an untracked `.env` file, sends no data anywhere, and runs on Bash 3.2 or later with standard Unix tools, macOS included.

## Documentation

Read the full [documentation](docs/index.md).

## Contributing

Report bugs and share ideas in [GitHub issues](https://github.com/dotHeydev/dotHey/issues). Before you open a pull request, read the [contributing guide](docs/prologue/contributing.md).

## Release notes

Read the [release notes](docs/prologue/release-notes.md) or browse the [GitHub releases](https://github.com/dotHeydev/dotHey/releases).

## License

dotHey is released under the [MIT License](LICENSE).
