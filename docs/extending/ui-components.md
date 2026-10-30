---
title: UI components
description: Interfaces for people, with plain fallbacks for agents and scripts.
order: 9
---

# UI components

`framework.ui.*` draws interfaces for people from plain arguments. For agents, CI, pipes, `--json`, and dumb terminals, it falls back on its own to plain lines with the same content. Load each component you use: `hey::use framework.ui.select framework.ui.progress`.

- **Ask:** `select`, `checkbox`, and `confirm` print the answer, or return it as their status. Without a terminal that reads keys, they ask for a typed answer; with no one to answer, they return 1, so fall back to your flags.
- **Cancel:** Esc, q, or Ctrl-C stops the command (status 130) and says so. Set the next steps it shows with `framework.ui.screen::on_cancel <step>...`.
- **Look:** every icon, glyph, color, size, and label is in `framework/ui/theme.sh`, with ASCII stand-ins for terminals without Unicode. Override one for a single call, as in `UI_PROGRESS_STYLE=fat framework.ui.progress::show 3 6`. `HEY_UI=plain` turns the drawing off.
- **Preview:** `bash hey tui:view` shows every component; `bash hey tui:view select,progress` runs those; `bash hey tui:view all` runs them all in one flow.

## banner

```bash
framework.ui.banner::show "dotHey setup" "Let's link your harnesses."
```

```text
╭──────────────────────────────╮
│  dotHey setup                │
│  Let's link your harnesses.  │
╰──────────────────────────────╯
```

## box

`box::show <title> <line>...`, the title optional (`""`). `box::wrap <title> <input> [argument...]` draws an input inside one.

```bash
framework.ui.box::show "WHAT'S LINKED" "Claude Code: 12 skills" "Cursor: 12 skills"
picked=$(framework.ui.box::wrap "SELECT ANY" framework.ui.checkbox::ask "Which skills?" review deploy)
```

```text
╭──────────────────────────╮
│  WHAT'S LINKED           │
│                          │
│  Claude Code: 12 skills  │
│  Cursor: 12 skills       │
╰──────────────────────────╯
```

## message

One line, and up to two more: indented for `info`, `success`, and `warning`; next steps for `error`.

```bash
framework.ui.message::success "Linked dotHey to Claude Code." "Your skills show up there now."
framework.ui.message::info "Cursor reads the same skills."
framework.ui.message::warning "Codex has no agents folder yet."
framework.ui.message::error "Couldn't read .hey/hey.json." "Check that the file is valid JSON."
```

```text
✓ Linked dotHey to Claude Code.
   Your skills show up there now.
i Cursor reads the same skills.
! Codex has no agents folder yet.
✗ Couldn't read .hey/hey.json.
   → Check that the file is valid JSON.
```

## list

```bash
framework.ui.list::item "Claude Code" "detected"
framework.ui.list::show Cursor Codex
```

```text
  • Claude Code  (detected)
  • Cursor
  • Codex
```

## rule

As wide as the terminal, or the width given.

```bash
framework.ui.rule::show 20
```

```text
────────────────────
```

## select

One option, picked with ↑/↓ (or its number) and Enter, printed.

```bash
harness=$(framework.ui.select::ask "Which harness do you use most?" "Claude Code" Cursor Codex) || exit
```

```text
Which harness do you use most?
› ◉ Claude Code
  ○ Cursor
  ○ Codex
↑/↓ move · Enter selects
```

Once answered, the frame becomes one line: `Which harness do you use most? › Claude Code`.

## checkbox

Any options, toggled with Space, confirmed with Enter, printed one per line.

```bash
skills=$(framework.ui.checkbox::ask "Which skills should we link?" review deploy release) || exit
```

```text
Which skills should we link?
  ☑ review
› ☐ deploy
  ☑ release
↑/↓ move · Space toggles · Enter confirms
```

## confirm

Yes or no, `y` or `n` the default; ←/→ to change, Enter to confirm, or y/n straight away. Status 0 for yes.

```bash
framework.ui.confirm::ask "Link Cursor too?" y && link_cursor
```

```text
Link Cursor too?  ›  Yes   No
```

The chosen one sits on green (Yes) or red (No), or in brackets without colors. The answer stays as one line, green or red: `Link Cursor too? › Yes`.

## progress

`progress::show <done> <total> [label]`, called again as work goes on; redrawn in place, its line ended at total. `UI_PROGRESS_STYLE` is `thin` (the default), `fat`, or `count`.

```bash
for ((done = 1; done <= total; done++)); do
  link_one "$done"
  framework.ui.progress::show "$done" "$total" "Linking"
done
```

```text
Linking  ━━━━━━━━━━──────────   50%      thin
Linking  ██████████░░░░░░░░░░   50%      fat
Linking  10/20                           count
```

## steps

`steps::run <label> <function> <item>...` calls the function with each item, marking the current one; it stops at the first that fails and returns its status. `steps::show <current> <label> <item>...` draws them as they stand, for loops of your own. `UI_STEPS_CURRENT=loader` turns the `›` into a loader (`⠋⠙⠹…`) while `steps::run` works.

```bash
link() { link_one "$1"; }
UI_STEPS_CURRENT=loader framework.ui.steps::run "Linking" link skills agents rules
```

```text
Linking:
  ✓ skills
  ⠙ agents
  • rules
```

## spinner

A spinner beside the label while the command runs; its errors print once it's done.

```bash
framework.ui.spinner::run "Downloading dotHey…" download "$version"
```

```text
Downloading dotHey… ·●
```
