# shellcheck shell=bash

# A download may take this long and be this big, so a slow or huge one can't
# stall a command or fill the disk.
NET_MAX_SECONDS=300
NET_MAX_BYTES=209715200

# Whether <url> is https://, said why when it isn't: dotdot never sends or
# fetches anything over plain http, nor any other scheme.
framework.helpers.net::is_https() {
  case "$1" in
    https://*) return 0 ;;
    http://*) dot::raise "dotdot only connects over https, so it refused ${1%%\?*}." "Please use its https:// address instead." ;;
    *) dot::raise "dotdot only connects to https:// addresses, so it refused ${1%%\?*}." ;;
  esac
  return 1
}

framework.helpers.net::download() {
  local url="$1" file="$2" header
  shift 2
  framework.helpers.net::is_https "$url" || return 1
  for header in "$@"; do
    case "$header" in
      *$'\n'* | *'"'*) return 1 ;;
    esac
    printf 'header = "%s"\n' "$header"
  done | curl --proto '=https' --proto-redir '=https' --tlsv1.2 -fsSL --max-time "$NET_MAX_SECONDS" --max-filesize "$NET_MAX_BYTES" --config - -o "$file" "$url"
}

# An HTTPS request: <method> <url>, the body from <data file> (or none, when
# empty), the reply into <output file>, then each header given. Prints the
# HTTP status (000 when there was no reply); fails only when curl couldn't
# run the request, its error on stderr.
framework.helpers.net::request() {
  local method="$1" url="$2" data="$3" file="$4" header
  shift 4
  framework.helpers.net::is_https "$url" || return 1
  for header in "$@"; do
    case "$header" in
      *$'\n'* | *'"'*) return 1 ;;
    esac
    printf 'header = "%s"\n' "$header"
  done | curl --proto '=https' --proto-redir '=https' --tlsv1.2 -sS -L --max-time "$NET_MAX_SECONDS" --max-filesize "$NET_MAX_BYTES" \
    --config - -X "$method" ${data:+--data-binary "@$data"} -o "$file" -w '%{http_code}' "$url"
}
