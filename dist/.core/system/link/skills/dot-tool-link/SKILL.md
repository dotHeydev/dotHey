---
name: dot-tool-link
description: Activates dotdot with bash dot link — seeds USER.md if missing and symlinks and appends what the "links" of .dot/dot.json list (the user's JSON map: general "<origin>": [destinations] links plus "append" and "remove", AGENTS.md by default; each active plugin's group under "<owner>/<name>"; and each plugin's never-applied links under "inactive", such as the harness plugin dotdot-sh/claude-code linking every skill, agent, and doc where its agent reads them, which the user takes with bash dot plugins:link <owner>/<name>). Never edit those links unless the user asks. Use it after installing dotdot or creating a worktree, and whenever a skill, agent, or harness file has been added, renamed, or removed in .dot/.core/system/*/skills/, .dot/.core/modules/*/skills/, .dot/.plugins/, or AGENTS.md — a new skill won't be visible to any agent until this runs. Every run previews its changes and needs a [y/N] answered by a person at a terminal, so you can only preview: run `bash dot link --preview` (or `bash dot plugins:link <owner>/<name> --preview` for one plugin) to show what would change, then ask the user to run `bash dot link` themselves (adding --overwrite only if they want existing destinations replaced). Never pass -y: it approves the changes on the user's behalf and is reserved for the installer.
metadata:
  internal: true
---

## Usage
```sh
bash dot link --help
```
