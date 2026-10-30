# shellcheck shell=bash

hey::use framework.helpers.fs

KV_KEY_PATTERN='^[A-Za-z_][A-Za-z0-9_]*$'

framework.helpers.kv::is_key() {
  [[ "$1" =~ $KV_KEY_PATTERN ]]
}

# <key>'s value in a dotenv <file>, read as dotenv libraries do: the first
# line setting it wins; a value in quotes is taken as written between them,
# anything after the closing quote ignored; an unquoted one ends at a " #"
# comment. Status 1 when no line sets it (a commented-out one doesn't).
framework.helpers.kv::value() {
  local file="$1" key="$2"
  framework.helpers.kv::is_key "$key" || return 1
  [ -f "$file" ] || return 1
  awk -v wanted="$key" '
    { sub(/\r$/, "") }
    /^[ \t]*(#|$)/ { next }
    {
      line = $0
      sub(/^[ \t]*(export[ \t]+)?/, "", line)
      split_at = index(line, "=")
      if (split_at == 0) next
      key = substr(line, 1, split_at - 1)
      sub(/[ \t]+$/, "", key)
      if (key != wanted) next
      value = substr(line, split_at + 1)
      sub(/^[ \t]+/, "", value)
      quote = substr(value, 1, 1)
      if ((quote == "\"" || quote == "\047") && index(substr(value, 2), quote)) {
        value = substr(value, 2, index(substr(value, 2), quote) - 1)
      } else {
        sub(/(^|[ \t]+)#.*$/, "", value)
        sub(/[ \t]+$/, "", value)
      }
      print value
      found = 1
      exit
    }
    END { if (!found) exit 1 }
  ' "$file"
}

# Whether <key>'s value in a dotenv <file> is written in quotes, so it is
# text whatever it reads like.
framework.helpers.kv::is_quoted() {
  local file="$1" key="$2"
  framework.helpers.kv::is_key "$key" && [ -f "$file" ] || return 1
  awk -v wanted="$key" '
    /^[ \t]*(#|$)/ { next }
    {
      line = $0
      sub(/^[ \t]*(export[ \t]+)?/, "", line)
      split_at = index(line, "=")
      if (split_at == 0) next
      key = substr(line, 1, split_at - 1)
      sub(/[ \t]+$/, "", key)
      if (key != wanted) next
      value = substr(line, split_at + 1)
      sub(/^[ \t]+/, "", value)
      quote = substr(value, 1, 1)
      exit !((quote == "\"" || quote == "\047") && index(substr(value, 2), quote))
    }
    END { exit 1 }
  ' "$file"
}

framework.helpers.kv::keys() {
  local file="$1"
  [ -f "$file" ] || return 0
  awk '
    { sub(/\r$/, "") }
    /^[ \t]*(#|$)/ { next }
    {
      line = $0
      sub(/^[ \t]*(export[ \t]+)?/, "", line)
      split_at = index(line, "=")
      if (split_at == 0) next
      key = substr(line, 1, split_at - 1)
      sub(/[ \t]+$/, "", key)
      if (!seen[key]++) print key
    }
  ' "$file"
}

framework.helpers.kv::write() {
  local file="$1" key="$2" value="$3"
  framework.helpers.kv::is_key "$key" || return 1
  case "$value" in
    *$'\n'*) return 1 ;;
  esac
  mkdir -p -- "$(dirname -- "$file")" || return 1
  [ -f "$file" ] || : > "$file" || return 1
  awk -v wanted="$key" -v value="$value" '
    {
      line = $0; sub(/^[ \t]*(export[ \t]+)?/, "", line)
      split_at = index(line, "="); key = substr(line, 1, split_at - 1); sub(/[ \t]+$/, "", key)
      if (split_at > 0 && key == wanted) { if (!done) print wanted "=" value; done = 1; next }
      print
    }
    END { if (!done) print wanted "=" value }
  ' "$file" | framework.helpers.fs::replace "$file"
}

framework.helpers.kv::remove() {
  local file="$1" key="$2"
  framework.helpers.kv::is_key "$key" || return 1
  framework.helpers.kv::value "$file" "$key" >/dev/null || return 1
  awk -v wanted="$key" '
    {
      line = $0; sub(/^[ \t]*(export[ \t]+)?/, "", line)
      split_at = index(line, "="); key = substr(line, 1, split_at - 1); sub(/[ \t]+$/, "", key)
      if (split_at > 0 && key == wanted) next
      print
    }
  ' "$file" | framework.helpers.fs::replace "$file"
}
