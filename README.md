# dotdot

**The context, rules, and tools your coding agents work by.** One small kit, any model, any harness.

AI coding agents are only as good as what they're told. Without a shared baseline, each session starts from scratch: the agent guesses your conventions, forgets last week's decisions, and drifts a little further from how your team works. dotdot gives your project that baseline: a lean set of instructions, records, skills, and commands that turns a capable agent into a consistent teammate.

```sh
curl -fsSL https://raw.githubusercontent.com/dotdot-sh/dotdot/main/install.sh | bash
```

Then tell your agent *"I'm using dotdot"*. It interviews you about the project and writes the context itself.

## Why dotdot

- **Consistent behavior, across sessions and models.** Product, rules, security, standards, and stack are written down once, in plain Markdown, and every agent reads them the same way.
- **A workflow agents actually follow.** Feature → plan → tests → code, each stage written down before the next begins, with a skill for every step.
- **Records that outlive the chat.** Features, decisions, notes, tasks, and *xrays* (discussions held in a file) keep what was agreed where the next session will find it.
- **Yours from day one.** A one-time install copies everything into `.dot/` in your project. There's no runtime, no service, no lock-in: edit, extend, or delete anything.
- **Safe by design.** Every change is previewed and confirmed, plugins are opt-in and reviewed, secrets never leave `.env`, and agents can't approve on your behalf.
- **Bash and Markdown, nothing else.** It runs on bash 3.2+ with standard Unix tools, macOS included.

## Quick start

1. **Install** from your project's root:

   ```sh
   curl -fsSL https://raw.githubusercontent.com/dotdot-sh/dotdot/main/install.sh | bash
   ```

   This creates `.dot/` and the `dot` command at the root, then sets dotdot up for your harnesses, asking a few questions first. Rather read it first? Download `install.sh`, read it, then run `bash install.sh`.

2. **Set it up.** The installer runs `bash dot setup` for you (run it again any time): it finds the harnesses the project uses (Amp, Antigravity, Claude Code, Codex, Cursor, Factory Droid, GitHub Copilot, Grok Build, Junie, Kiro, OpenCode, Pi, Zed, `.agents/`) and what they already hold, asks which to link, shows the plan, and links. No plugin needed.

3. **Define.** Tell your agent "set up dotdot". The `dot-ready` skill reads what the project already says, asks about the rest, and fills `.dot/PRODUCT.md`, `RULES.md`, `TECHSTACK.md`, and the rest.

4. **Build.** Describe a feature and let the agent take it from specification to tested code.

> [!TIP]
> Add `dot() { bash dot "$@"; }` to your shell profile to type `dot` instead of `bash dot`.

## A taste of it

```sh
bash dot                                           # every command, at a glance
bash dot features:create "Password reset" --description "Reset a password by email."
bash dot decisions:impact 002 --term session,jwt   # what a decision would touch
bash dot tasks:list --status todo,doing
bash dot xrays:create "Caching" --description "Where and how we cache."
bash dot upgrade                                   # the latest dotdot, after a review
```

Every command answers `--help` with its usage, options, and examples.

## Documentation

**[Using dotdot](docs/usage.md)**: building with it.

- [Concepts](docs/usage.md#concepts): context, tools, and work; rules precedence; who owns what
- [Working with agents](docs/usage.md#working-with-agents): the workflow, skills, and reply flags
- [Records](docs/usage.md#records): features, decisions, notes, xrays, and tasks
- [The `dot` command](docs/usage.md#the-dot-command)
- [Linking](docs/usage.md#linking): what goes where your harness reads
- [Using plugins](docs/usage.md#using-plugins)
- [Settings](docs/usage.md#settings), [values from `.env`](docs/usage.md#values-from-env), and [secrets](docs/usage.md#secrets)
- [GitHub access](docs/usage.md#github-access)
- [Releases](docs/usage.md#releases)
- [Updating dotdot](docs/usage.md#updating-dotdot)
- [Project layout](docs/usage.md#project-layout)

**[Extending dotdot](docs/plugins.md)**: writing plugins.

- [What a plugin is](docs/plugins.md#what-a-plugin-is)
- [Creating a plugin](docs/plugins.md#creating-a-plugin)
- [`plugin.json`](docs/plugins.md#pluginjson)
- [Commands](docs/plugins.md#commands)
- [Context, skills, agents, and stubs](docs/plugins.md#context-skills-agents-and-stubs)
- [Settings and secrets](docs/plugins.md#settings-and-secrets)
- [The public API](docs/plugins.md#the-public-api)
- [Output conventions](docs/plugins.md#output-conventions)
- [Architecture](docs/plugins.md#architecture) and [the security model](docs/plugins.md#security-model)
- [Publishing](docs/plugins.md#publishing)

## Supported harnesses

dotdot is model-agnostic: the context is plain Markdown, and a harness plugin wires it into a specific agent.

- [x] Claude Code: `bash dot plugins:add dotdot-sh/claude-code`
- [ ] OpenCode
- [ ] Codex
- [ ] Copilot
- [ ] Cursor

## Principles

1. **Simplicity.** The smallest set of instructions that achieves the goal.
2. **Reliability.** Instructions that produce the same behavior across sessions and models.
3. **Efficiency.** The least context, tokens, and steps an agent needs to do the right thing.

## License

[MIT](LICENSE)
