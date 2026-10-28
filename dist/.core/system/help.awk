# A command's plain help, as tab-separated rows for kernel::help_json:
# "usage" and "example" rows (a line ending in \, or indented under a usage
# line, continues it), and "argument" and "option" rows (name, description;
# deeper-indented lines continue the description). Other sections are skipped.
function flush() {
  if (kind != "") print kind "\t" name "\t" text
  kind = ""; name = ""; text = ""
}
function trim(value) { sub(/^[ \t]+/, "", value); sub(/[ \t]+$/, "", value); return value }
/^[A-Z][^:]*:$/ { flush(); section = $0; next }
/^[ \t]*$/ { if (section != "Usage:" && section != "Examples:") flush(); next }
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
END { flush() }
