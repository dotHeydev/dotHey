# shellcheck shell=bash

# dotHey's look, in one place: every icon, glyph, style, size, and label its
# output and its UI components draw with. Change them here only.
#
# Styles are render.awk's names, space-separated, outermost first: bold, dim,
# italic, underline, red, green, yellow, blue, magenta, cyan, gray,
# light-blue, bright, bg-red, bg-green, bg-blue. A single call can override
# one, as in UI_PROGRESS_STYLE=fat framework.ui.progress::show 3 6.
#
# A UI_GLYPH_<NAME>_ASCII or UI_HINT_<NAME>_ASCII stands in for the one
# without _ASCII where the terminal can't draw Unicode
# (framework.ui.screen::detect).

# Messages, printed as they are in every output, plain text included.
UI_ICON_SUCCESS="✓"
UI_ICON_ERROR="✗"
UI_ICON_WARNING="!"
UI_ICON_INFO="i"
UI_ICON_NEXT="→"
UI_ICON_CANCELLED="⚠"
UI_TIP_LABEL="💡 Tip:"
UI_SEPARATOR="•"
UI_ARROW="→"
UI_INDENT="   "

# A listed change (framework.console.output::entry).
UI_MARK_ADDED="+"
UI_MARK_REMOVED="-"
UI_MARK_CHANGED="*"
UI_MARK_LINKED="~"
UI_MARK_APPENDED=">"
UI_MARK_TAKEN="!"
UI_MARK_UNCHANGED="·"

# What text is.
UI_STYLE_SUCCESS="bold green"
UI_STYLE_ERROR="bold red"
UI_STYLE_WARNING="bold yellow"
UI_STYLE_INFO="bold light-blue"
UI_STYLE_NEXT="bold magenta"
UI_STYLE_CANCELLED="bold red"
UI_STYLE_TITLE="bold"
UI_STYLE_HEADING="bold blue"
UI_STYLE_PATH="gray"
UI_STYLE_COMMAND="bold bright"
UI_STYLE_VALUE="italic"
UI_STYLE_SETTING="italic bright"
UI_STYLE_CODE="cyan"
UI_STYLE_NOTE="light-blue italic"
UI_STYLE_REFERENCE="bold"
UI_STYLE_MUTED="dim"

# The states of an option in select, checkbox, and confirm.
UI_STYLE_POINTER="bold cyan"
UI_STYLE_HOVERED="bold"
UI_STYLE_ON="green"
UI_STYLE_OFF="gray"
UI_STYLE_HINT="dim"
UI_STYLE_ANSWER="cyan"
UI_STYLE_ANSWER_YES="bold green"
UI_STYLE_ANSWER_NO="bold red"
UI_STYLE_YES="bold bg-green"
UI_STYLE_NO="bold bg-red"
UI_STYLE_IDLE="dim"

# Glyphs, with what stands in for them without Unicode.
UI_GLYPH_POINTER="›"
UI_GLYPH_POINTER_ASCII=">"
UI_GLYPH_RADIO_ON="◉"
UI_GLYPH_RADIO_ON_ASCII="(*)"
UI_GLYPH_RADIO_OFF="○"
UI_GLYPH_RADIO_OFF_ASCII="( )"
UI_GLYPH_CHECK_ON="☑"
UI_GLYPH_CHECK_ON_ASCII="[x]"
UI_GLYPH_CHECK_OFF="☐"
UI_GLYPH_CHECK_OFF_ASCII="[ ]"
UI_GLYPH_BULLET="•"
UI_GLYPH_BULLET_ASCII="*"
UI_GLYPH_RULE="─"
UI_GLYPH_RULE_ASCII="-"
UI_GLYPH_THIN_DONE="━"
UI_GLYPH_THIN_DONE_ASCII="="
UI_GLYPH_THIN_TODO="─"
UI_GLYPH_THIN_TODO_ASCII="-"
UI_GLYPH_FAT_DONE="█"
UI_GLYPH_FAT_DONE_ASCII="#"
UI_GLYPH_FAT_TODO="░"
UI_GLYPH_FAT_TODO_ASCII="."
UI_GLYPH_BOX_TOP_LEFT="╭"
UI_GLYPH_BOX_TOP_LEFT_ASCII="+"
UI_GLYPH_BOX_TOP_RIGHT="╮"
UI_GLYPH_BOX_TOP_RIGHT_ASCII="+"
UI_GLYPH_BOX_BOTTOM_LEFT="╰"
UI_GLYPH_BOX_BOTTOM_LEFT_ASCII="+"
UI_GLYPH_BOX_BOTTOM_RIGHT="╯"
UI_GLYPH_BOX_BOTTOM_RIGHT_ASCII="+"
UI_GLYPH_BOX_HORIZONTAL="─"
UI_GLYPH_BOX_HORIZONTAL_ASCII="-"
UI_GLYPH_BOX_VERTICAL="│"
UI_GLYPH_BOX_VERTICAL_ASCII="|"

# Box and banner.
UI_BOX_PADDING=2
UI_STYLE_BOX="gray"
UI_STYLE_BOX_TITLE="bold"
UI_STYLE_BANNER="blue"
UI_STYLE_BANNER_TITLE="bold"

# Rule: as wide as the terminal, or UI_WIDTH when that's unknown.
UI_WIDTH=80
UI_STYLE_RULE="gray"

# Progress: thin, fat, or count (12/34).
UI_PROGRESS_STYLE=thin
UI_PROGRESS_WIDTH=20
UI_STYLE_PROGRESS_DONE="green"
UI_STYLE_PROGRESS_TODO="gray"
UI_STYLE_PROGRESS_LABEL="bold"

# Steps: how many show at once, around the current one, and what marks the
# current one: pointer, or loader (a one-character loop while steps::run works).
UI_STEPS_VISIBLE=5
UI_STEPS_CURRENT=pointer
UI_STEPS_LOADER_FRAMES=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
UI_STEPS_LOADER_FRAMES_ASCII=('|' '/' '-' "\\")
UI_STYLE_STEP_DONE="green"
UI_STYLE_STEP_CURRENT="bold cyan"
UI_STYLE_STEP_PENDING="gray"
UI_STYLE_STEP_FAILED="bold red"

# Spinner: one frame every UI_SPINNER_INTERVAL seconds, the first
# UI_SPINNER_GRACE_FRAMES of them not drawn when there's no label.
UI_SPINNER_FRAMES=(' ·●' ' •⏺' ' ⏺•' ' ●·' ' ⏺•' ' •⏺' ' ·●')
UI_SPINNER_FRAMES_ASCII=(' |' ' /' ' -' " \\")
UI_SPINNER_INTERVAL=0.07
UI_SPINNER_GRACE_FRAMES=4
# Whether the label stays once the command is done, or goes with the spinner.
UI_SPINNER_KEEP=true

# Words.
UI_LABEL_YES="Yes"
UI_LABEL_NO="No"
UI_LABEL_ABORTED="Cancelled — nothing changed."
UI_LABEL_CANCELLED="Cancelled."
UI_HINT_SELECT="↑/↓ move · Enter selects"
UI_HINT_SELECT_ASCII="Up/Down move, Enter selects"
UI_HINT_CHECKBOX="↑/↓ move · Space toggles · Enter confirms"
UI_HINT_CHECKBOX_ASCII="Up/Down move, Space toggles, Enter confirms"
UI_HINT_CHOICE="Choose 1–%s (Ctrl-D cancels): "
UI_HINT_CHOICES="Choose any of 1–%s, separated by spaces: "
UI_HINT_INVALID="Please pick a number from the list."
