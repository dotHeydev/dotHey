# Renders dotHey's style markup, the one place styles become escape codes:
# \001<name>\002 opens a style and \003 closes the last one opened. With
# styled=1 each style becomes its escape code; closing one resets and puts
# back every style still open, so styles nest, and a style still open at the
# end of a line goes on again on the next. Codes are written only where text
# follows them. "bright" turns the colors open with it into their bright
# variants (31 red becomes 91); it can't brighten the terminal's own default
# color. Otherwise the markup is dropped.
BEGIN {
  OPEN = sprintf("%c", 1); NAME_END = sprintf("%c", 2); CLOSE = sprintf("%c", 3)
  MARK = "[" OPEN CLOSE "]"
  code["bold"] = 1; code["dim"] = 2; code["italic"] = 3; code["underline"] = 4
  code["red"] = 31; code["green"] = 32; code["yellow"] = 33; code["blue"] = 34
  code["magenta"] = 35; code["cyan"] = 36; code["gray"] = 90; code["light-blue"] = 94
  code["bg-red"] = 41; code["bg-green"] = 42; code["bg-blue"] = 44
  depth = 0
}

# The codes of the styles open from level <from> up, outermost first.
function codes(from,   i, all, bright, value) {
  all = ""
  bright = 0
  for (i = 1; i <= depth; i++) {
    if (stack[i] == "bright") bright = 1
    if (i < from || !(stack[i] in code)) continue
    value = code[stack[i]]
    if (bright && value >= 31 && value <= 37) value += 60
    all = all "\033[" value "m"
  }
  return all
}

# <text>, after the codes it needs: only the styles opened since the last text
# when none was closed, else a reset and every style still open.
function write(text) {
  if (text == "") return
  if (styled && changed) {
    if (closed) {
      opened = codes(1)
      out = out (active ? "\033[0m" : "") opened
      active = opened != ""
    } else {
      opened = codes(shown + 1)
      out = out opened
      active = active || opened != ""
    }
    shown = depth
    changed = 0
    closed = 0
  }
  out = out text
}

{
  line = $0
  out = ""
  changed = depth > 0
  closed = 0
  shown = 0
  active = 0
  while ((at = match(line, MARK)) > 0) {
    write(substr(line, 1, at - 1))
    mark = substr(line, at, 1)
    line = substr(line, at + 1)
    if (mark == OPEN) {
      ends = index(line, NAME_END)
      stack[++depth] = substr(line, 1, ends - 1)
      line = substr(line, ends + 1)
      if (stack[depth] == "bright") for (level = 1; level < depth; level++) if (code[stack[level]] >= 31 && code[stack[level]] <= 37) closed = 1
    } else if (depth > 0) {
      depth--
      if (depth < shown) closed = 1
    }
    changed = 1
  }
  write(line)
  if (styled && active) out = out "\033[0m"
  print out
}
