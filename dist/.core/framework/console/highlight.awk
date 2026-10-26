# Styles a line of dotdot's output at a terminal: commands (bash dot <name>
# and the arguments after it) bold cyan, paths gray, "quoted values" italic.
# Each style is closed with its own reset, so the line's other styles stay.
BEGIN {
  COMMAND = "\033[1;36m"; COMMAND_OFF = "\033[22;39m"
  PATH_ON = "\033[90m"; PATH_OFF = "\033[39m"
  VALUE = "\033[3m"; VALUE_OFF = "\033[23m"
}

function is_argument(word) {
  return word ~ /^--?[A-Za-z0-9][A-Za-z0-9=-]*$/ || word ~ /^<[^>]*>(\/<[^>]*>)?$/ || word ~ /^[a-z0-9][a-z0-9-]*\/[a-z0-9][a-z0-9-]*(@[A-Za-z0-9._\/-]+)?$/ \
    || word ~ /^\.\/[^ ]+$/ || word ~ /^#?[0-9]+$/ || word ~ /^[a-z][0-9]+$/ || word ~ /^[0-9]+\.[0-9]+\.[0-9]+$/
}

function bare(word) {
  sub(/[.,;:)!?]+$/, "", word)
  return word
}

function is_path(word,   last) {
  if (word ~ /^\.[A-Za-z][A-Za-z0-9_.-]*$/) return 1
  if (word ~ /^[A-Za-z0-9_-]+\.(md|json|sh|conf|txt|yml|yaml|toml|stub)$/) return 1
  if (word !~ /^[~.]?[A-Za-z0-9_@.*<>-]*(\/[A-Za-z0-9_.@*<>-]*)+$/) return 0
  last = word
  sub(/^.*\//, "", last)
  return word ~ /^[~.]/ || word ~ /\/$/ || last ~ /\./
}

{
  line = $0
  gsub(/"[^"]*"/, VALUE "&" VALUE_OFF, line)
  count = split(line, words, / /)
  out = ""
  command = 0
  for (i = 1; i <= count; i++) {
    word = words[i]
    core = word
    tail = ""
    while (core ~ /[.,;:)!?]$/ && core !~ /^\.\.?$/) {
      tail = substr(core, length(core)) tail
      core = substr(core, 1, length(core) - 1)
    }
    head = ""
    while (core ~ /^[(]/) {
      head = head substr(core, 1, 1)
      core = substr(core, 2)
    }
    if (!command && core == "bash" && words[i + 1] == "dot" && words[i + 2] ~ /^[a-z0-9][a-z0-9:-]*[.,;:)]*$/) {
      command = 1
      word = head COMMAND core tail
      if (tail != "") { word = word COMMAND_OFF; command = 0 }
    } else if (command) {
      if (core == "dot" || words[i - 1] == "dot" || (is_argument(core) && words[i - 1] !~ /[.,;:)]$/)) {
        word = head core tail
      } else {
        out = out COMMAND_OFF
        command = 0
      }
      if (command && core != "dot" && (tail != "" || i == count || !is_argument(bare(words[i + 1])))) {
        word = head core COMMAND_OFF tail
        command = 0
      }
    }
    if (!command && word == words[i] && is_path(core)) word = head PATH_ON core PATH_OFF tail
    out = out (i > 1 ? " " : "") word
  }
  if (command) out = out COMMAND_OFF
  print out
}
