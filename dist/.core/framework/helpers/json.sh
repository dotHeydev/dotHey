#!/usr/bin/env bash

# Reading and writing JSON with jq when it is installed, and otherwise with a
# portable awk reader and writer that print exactly what jq does (most Linux
# and Windows systems ship no jq), so nothing here depends on it.

# What <path> selects in <document>, exactly as jq -rc '<path> // empty'
# prints it, one result per line: strings raw, numbers in jq's form (1e2 is
# 1E+2), objects and arrays compact; nothing for null, false, a missing path,
# or bad JSON. A path is ., or a chain of .key, ."key", .["key"], [N], [-N],
# and [] (each element or value): .items[0].name, .["a b"][-1], .links.link[]
framework.helpers.json::values() {
  local document="$1" path="$2"
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$document" | jq -rc "$path // empty" 2>/dev/null || true
  else
    framework.helpers.json::read_values "$document" "$path"
  fi
}

# What <path> selects in <document> as JSON, exactly as jq -c '<path>' prints
# it, one result per line: strings quoted, null for null or a missing path;
# nothing for bad JSON.
framework.helpers.json::encoded() {
  local document="$1" path="$2"
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$document" | jq -c "$path" 2>/dev/null || true
  else
    framework.helpers.json::read "$document" "$path" encoded
  fi
}

# The keys of the object at <path> in <document>, in document order, exactly
# as jq -r '<path> | keys_unsorted[]' prints them, one per line (a list's
# indexes); nothing for anything else, a missing path, or bad JSON.
framework.helpers.json::keys() {
  local document="$1" path="$2"
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$document" | jq -r "$path | keys_unsorted[]" 2>/dev/null || true
  else
    framework.helpers.json::read "$document" "$path" keys
  fi
}

# Every key <document> defines twice in one object, as its keys from the
# root, tab-separated, once per repeat: JSON readers, jq included, keep only
# the last, so the earlier value is silently lost. jq has no such check, so
# this always reads with the awk reader.
framework.helpers.json::duplicate_keys() {
  framework.helpers.json::read "$1" . duplicates
}

# <document> with each key defined twice in one object merged into its first
# definition and the later ones cut, the rest of the text left as written:
# lists are joined, each element once, objects member by member, equal
# values kept once. With <prefix> (keys from the root, tab-separated), only
# the objects at or under it. Fails, printing nothing, on bad JSON, values
# that can't be merged (two different texts, a list and an object), or a
# pair inside another; jq has no such edit, so this always uses the awk reader.
framework.helpers.json::merge_duplicates() {
  local output
  output=$(framework.helpers.json::read "$1" . merge_duplicates "${2-}") || return 1
  [ -n "$output" ] || return 1
  printf '%s\n' "$output"
}

# The single value at <path>, as values prints it, control characters removed.
framework.helpers.json::field() {
  framework.helpers.json::values "$1" "$2" | LC_ALL=C tr -d '[:cntrl:]'
}

# Every scalar in <document> as "<key or index>\t…\t<value>", in document
# order, exactly as jq -r 'paths(scalars) as $p | ($p | map(tostring) |
# join("\t")) + "\t" + (getpath($p) | tostring)' prints it (null and false
# left out, as there).
framework.helpers.json::leaves() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$1" | jq -r 'paths(scalars) as $p | ($p | map(tostring) | join("\t")) + "\t" + (getpath($p) | tostring)' 2>/dev/null || true
  else
    framework.helpers.json::read_leaves "$1"
  fi
}

# <document> with the value at <path> set to <json>, exactly as
# jq --argjson value <json> '<path> = $value' prints it (pretty, the whole
# document rewritten); with --keep-format, only that value's text is replaced,
# or the missing member inserted after its siblings, and everything else is
# left as written; adding --before <key> too places a new member right before
# its sibling <key>, when there is one. Fails, printing nothing, on bad JSON,
# a path with [], or a type mismatch.
framework.helpers.json::set() {
  local document="$1" path="$2" value="$3" output
  if [ "${4-}" = --keep-format ] && [ "${5-}" = --before ]; then
    output=$(framework.helpers.json::read "$document" "$path" set_before "$value" "${6-}") || return 1
  elif [ "${4-}" = --keep-format ]; then
    output=$(framework.helpers.json::read "$document" "$path" set_keep "$value") || return 1
  elif command -v jq >/dev/null 2>&1; then
    output=$(printf '%s' "$document" | jq --argjson value "$value" "$path = \$value" 2>/dev/null) || return 1
  else
    output=$(framework.helpers.json::read "$document" "$path" set "$value") || return 1
  fi
  printf '%s\n' "$output"
}

# <document> without what <path> names, exactly as jq 'del(<path>)' prints
# it; with --keep-format, only that member or element and its comma are cut.
framework.helpers.json::delete() {
  local document="$1" path="$2" output
  if [ "${3-}" = --keep-format ]; then
    output=$(framework.helpers.json::read "$document" "$path" delete_keep) || return 1
  elif command -v jq >/dev/null 2>&1; then
    output=$(printf '%s' "$document" | jq "del($path)" 2>/dev/null) || return 1
  else
    output=$(framework.helpers.json::read "$document" "$path" delete) || return 1
  fi
  printf '%s\n' "$output"
}

# Each line of stdin as a JSON string literal, exactly as jq -R . prints it.
framework.helpers.json::lines() {
  if command -v jq >/dev/null 2>&1; then
    jq -R .
  else
    LC_ALL=C awk "$JSON_AWK_LIBRARY"'
      BEGIN { json_init() }
      { printf "%s\n", quote(repair($0)) }
    '
  fi
}

# <text> as a JSON string literal, quotes included, exactly as jq -Rs . prints it.
framework.helpers.json::string() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$1" | jq -Rs .
  else
    framework.helpers.json::write_string "$1"
  fi
}

# Shared by the reader and the writer, run with LC_ALL=C so text is bytes:
# repairing UTF-8 as jq does (each bad sequence becomes U+FFFD) and escaping a
# string as jq writes it.
JSON_AWK_LIBRARY='
  function json_init(   code) {
    for (code = 1; code < 256; code++) ORD[sprintf("%c", code)] = code
    REPLACEMENT = sprintf("%c%c%c", 239, 191, 189)
    NUL = sprintf("%c", 255)
  }
  function utf8(code) {
    if (code < 128) return sprintf("%c", code)
    if (code < 2048) return sprintf("%c%c", 192 + int(code / 64), 128 + code % 64)
    if (code < 65536) return sprintf("%c%c%c", 224 + int(code / 4096), 128 + int(code / 64) % 64, 128 + code % 64)
    return sprintf("%c%c%c%c", 240 + int(code / 262144), 128 + int(code / 4096) % 64, 128 + int(code / 64) % 64, 128 + code % 64)
  }
  # The valid UTF-8 sequence starting at byte <at> of <bytes>, or U+FFFD for
  # a bad one; sets UTF8_USED to the bytes it took.
  function utf8_next(bytes, at,   lead, size, code, i, byte) {
    lead = ORD[substr(bytes, at, 1)]
    UTF8_USED = 1
    if (lead < 128) return substr(bytes, at, 1)
    if (lead >= 194 && lead <= 223) { size = 2; code = lead - 192 }
    else if (lead >= 224 && lead <= 239) { size = 3; code = lead - 224 }
    else if (lead >= 240 && lead <= 244) { size = 4; code = lead - 240 }
    else return REPLACEMENT
    for (i = 1; i < size; i++) {
      byte = ORD[substr(bytes, at + i, 1)]
      if (byte < 128 || byte > 191) { UTF8_USED = i; return REPLACEMENT }
      code = code * 64 + byte - 128
    }
    UTF8_USED = size
    if ((size == 3 && code < 2048) || (size == 4 && code < 65536) || code > 1114111 || (code >= 55296 && code < 57344)) return REPLACEMENT
    return substr(bytes, at, size)
  }
  function repair(bytes,   out, at, count) {
    out = ""
    count = length(bytes)
    for (at = 1; at <= count; at += UTF8_USED) out = out utf8_next(bytes, at)
    return out
  }
  function quote(text,   out, i, count, char, code) {
    out = ""
    count = length(text)
    for (i = 1; i <= count; i++) {
      char = substr(text, i, 1)
      code = ORD[char]
      if (char == NUL) out = out "\\u0000"
      else if (char == "\"") out = out "\\\""
      else if (char == "\\") out = out "\\\\"
      else if (char == "\n") out = out "\\n"
      else if (char == "\t") out = out "\\t"
      else if (char == "\r") out = out "\\r"
      else if (code == 8) out = out "\\b"
      else if (code == 12) out = out "\\f"
      else if (code < 32 || code == 127) out = out sprintf("\\u%04x", code)
      else out = out char
    }
    return "\"" out "\""
  }
'

# The awk reader behind values: parses the whole document (a stream of them,
# as jq reads it) with jq's leniency, then prints what the path selects.
framework.helpers.json::read_values() {
  framework.helpers.json::read "$1" "$2" values
}

# The awk reader behind leaves.
framework.helpers.json::read_leaves() {
  framework.helpers.json::read "$1" . leaves
}

framework.helpers.json::read() {
  printf '%s' "$1" | JSON_PATH="$2" JSON_MODE="$3" JSON_VALUE="${4-}" JSON_BEFORE="${5-}" LC_ALL=C awk "$JSON_AWK_LIBRARY"'
    function fail() { failed = 1 }
    function blank() { while (pos <= size && index(" \t\n\r", substr(text, pos, 1))) pos++ }
    function hex(digits,   value, i, digit) {
      if (length(digits) < 4) { fail(); return 0 }
      value = 0
      for (i = 1; i <= 4; i++) {
        digit = index("0123456789abcdef", tolower(substr(digits, i, 1))) - 1
        if (digit < 0) { fail(); return 0 }
        value = value * 16 + digit
      }
      return value
    }
    # A string at pos, decoded; raw control characters, bad escapes, and lone
    # high surrogates fail as in jq, a lone low surrogate and bad UTF-8 become
    # U+FFFD.
    function read_string(   out, char, code, low) {
      out = ""
      pos++
      while (pos <= size) {
        char = substr(text, pos, 1)
        if (char == "\"") { pos++; return out }
        if (ORD[char] < 32) { fail(); return "" }
        if (char != "\\") { out = out utf8_next(text, pos); pos += UTF8_USED; continue }
        pos++
        char = substr(text, pos, 1)
        pos++
        if (char == "\"" || char == "\\" || char == "/") out = out char
        else if (char == "n") out = out "\n"
        else if (char == "t") out = out "\t"
        else if (char == "r") out = out "\r"
        else if (char == "b") out = out sprintf("%c", 8)
        else if (char == "f") out = out sprintf("%c", 12)
        else if (char == "u") {
          code = hex(substr(text, pos, 4))
          pos += 4
          if (failed) return ""
          if (code >= 55296 && code < 56320) {
            if (substr(text, pos, 2) != "\\u") { fail(); return "" }
            low = hex(substr(text, pos + 2, 4))
            if (failed || low < 56320 || low >= 57344) { fail(); return "" }
            code = 65536 + (code - 55296) * 1024 + (low - 56320)
            pos += 6
          }
          if (code >= 56320 && code < 57344) out = out REPLACEMENT
          else if (code == 0) out = out NUL
          else out = out utf8(code)
        }
        else { fail(); return "" }
      }
      fail()
      return ""
    }
    # A number as jq prints a literal it keeps: the coefficient without
    # leading zeros and the exponent, in plain notation while the exponent is
    # not positive and the adjusted exponent at least -6, else d.dddE+x.
    function canonical(literal,   sign, mantissa, exponent, whole, fraction, at, digits, adjusted, point, zeros) {
      sign = ""
      if (substr(literal, 1, 1) == "-") { sign = "-"; literal = substr(literal, 2) }
      else if (substr(literal, 1, 1) == "+") literal = substr(literal, 2)
      exponent = 0
      at = match(literal, /[eE]/)
      mantissa = at ? substr(literal, 1, at - 1) : literal
      if (at) exponent = substr(literal, at + 1) + 0
      at = index(mantissa, ".")
      whole = at ? substr(mantissa, 1, at - 1) : mantissa
      fraction = at ? substr(mantissa, at + 1) : ""
      digits = whole fraction
      exponent -= length(fraction)
      sub(/^0+/, "", digits)
      if (digits == "") digits = "0"
      adjusted = exponent + length(digits) - 1
      if (exponent <= 0 && adjusted >= -6) {
        if (exponent == 0) return sign digits
        point = length(digits) + exponent
        if (point > 0) return sign substr(digits, 1, point) "." substr(digits, point + 1)
        zeros = ""
        while (point++ < 0) zeros = zeros "0"
        return sign "0." zeros digits
      }
      return sign substr(digits, 1, 1) (length(digits) > 1 ? "." substr(digits, 2) : "") "E" (adjusted >= 0 ? "+" : "-") (adjusted < 0 ? -adjusted : adjusted)
    }
    function literal(token,   lower) {
      lower = tolower(token)
      sub(/^[-+]/, "", lower)
      if (token == "true") return node("t", "true")
      if (token == "false") return node("f", "")
      if (token == "null") return node("z", "")
      if (lower == "nan") return node("n", "null")
      if (lower == "infinity") return node("n", (substr(token, 1, 1) == "-" ? "-" : "") "1.7976931348623157e+308")
      if (token ~ /^[-+]?([0-9]+\.?[0-9]*|\.[0-9]+)([eE][-+]?[0-9]+)?$/) return node("n", canonical(token))
      fail()
      return 0
    }
    function node(type, value) { TYPE[++nodes] = type; VALUE[nodes] = value; COUNT[nodes] = 0; return nodes }
    # The value at pos, as a node whose SPAN_START and SPAN_END hold its span in text;
    # a member of an object also has KEY_START, where its key begins.
    function value_at(   id, start) {
      blank()
      start = pos
      id = parse_value(start)
      if (id) { SPAN_START[id] = start; SPAN_END[id] = pos }
      return id
    }
    function parse_value(start,   char, id, key, child, slot, key_start) {
      if (pos > size) { fail(); return 0 }
      char = substr(text, pos, 1)
      if (char == "\"") { key = read_string(); return failed ? 0 : node("s", key) }
      if (char == "[" || char == "{") {
        id = node(char == "[" ? "a" : "o", "")
        pos++
        blank()
        if (substr(text, pos, 1) == (char == "[" ? "]" : "}")) { pos++; return id }
        while (!failed) {
          blank()
          key_start = pos
          if (char == "{") {
            if (substr(text, pos, 1) != "\"") { fail(); return 0 }
            key = read_string()
            blank()
            if (failed || substr(text, pos, 1) != ":") { fail(); return 0 }
            pos++
          }
          child = value_at()
          if (failed) return 0
          PARENT[child] = id
          STEP_OF[child] = char == "{" ? key : COUNT[id]
          if (char == "{" && (id SUBSEP key) in SLOT) {
            CHILD[id, SLOT[id, key]] = child
            DUPLICATE[++duplicates] = child
            OCCURRENCE[id, key, ++OCCURRENCES[id, key]] = child
            CUT_FROM[duplicates] = LAST_END[id]
          } else {
            slot = ++COUNT[id]
            CHILD[id, slot] = child
            KEY_START[id, slot] = key_start
            if (char == "{") { KEY[id, slot] = key; SLOT[id, key] = slot; OCCURRENCE[id, key, 1] = child; OCCURRENCES[id, key] = 1 }
          }
          LAST_END[id] = SPAN_END[child]
          blank()
          if (substr(text, pos, 1) == ",") { pos++; continue }
          if (substr(text, pos, 1) == (char == "[" ? "]" : "}")) { pos++; return id }
          fail()
          return 0
        }
        return 0
      }
      while (pos <= size && !index(" \t\n\r,:[]{}\"", substr(text, pos, 1))) pos++
      if (pos == start) { fail(); return 0 }
      return literal(substr(text, start, pos - start))
    }
    function dump(id,   out, i) {
      if (TYPE[id] == "s") return quote(VALUE[id])
      if (TYPE[id] == "f") return "false"
      if (TYPE[id] == "z") return "null"
      if (TYPE[id] == "a" || TYPE[id] == "o") {
        out = ""
        for (i = 1; i <= COUNT[id]; i++) out = out (i > 1 ? "," : "") (TYPE[id] == "o" ? quote(KEY[id, i]) ":" : "") dump(CHILD[id, i])
        return TYPE[id] == "a" ? "[" out "]" : "{" out "}"
      }
      return VALUE[id]
    }
    # <a> and <b> as one value, or 0 when they cannot be: lists joined, each
    # element once; objects joined member by member, a key both hold merged;
    # anything else only when equal.
    function merge_nodes(a, b,   id, i, key, merged) {
      if (dump(a) == dump(b)) return a
      if (TYPE[a] == "a" && TYPE[b] == "a") {
        id = node("a", "")
        for (i = 1; i <= COUNT[a]; i++) add_unique(id, CHILD[a, i])
        for (i = 1; i <= COUNT[b]; i++) add_unique(id, CHILD[b, i])
        return id
      }
      if (TYPE[a] != "o" || TYPE[b] != "o") return 0
      id = node("o", "")
      for (i = 1; i <= COUNT[a]; i++) {
        key = KEY[a, i]
        merged = (b SUBSEP key) in SLOT ? merge_nodes(CHILD[a, i], CHILD[b, SLOT[b, key]]) : CHILD[a, i]
        if (!merged) return 0
        add_member(id, key, merged)
      }
      for (i = 1; i <= COUNT[b]; i++) if (!((a SUBSEP KEY[b, i]) in SLOT)) add_member(id, KEY[b, i], CHILD[b, i])
      return id
    }
    function add_unique(id, child,   i) {
      for (i = 1; i <= COUNT[id]; i++) if (dump(CHILD[id, i]) == dump(child)) return
      CHILD[id, ++COUNT[id]] = child
    }
    function add_member(id, key, child,   slot) {
      slot = ++COUNT[id]
      CHILD[id, slot] = child; KEY[id, slot] = key; SLOT[id, key] = slot
    }
    # The text with each key defined twice in an object under <prefix> (its
    # keys from the root, tab-separated; empty for all) merged into its first
    # definition and the later ones cut, the rest left as written; fails when
    # a pair cannot be merged or one lies inside another.
    function merge_duplicates(prefix,   i, child, object, key, first, merged, n, j, edits, out, path) {
      edits = 0
      for (i = 1; i <= duplicates; i++) {
        child = DUPLICATE[i]
        object = PARENT[child]
        key = STEP_OF[child]
        path = steps_to(object)
        if (prefix != "" && path != prefix && index(path, prefix "\t") != 1) continue
        EDIT_FROM[++edits] = CUT_FROM[i]; EDIT_TO[edits] = SPAN_END[child]; EDIT_TEXT[edits] = ""
        if ((object SUBSEP key) in GROUP_DONE) continue
        GROUP_DONE[object, key] = 1
        first = OCCURRENCE[object, key, 1]
        merged = first
        n = OCCURRENCES[object, key]
        for (j = 2; j <= n; j++) { merged = merge_nodes(merged, OCCURRENCE[object, key, j]); if (!merged) exit 3 }
        EDIT_FROM[++edits] = SPAN_START[first]; EDIT_TO[edits] = SPAN_END[first]
        if (index(substr(input, SPAN_START[first], SPAN_END[first] - SPAN_START[first]), "\n")) EDIT_TEXT[edits] = reindent(pretty(merged, ""), indent_at(SPAN_START[first]))
        else EDIT_TEXT[edits] = dump(merged)
      }
      for (i = 1; i <= edits; i++) for (j = 1; j <= edits; j++)
        if (i != j && EDIT_FROM[j] < EDIT_TO[i] && EDIT_FROM[i] < EDIT_TO[j]) exit 4
      out = input
      for (n = edits; n > 0; n--) {
        j = 0
        for (i = 1; i <= edits; i++) if (!(i in APPLIED) && (!j || EDIT_FROM[i] > EDIT_FROM[j])) j = i
        APPLIED[j] = 1
        out = substr(out, 1, EDIT_FROM[j] - 1) EDIT_TEXT[j] substr(out, EDIT_TO[j])
      }
      printf "%s\n", out
      done = 1
    }
    # The keys leading from the root to <id>, tab-separated.
    function steps_to(id,   out) {
      out = ""
      while (id in PARENT) { out = (out == "" ? STEP_OF[id] : STEP_OF[id] "\t" out); id = PARENT[id] }
      return out
    }
    # Applies the path from <step> on to <id> depth first, as jq does: .key
    # and [N] give null on null and a missing key or index, [] gives each
    # element or value; anything else is an error, which ends this document.
    function select(id, step,   wanted, slot, i) {
      if (stopped) return
      if (step > steps) { show(id); return }
      wanted = STEP[step]
      if (STEP_KIND[step] == "iterate") {
        if (TYPE[id] != "a" && TYPE[id] != "o") { stopped = 1; return }
        for (i = 1; i <= COUNT[id] && !stopped; i++) select(CHILD[id, i], step + 1)
        return
      }
      if (TYPE[id] == "z") { select(id, step + 1); return }
      if (STEP_KIND[step] == "key") {
        if (TYPE[id] != "o") { stopped = 1; return }
        select((id SUBSEP wanted) in SLOT ? CHILD[id, SLOT[id, wanted]] : null, step + 1)
        return
      }
      if (TYPE[id] != "a") { stopped = 1; return }
      slot = wanted + 0
      if (slot < 0) slot += COUNT[id]
      select(slot >= 0 && slot < COUNT[id] ? CHILD[id, slot + 1] : null, step + 1)
    }
    # Every scalar under <id> but null and false, as its path and value.
    function leaves(id, prefix, depth,   i, step, value, parts, count) {
      if (TYPE[id] == "a" || TYPE[id] == "o") {
        for (i = 1; i <= COUNT[id]; i++) {
          step = TYPE[id] == "o" ? KEY[id, i] : i - 1
          leaves(CHILD[id, i], depth ? prefix "\t" step : step, depth + 1)
        }
        return
      }
      if (!depth || TYPE[id] == "z" || TYPE[id] == "f") return
      value = TYPE[id] == "s" ? VALUE[id] : dump(id)
      count = split(value, parts, NUL)
      printf "%s\t", prefix
      for (i = 1; i <= count; i++) { if (i > 1) printf "%c", 0; printf "%s", parts[i] }
      printf "\n"
    }
    function show(id,   value, parts, count, i, j) {
      if (mode == "encoded") { printf "%s\n", dump(id); return }
      if (mode == "keys") {
        if (TYPE[id] == "o") for (i = 1; i <= COUNT[id]; i++) { count = split(KEY[id, i], parts, NUL); for (j = 1; j <= count; j++) { if (j > 1) printf "%c", 0; printf "%s", parts[j] } printf "\n" }
        else if (TYPE[id] == "a") for (i = 1; i <= COUNT[id]; i++) printf "%d\n", i - 1
        return
      }
      if (TYPE[id] == "z" || TYPE[id] == "f") return
      if (TYPE[id] != "s") { printf "%s\n", dump(id); return }
      count = split(VALUE[id], parts, NUL)
      for (i = 1; i <= count; i++) { if (i > 1) printf "%c", 0; printf "%s", parts[i] }
      printf "\n"
    }
    # <id> as jq prints it by default: two spaces per level, a member or
    # element per line, empty objects and arrays inline.
    function pretty(id, indent,   out, i, inner) {
      if ((TYPE[id] != "a" && TYPE[id] != "o") || !COUNT[id]) return dump(id)
      inner = indent "  "
      out = ""
      for (i = 1; i <= COUNT[id]; i++) out = out (i > 1 ? "," : "") "\n" inner (TYPE[id] == "o" ? quote(KEY[id, i]) ": " : "") pretty(CHILD[id, i], inner)
      return (TYPE[id] == "a" ? "[" : "{") out "\n" indent (TYPE[id] == "a" ? "]" : "}")
    }
    # <id> with the path from <step> set to <value>, as jq setpath does:
    # null becomes an object or array as needed, a missing key is added last,
    # an array grows with nulls; a type mismatch fails.
    function set_tree(id, step, value,   wanted, slot) {
      if (step > steps) return value
      wanted = STEP[step]
      if (STEP_KIND[step] == "key") {
        if (TYPE[id] == "z") id = node("o", "")
        if (TYPE[id] != "o") { fail(); return id }
        if ((id SUBSEP wanted) in SLOT) slot = SLOT[id, wanted]
        else { slot = ++COUNT[id]; KEY[id, slot] = wanted; SLOT[id, wanted] = slot; CHILD[id, slot] = null }
        CHILD[id, slot] = set_tree(CHILD[id, slot], step + 1, value)
        return id
      }
      if (TYPE[id] == "z") id = node("a", "")
      if (TYPE[id] != "a") { fail(); return id }
      slot = wanted + 0
      if (slot < 0) slot += COUNT[id]
      if (slot < 0) { fail(); return id }
      while (COUNT[id] <= slot) CHILD[id, ++COUNT[id]] = null
      CHILD[id, slot + 1] = set_tree(CHILD[id, slot + 1], step + 1, value)
      return id
    }
    # <id> without what the path names, as jq del does: nothing missing
    # changes; a type mismatch fails.
    function delete_tree(id, step,   wanted, slot, i) {
      if (TYPE[id] == "z") return
      wanted = STEP[step]
      if (STEP_KIND[step] == "key") {
        if (TYPE[id] != "o") { fail(); return }
        if (!((id SUBSEP wanted) in SLOT)) return
        slot = SLOT[id, wanted]
      } else {
        if (TYPE[id] != "a") { fail(); return }
        slot = wanted + 1
        if (slot < 1) slot += COUNT[id]
        if (slot < 1 || slot > COUNT[id]) return
      }
      if (step < steps) { delete_tree(CHILD[id, slot], step + 1); return }
      if (TYPE[id] == "o") delete SLOT[id, KEY[id, slot]]
      for (i = slot; i < COUNT[id]; i++) {
        CHILD[id, i] = CHILD[id, i + 1]; KEY[id, i] = KEY[id, i + 1]; KEY_START[id, i] = KEY_START[id, i + 1]
        if (TYPE[id] == "o") SLOT[id, KEY[id, i]] = i
      }
      COUNT[id]--
    }
    # The leading blanks of the line <at> is on.
    function indent_at(at,   start) {
      start = at
      while (start > 1 && substr(input, start - 1, 1) != "\n") start--
      match(substr(input, start), /^[ \t]*/)
      return substr(input, start, RLENGTH)
    }
    function reindent(value, indent) {
      gsub(/\n/, "\n" indent, value)
      return value
    }
    function splice(from, to, replacement) {
      printf "%s\n", substr(input, 1, from - 1) replacement substr(input, to)
      done = 1
    }
    # set, keeping the text as written: only the value at the path is
    # replaced, or the missing member inserted after its siblings.
    function keep_set(id, value,   step, wanted, slot, last, indent, inner, i) {
      for (step = 1; step <= steps; step++) {
        wanted = STEP[step]
        if (STEP_KIND[step] == "key") {
          if (TYPE[id] != "o") { fail(); return }
          if (!((id SUBSEP wanted) in SLOT)) break
          id = CHILD[id, SLOT[id, wanted]]
        } else {
          if (TYPE[id] != "a") { fail(); return }
          slot = wanted + 0
          if (slot < 0) slot += COUNT[id]
          if (slot < 0 || slot >= COUNT[id]) { fail(); return }
          id = CHILD[id, slot + 1]
        }
      }
      if (step > steps) { splice(SPAN_START[id], SPAN_END[id], reindent(value, indent_at(SPAN_START[id]))); return }
      for (i = steps; i > step; i--) {
        if (STEP_KIND[i] != "key") { fail(); return }
        value = "{" quote(STEP[i]) ": " value "}"
      }
      last = COUNT[id]
      if (!last) {
        indent = indent_at(SPAN_START[id])
        inner = indent "  "
        splice(SPAN_START[id], SPAN_END[id], "{\n" inner quote(wanted) ": " reindent(value, inner) "\n" indent "}")
        return
      }
      if (!index(substr(input, SPAN_START[id], KEY_START[id, last] - SPAN_START[id]), "\n")) {
        splice(SPAN_END[CHILD[id, last]], SPAN_END[CHILD[id, last]], ", " quote(wanted) ": " value)
        return
      }
      inner = indent_at(KEY_START[id, last])
      splice(SPAN_END[CHILD[id, last]], SPAN_END[CHILD[id, last]], ",\n" inner quote(wanted) ": " reindent(value, inner))
    }
    # set, keeping the text as written, a new member placed right before its
    # sibling <before> when that is there; otherwise as keep_set does.
    function keep_insert(root, value, before,   id, step, wanted, slot, at, indent) {
      id = root
      for (step = 1; step < steps; step++) {
        wanted = STEP[step]
        if (STEP_KIND[step] == "key") {
          if (TYPE[id] != "o" || !((id SUBSEP wanted) in SLOT)) { keep_set(root, value); return }
          id = CHILD[id, SLOT[id, wanted]]
        } else {
          slot = wanted + 0
          if (TYPE[id] != "a") { keep_set(root, value); return }
          if (slot < 0) slot += COUNT[id]
          if (slot < 0 || slot >= COUNT[id]) { keep_set(root, value); return }
          id = CHILD[id, slot + 1]
        }
      }
      wanted = STEP[steps]
      if (STEP_KIND[steps] != "key" || TYPE[id] != "o" || (id SUBSEP wanted) in SLOT || !((id SUBSEP before) in SLOT)) { keep_set(root, value); return }
      at = KEY_START[id, SLOT[id, before]]
      if (index(substr(input, SPAN_START[id], at - SPAN_START[id]), "\n")) {
        indent = indent_at(at)
        splice(at, at, quote(wanted) ": " reindent(value, indent) ",\n" indent)
      } else splice(at, at, quote(wanted) ": " value ", ")
    }
    # del, keeping the text as written: only the member or element and its
    # comma are cut.
    function keep_delete(id,   step, wanted, slot, parent) {
      for (step = 1; step <= steps; step++) {
        if (TYPE[id] == "z") return
        wanted = STEP[step]
        if (STEP_KIND[step] == "key") {
          if (TYPE[id] != "o") { fail(); return }
          if (!((id SUBSEP wanted) in SLOT)) return
          slot = SLOT[id, wanted]
        } else {
          if (TYPE[id] != "a") { fail(); return }
          slot = wanted + 1
          if (slot < 1) slot += COUNT[id]
          if (slot < 1 || slot > COUNT[id]) return
        }
        parent = id
        id = CHILD[id, slot]
      }
      if (COUNT[parent] == 1) splice(SPAN_START[parent], SPAN_END[parent], TYPE[parent] == "o" ? "{}" : "[]")
      else if (slot > 1) splice(SPAN_END[CHILD[parent, slot - 1]], SPAN_END[id], "")
      else splice(KEY_START[parent, 1], KEY_START[parent, 2], "")
    }
    # The path into STEP and STEP_KIND, read with the string reader; anything
    # outside the supported grammar fails, as jq would not compile it.
    function read_path(   char, ident) {
      text = ENVIRON["JSON_PATH"]
      size = length(text)
      pos = 1
      steps = 0
      if (text == ".") return 1
      while (pos <= size) {
        char = substr(text, pos, 1)
        if (char == ".") {
          pos++
          char = substr(text, pos, 1)
          if (char == "\"") { STEP[++steps] = read_string(); STEP_KIND[steps] = "key"; if (failed) return 0; continue }
          if (char == "[") continue
          if (!match(substr(text, pos), /^[A-Za-z_][A-Za-z0-9_]*/)) return 0
          STEP[++steps] = substr(text, pos, RLENGTH); STEP_KIND[steps] = "key"
          pos += RLENGTH
          continue
        }
        if ((char == " " || char == "\t") && pos > 1) { pos++; continue }
        if (char == "[" && steps + (pos > 1) > 0) {
          pos++
          while (index(" \t", substr(text, pos, 1)) && pos <= size) pos++
          if (substr(text, pos, 1) == "]") {
            STEP[++steps] = ""; STEP_KIND[steps] = "iterate"
          } else if (substr(text, pos, 1) == "\"") {
            STEP[++steps] = read_string(); STEP_KIND[steps] = "key"
            if (failed) return 0
          } else if (match(substr(text, pos), /^-?[0-9]+/)) {
            STEP[++steps] = substr(text, pos, RLENGTH); STEP_KIND[steps] = "index"
            pos += RLENGTH
          } else return 0
          while (index(" \t", substr(text, pos, 1)) && pos <= size) pos++
          if (substr(text, pos, 1) != "]") return 0
          pos++
          continue
        }
        return 0
      }
      return steps > 0
    }
    BEGIN { json_init(); null = node("z", "") }
    { input = input (NR > 1 ? "\n" : "") $0 }
    END {
      mode = ENVIRON["JSON_MODE"]
      if (!read_path()) exit (mode ~ /^(set|delete)/ ? 1 : 0)
      if (mode ~ /^(set|delete)/) {
        for (i = 1; i <= steps; i++) if (STEP_KIND[i] == "iterate") exit 1
        if (mode == "delete" && !steps) exit 1
      }
      if (mode ~ /^set/) {
        text = ENVIRON["JSON_VALUE"]; size = length(text); pos = 1; failed = 0
        value = value_at()
        blank()
        if (failed || pos <= size) exit 1
        literal_value = substr(text, SPAN_START[value], SPAN_END[value] - SPAN_START[value])
      }
      text = input
      size = length(text)
      pos = 1
      failed = 0
      for (;;) {
        blank()
        if (pos > size) break
        root = value_at()
        if (failed) break
        stopped = 0
        if (mode == "duplicates") { for (i = 1; i <= duplicates; i++) printf "%s\n", steps_to(DUPLICATE[i]); duplicates = 0 }
        else if (mode == "merge_duplicates") { merge_duplicates(ENVIRON["JSON_VALUE"]); exit 0 }
        else if (mode == "leaves") leaves(root, "", 0)
        else if (mode == "values" || mode == "encoded" || mode == "keys") select(root, 1)
        else if (mode == "set") { root = set_tree(root, 1, value); if (failed) exit 5; printf "%s\n", pretty(root, "") }
        else if (mode == "delete") { if (steps) delete_tree(root, 1); if (failed) exit 5; printf "%s\n", pretty(root, "") }
        else {
          if (mode == "set_keep") keep_set(root, literal_value)
          else if (mode == "set_before") keep_insert(root, literal_value, ENVIRON["JSON_BEFORE"])
          else keep_delete(root)
          if (failed) exit 5
          if (!done) printf "%s\n", input
          exit 0
        }
      }
      if (failed && mode != "values" && mode != "encoded" && mode != "keys" && mode != "leaves" && mode != "duplicates") exit 2
    }
  '
}

# The awk writer behind string.
framework.helpers.json::write_string() {
  printf '%s.' "$1" | LC_ALL=C awk "$JSON_AWK_LIBRARY"'
    BEGIN { json_init() }
    { text = text (NR > 1 ? "\n" : "") $0 }
    END { printf "%s\n", quote(repair(substr(text, 1, length(text) - 1))) }
  '
}
