---
title: Output conventions
description: Printing messages that read the same for people and agents.
order: 8
---

# Output conventions

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

## Styling

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
