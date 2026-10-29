# A help page, plain, as tab-separated rows for kernel::help_fields, so its
# JSON says what the page does: "about" (the text before the first section),
# "usage" and "example" rows (a line ending in \, or indented under a usage
# line, continues it), "argument" and "option" rows (name, description;
# deeper-indented lines continue the description), "note" rows (one per
# "- " item of Notes), and a "section" row for any other section (its title,
# then its lines). About and note rows hold their text as the name; breaks
# within a text are written as BREAK.
function flush() {
  if (kind != "") print kind "\t" name "\t" text
  kind = ""; name = ""; text = ""
}
function trim(value) { sub(/^[ \t]+/, "", value); sub(/[ \t]+$/, "", value); return value }
BEGIN { BREAK = sprintf("%c", 30) }
/^[A-Z][^:]*:$/ {
  flush()
  section = $0
  if (section != "Usage:" && section != "Examples:" && section != "Arguments:" && section != "Options:" && section != "Notes:" && section != "Docs:") {
    kind = "section"; name = substr(section, 1, length(section) - 1)
  }
  next
}
section == "" {
  line = trim($0)
  if (line == "") { if (name != "") name = name BREAK BREAK; next }
  if (kind == "") kind = "about"
  name = name (name == "" || name ~ BREAK "$" ? "" : " ") line
  next
}
/^[ \t]*$/ {
  if (kind == "section") { text = text BREAK; next }
  if (section != "Usage:" && section != "Examples:") flush()
  next
}
section == "Usage:" || section == "Examples:" {
  line = trim($0)
  if (kind != "" && (joined || line !~ /^bash dot /)) {
    name = name " " line
  } else {
    flush(); kind = section == "Usage:" ? "usage" : "example"; name = line
  }
  joined = sub(/ *\\$/, "", name)
  next
}
section == "Arguments:" || section == "Options:" {
  if ($0 ~ /^  [^ ]/) {
    flush()
    kind = section == "Arguments:" ? "argument" : "option"
    line = substr($0, 3)
    if (match(line, /  +/)) { name = substr(line, 1, RSTART - 1); text = trim(substr(line, RSTART)) }
    else name = line
  } else if (kind != "") {
    text = trim(text " " trim($0))
  }
  next
}
section == "Notes:" {
  line = trim($0)
  if (line ~ /^- /) { flush(); kind = "note"; name = substr(line, 3) }
  else if (kind != "") name = name " " line
  next
}
kind == "section" {
  line = $0
  sub(/^  /, "", line)
  sub(/[ \t]+$/, "", line)
  text = text (text == "" ? "" : BREAK) line
  next
}
END { flush() }
