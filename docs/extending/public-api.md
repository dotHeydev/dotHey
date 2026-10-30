---
title: The public API
description: The functions and modules plugin code may use.
order: 7
---

# The public API

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
