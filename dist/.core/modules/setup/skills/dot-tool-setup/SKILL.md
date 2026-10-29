---
name: dot-tool-setup
description: Sets dotdot up for the project's harnesses with bash dot setup — detects the harnesses the project uses and what they already hold (bash dot adopt --scan --json), then links dotdot where the chosen ones read it (AGENTS.md or an @import into their own instructions file, dotdot's skills and agents), in parallel with the project's own files (combine) or centralizing them (own: moving its skills and agents into .dot/Skills/ and .dot/Agents/, linked back), and can move dotdot into .agents/.dot (bash dot relocate). Use it when the user says "set up dotdot", wants dotdot linked to another harness or unlinked from one, or onboarding finds no harness set up. Applying needs a person at a terminal, so you only scan and preview: run `bash dot adopt --scan --json` and `bash dot setup --harness <a,b> [--strategy combine|own] --preview`, show what would change, then ask the user to run the same command without --preview in their terminal. Never pass -y. Once it ran, `setup.pending` in the scan lists what is left for you (context, split:<path>, unsure:<path>, verify): finish each with dot-ready and mark it with `bash dot setup:done <item>`.
metadata:
  internal: true
---

## Usage
```sh
bash dot setup --help
bash dot adopt --help
bash dot relocate --help
```
