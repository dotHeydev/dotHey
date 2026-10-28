#!/usr/bin/env bash

# Codex reads agents as TOML (.codex/agents/<name>.toml: name, description,
# developer_instructions), not Markdown: each of dotdot's is rendered into
# it, and the project's own are imported back into dotdot's format when
# dotdot owns them. Fields only one format knows (tools, model) don't port.

dot::use framework.helpers.frontmatter

# <text> as a TOML basic string, quotes included: one line, every quote,
# backslash, and control character escaped.
core.harnesses.codex.agents-toml::string() {
  printf '%s' "$1" | awk '
    BEGIN { ORS = "" }
    {
      line = $0
      gsub(/\\/, "\\\\", line)
      gsub(/"/, "\\\"", line)
      gsub(/\t/, "\\t", line)
      gsub(/\r/, "", line)
      gsub(/[\001-\010\013\014\016-\037\177]/, "", line)
      out = out (NR > 1 ? "\\n" : "") line
    }
    END { print "\"" out "\"" }
  '
}

# A frontmatter value without the YAML quotes around it.
core.harnesses.codex.agents-toml::value() {
  local value="$1"
  case "$value" in
    \"*\") value="${value#\"}"; value="${value%\"}" ;;
    \'*\') value="${value#\'}"; value="${value%\'}" ;;
  esac
  printf '%s' "$value"
}

# render <name> <source>: the agent at <source> as Codex's TOML, named after
# its file.
core.harnesses.codex.agents-toml::render() {
  local name="$1" source="$2" description
  description=$(core.harnesses.codex.agents-toml::value "$(framework.helpers.frontmatter::field "$source" description)")
  printf 'name = %s\n' "$(core.harnesses.codex.agents-toml::string "$name")"
  printf 'description = %s\n' "$(core.harnesses.codex.agents-toml::string "${description:-$name}")"
  printf 'developer_instructions = %s\n' "$(core.harnesses.codex.agents-toml::string "$(framework.helpers.frontmatter::body "$source")")"
}

# The top-level <key> of a TOML file, its string decoded: basic ("…") and
# literal ('…') strings, on one line or in triple quotes across several.
core.harnesses.codex.agents-toml::field() {
  awk -v key="$2" '
    function decode(text,   out, i, c, n) {
      out = ""
      for (i = 1; i <= length(text); i++) {
        c = substr(text, i, 1)
        if (c != "\\") { out = out c; continue }
        n = substr(text, ++i, 1)
        if (n == "n") out = out "\n"; else if (n == "t") out = out "\t"; else if (n == "r") out = out ""; else out = out n
      }
      return out
    }
    !inside && $0 ~ "^[ \t]*" key "[ \t]*=" {
      value = $0
      sub("^[ \t]*" key "[ \t]*=[ \t]*", "", value)
      if (substr(value, 1, 3) == "\"\"\"" || substr(value, 1, 3) == "'\'''\'''\''") {
        fence = substr(value, 1, 3); literal = (fence != "\"\"\""); value = substr(value, 4)
        if (index(value, fence)) { text = substr(value, 1, index(value, fence) - 1); print (literal ? text : decode(text)); exit }
        inside = 1; text = value; first = (value == ""); next
      }
      q = substr(value, 1, 1)
      if (q == "\"") { sub(/^"/, "", value); sub(/"[ \t]*(#.*)?$/, "", value); print decode(value); exit }
      if (q == "'\''") { sub(/^'\''/, "", value); sub(/'\''[ \t]*(#.*)?$/, "", value); print value; exit }
      exit
    }
    inside {
      if (index($0, fence)) { line = substr($0, 1, index($0, fence) - 1); text = first ? line : text "\n" line; print (literal ? text : decode(text)); exit }
      text = first ? $0 : text "\n" $0; first = 0
    }
  ' "$1"
}

# <text> as a YAML double-quoted scalar.
core.harnesses.codex.agents-toml::yaml() {
  printf '"%s"' "$(printf '%s' "$1" | tr '\n\t' '  ' | sed 's/\\/\\\\/g; s/"/\\"/g')"
}

# import <name> <file>: the Codex agent at <file> in dotdot's format.
core.harnesses.codex.agents-toml::import() {
  local name="$1" file="$2" description instructions
  instructions=$(core.harnesses.codex.agents-toml::field "$file" developer_instructions)
  [ -n "$instructions" ] || return 1
  description=$(core.harnesses.codex.agents-toml::field "$file" description)
  printf -- '---\nname: %s\ndescription: %s\n---\n\n%s\n' "$name" "$(core.harnesses.codex.agents-toml::yaml "${description:-$name}")" "$instructions"
}
