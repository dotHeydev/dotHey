# Marks each row of a help page's Options section that isn't required: its
# text starts with "Optional." (rewrapped to fit 80 columns), unless it
# already says "Required." or is -h, --help.
function flush(   indent, words, count, i, line, text) {
  if (row == "") return
  if (text_of_row == "" || text_of_row ~ /^Required\./ || option ~ /^-h, --help$/) {
    printf "%s", raw
  } else {
    if (head_line != "") print head_line
    indent = sprintf("%" column "s", "")
    count = split("Optional. " text_of_row, words, / +/)
    line = (head_line != "") ? indent : first_prefix
    text = ""
    for (i = 1; i <= count; i++) {
      if (text != "" && length(line text " " words[i]) > 80) {
        print line text
        line = indent
        text = ""
      }
      text = text (text == "" ? "" : " ") words[i]
    }
    print line text
  }
  row = ""
}

/^[A-Z][^ ].*:$/ {
  flush()
  section = $0
  print
  next
}

section == "Options:" && /^  -/ {
  flush()
  row = $0
  raw = $0 "\n"
  rest = substr($0, 3)
  gap = index(rest, "  ")
  if (gap == 0) {
    option = rest
    head_line = $0
    first_prefix = ""
    text_of_row = ""
    column = 0
  } else {
    option = substr(rest, 1, gap - 1)
    after = substr(rest, gap)
    match(after, /^ +/)
    column = 2 + gap - 1 + RLENGTH
    head_line = ""
    first_prefix = substr($0, 1, column)
    text_of_row = substr($0, column + 1)
  }
  next
}

row != "" && /^   +[^ ]/ {
  raw = raw $0 "\n"
  match($0, /^ +/)
  if (column == 0) column = RLENGTH
  line_text = substr($0, RLENGTH + 1)
  text_of_row = text_of_row (text_of_row == "" ? "" : " ") line_text
  next
}

{
  flush()
  print
}

END { flush() }
