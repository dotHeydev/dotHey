# Marks up a line of dotdot's output for render.awk, by what its words look
# like: commands (bash dot <name> and the arguments after it) bold bright,
# paths gray, "quoted values" italic, plugin ids (acme/widgets) and record and
# task references (d002, t004, #12) bold. A word already marked up is left as
# it is.
BEGIN {
  OPEN = sprintf("%c", 1); NAME_END = sprintf("%c", 2); CLOSE = sprintf("%c", 3)
  COMMAND = OPEN "bold" NAME_END OPEN "bright" NAME_END; COMMAND_OFF = CLOSE CLOSE
  PATH_ON = OPEN "gray" NAME_END; PATH_OFF = CLOSE
  VALUE = OPEN "italic" NAME_END; VALUE_OFF = CLOSE
  REFERENCE = OPEN "bold" NAME_END; REFERENCE_OFF = CLOSE
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

# A line holding only a command (a usage line, an example) is all command,
# whatever its arguments look like; a trailing "# comment" stays as it is.
/^ *bash dot [a-z]/ {
  line = $0
  indent = line
  sub(/[^ ].*$/, "", indent)
  rest = substr(line, length(indent) + 1)
  comment = ""
  if (match(rest, / +# /)) { comment = substr(rest, RSTART); rest = substr(rest, 1, RSTART - 1) }
  print indent COMMAND rest COMMAND_OFF comment
  next
}

{
  line = $0
  gsub(/"[^"\001\002\003]*"/, VALUE "&" VALUE_OFF, line)
  count = split(line, words, / /)
  out = ""
  command = 0
  for (i = 1; i <= count; i++) {
    word = words[i]
    core = word
    tail = ""
    while ((core ~ /[.,;:)!?]$/ && core !~ /^\.\.?$/) || substr(core, length(core)) == CLOSE) {
      tail = substr(core, length(core)) tail
      core = substr(core, 1, length(core) - 1)
    }
    head = ""
    while (core ~ /^[(]/ || substr(core, 1, 1) == OPEN) {
      if (substr(core, 1, 1) == OPEN) {
        ends = index(core, NAME_END)
        head = head substr(core, 1, ends)
        core = substr(core, ends + 1)
      } else {
        head = head substr(core, 1, 1)
        core = substr(core, 2)
      }
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
    else if (!command && word == words[i] && (core ~ /^[dfntx][0-9][0-9][0-9]$/ || core ~ /^#[0-9]+$/ || core ~ /^[a-z0-9][a-z0-9-]*\/[a-z0-9][a-z0-9-]*$/)) word = head REFERENCE core REFERENCE_OFF tail
    out = out (i > 1 ? " " : "") word
  }
  if (command) out = out COMMAND_OFF
  print out
}
