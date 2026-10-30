---
title: Settings and secrets
description: A plugin's own settings and secrets.
order: 6
---

# Settings and secrets

A plugin's settings live in the project's `.hey/hey.json` under `plugins["<owner>/<name>"]`. Adding or updating the plugin writes each key its `plugin.json` declares and `hey.json` lacks, with its default; keys already there stay.

```bash
url=$(hey::plugin_setting apiUrl)                         # its own, from hey.json
strict=$(hey::plugin_setting strict false)                # with a default
hey::save_plugin_setting lastRun '"2026-10-27"'           # JSON values
timezone=$(hey::setting general.timezone "")              # dotHey's, read only
```

Text prints raw; booleans, numbers, lists, and objects print as JSON (`framework.helpers.json::values "$value" '.[]'` lists one entry per line). An unset setting prints the default when one is given, and stops with how to set it otherwise.

Secrets live in the project's `.env`, named `HEY_<OWNER>_<FOLDER>__<KEY>` (its folder's name, see [the public API](../extending/public-api.md) on names and folders), and only their plugin can read them:

```bash
token=$(hey::secret HEY_ACME_WIDGETS__TOKEN)
hey::save_secret HEY_ACME_WIDGETS__TOKEN "$token"
hey::remove_secret HEY_ACME_WIDGETS__TOKEN
```

Leave passwords and passphrases to the system's own prompts (ssh-add, gpg, the keychain): never ask for them yourself. For a secret no system prompt takes, use `framework.console.prompt::pinentry "<description>" ["<label>"]`: gpg's pinentry asks for it on the terminal only (`pinentry-curses` or `pinentry-tty`, never a window), and you get it on stdout to pipe on, never through an argument, the environment, or a file. It fails, asking nothing, with no one at a terminal or no terminal pinentry installed.
