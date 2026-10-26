#!/usr/bin/env bash

# GitHub through its REST and GraphQL APIs as DOT_GH_TOKEN's owner, for when
# gh is missing or fails; the same operations as internal/cli.sh, printing
# the same, an "HTTP <status>: <message>" error on stderr.

dot::use framework.helpers.fs framework.helpers.json framework.helpers.net

GITHUB_API_URL="https://api.github.com"
GITHUB_API_PAGE=100

# A request as DOT_GH_TOKEN's owner: <method> <path> [<json>]; the reply on
# stdout when it succeeds, else its status and message on stderr.
framework.integrations.github.internal.api::request() {
  local method="$1" path="$2" json="${3-}" token work status reply
  token=$(dot::secret DOT_GH_TOKEN 2>/dev/null) || { printf 'no DOT_GH_TOKEN\n' >&2; return 1; }
  framework.helpers.fs::make_temp_dir work || return 1
  [ -z "$json" ] || printf '%s' "$json" > "$work/data"
  status=$(framework.helpers.net::request "$method" "$GITHUB_API_URL/$path" "${json:+$work/data}" "$work/reply" \
    "Authorization: Bearer $token" "Accept: application/vnd.github+json" "X-GitHub-Api-Version: 2022-11-28") || status=000
  reply=""
  [ ! -f "$work/reply" ] || reply=$(cat -- "$work/reply")
  rm -rf -- "$work"
  case "$status" in
    2??) printf '%s\n' "$reply"; return 0 ;;
    000) printf 'network: no reply from %s\n' "$GITHUB_API_URL" >&2 ;;
    *) printf 'HTTP %s: %s\n' "$status" "$(framework.helpers.json::field "$reply" .message)" >&2 ;;
  esac
  return 1
}

# The rows of a JSON list of issues (pull requests left out), as
# internal/cli.sh prints them.
framework.integrations.github.internal.api::rows() {
  framework.helpers.json::leaves "$1" | awk -F '\t' -v OFS='\t' '
    function text(from,   out, i) { out = $from; for (i = from + 1; i <= NF; i++) out = out " " $i; gsub(/[\r\n]/, " ", out); return out }
    !($1 in seen) { seen[$1] = 1; order[++count] = $1 }
    $2 == "pull_request" { pull[$1] = 1 }
    $2 == "number" { number[$1] = $3 }
    $2 == "state" { state[$1] = toupper($3) }
    $2 == "title" { title[$1] = text(3) }
    $2 == "created_at" { created[$1] = $3 }
    $2 == "updated_at" { updated[$1] = $3 }
    $2 == "labels" && $4 == "name" { labels[$1] = (labels[$1] == "" ? "" : labels[$1] ",") $5 }
    END { for (i = 1; i <= count; i++) { id = order[i]; if (!(id in pull) && (id in number)) print number[id], state[id], labels[id], created[id], updated[id], title[id] } }
  '
}

framework.integrations.github.internal.api::tarball() {
  local token
  token=$(dot::secret DOT_GH_TOKEN 2>/dev/null) || { printf 'no DOT_GH_TOKEN\n' >&2; return 1; }
  framework.helpers.net::download "$GITHUB_API_URL/repos/$1/tarball/$2" "$3" "Authorization: Bearer $token" \
    || { printf 'HTTP error or no reply downloading %s@%s\n' "$1" "$2" >&2; return 1; }
}

framework.integrations.github.internal.api::reach() {
  framework.integrations.github.internal.api::request GET "repos/$1" >/dev/null
}

framework.integrations.github.internal.api::issues() {
  local repository="$1" label="$2" limit="$3" page=1 reply rows printed=0
  while [ "$printed" -lt "$limit" ]; do
    reply=$(framework.integrations.github.internal.api::request GET "repos/$repository/issues?labels=$(framework.integrations.github.internal.api::escape "$label")&state=all&per_page=$GITHUB_API_PAGE&page=$page") || return 1
    rows=$(framework.integrations.github.internal.api::rows "$reply")
    [ -z "$rows" ] || { printf '%s\n' "$rows" | head -n $((limit - printed)); printed=$((printed + $(printf '%s\n' "$rows" | wc -l))); }
    [ "$(framework.helpers.json::keys "$reply" . | wc -l)" -ge "$GITHUB_API_PAGE" ] || break
    page=$((page + 1))
  done
}

framework.integrations.github.internal.api::issue() {
  local reply
  reply=$(framework.integrations.github.internal.api::request GET "repos/$1/issues/$2") || return 1
  framework.integrations.github.internal.api::rows "[$reply]"
}

framework.integrations.github.internal.api::issue_body() {
  local reply
  reply=$(framework.integrations.github.internal.api::request GET "repos/$1/issues/$2") || return 1
  framework.helpers.json::values "$reply" .body
}

framework.integrations.github.internal.api::create_issue() {
  local reply
  reply=$(framework.integrations.github.internal.api::request POST "repos/$1/issues" \
    "{\"title\": $(framework.helpers.json::string "$2"), \"body\": $(framework.helpers.json::string "$(cat -- "$3")"), \"labels\": [$(framework.helpers.json::string "$4")]}") || return 1
  framework.helpers.json::field "$reply" .number
}

framework.integrations.github.internal.api::edit_issue() {
  local members=""
  [ -z "$3" ] || members="\"title\": $(framework.helpers.json::string "$3")"
  [ -z "$4" ] || members="${members:+$members, }\"body\": $(framework.helpers.json::string "$(cat -- "$4")")"
  [ -n "$members" ] || return 0
  framework.integrations.github.internal.api::request PATCH "repos/$1/issues/$2" "{$members}" >/dev/null
}

framework.integrations.github.internal.api::label_issue() {
  local repository="$1" number="$2" label list=""
  for label in $(printf '%s' "$3" | tr ',' ' '); do list="${list:+$list, }$(framework.helpers.json::string "$label")"; done
  [ -z "$list" ] || framework.integrations.github.internal.api::request POST "repos/$repository/issues/$number/labels" "{\"labels\": [$list]}" >/dev/null || return 1
  for label in $(printf '%s' "$4" | tr ',' ' '); do
    framework.integrations.github.internal.api::request DELETE "repos/$repository/issues/$number/labels/$(framework.integrations.github.internal.api::escape "$label")" >/dev/null || return 1
  done
}

framework.integrations.github.internal.api::close_issue() {
  framework.integrations.github.internal.api::request PATCH "repos/$1/issues/$2" "{\"state\": \"closed\", \"state_reason\": \"$3\"}" >/dev/null
}

framework.integrations.github.internal.api::reopen_issue() {
  framework.integrations.github.internal.api::request PATCH "repos/$1/issues/$2" '{"state": "open"}' >/dev/null
}

# REST can't delete an issue; GraphQL can, by its node id.
framework.integrations.github.internal.api::delete_issue() {
  local reply node
  reply=$(framework.integrations.github.internal.api::request GET "repos/$1/issues/$2") || return 1
  node=$(framework.helpers.json::field "$reply" .node_id)
  [ -n "$node" ] || { printf 'issue #%s has no node id\n' "$2" >&2; return 1; }
  reply=$(framework.integrations.github.internal.api::request POST graphql \
    "{\"query\": \"mutation(\$id: ID!) { deleteIssue(input: {issueId: \$id}) { clientMutationId } }\", \"variables\": {\"id\": $(framework.helpers.json::string "$node")}}") || return 1
  [ -z "$(framework.helpers.json::field "$reply" '.errors[0].message')" ] \
    || { printf 'GraphQL: %s\n' "$(framework.helpers.json::field "$reply" '.errors[0].message')" >&2; return 1; }
}

framework.integrations.github.internal.api::save_label() {
  local repository="$1" name="$2" color="$3" description="$4" error
  error=$(framework.integrations.github.internal.api::request POST "repos/$repository/labels" \
    "{\"name\": $(framework.helpers.json::string "$name"), \"color\": \"$color\", \"description\": $(framework.helpers.json::string "$description")}" 2>&1 >/dev/null) && return 0
  case "$error" in
    "HTTP 422"*) ;;
    *) printf '%s\n' "$error" >&2; return 1 ;;
  esac
  framework.integrations.github.internal.api::request PATCH "repos/$repository/labels/$(framework.integrations.github.internal.api::escape "$name")" \
    "{\"color\": \"$color\", \"description\": $(framework.helpers.json::string "$description")}" >/dev/null
}

# <text> for a URL path segment: everything but letters, digits, and -._~
# percent-encoded, byte by byte.
framework.integrations.github.internal.api::escape() {
  local text="$1" out="" char i
  for ((i = 0; i < ${#text}; i++)); do
    char="${text:i:1}"
    case "$char" in
      [A-Za-z0-9._~-]) out="$out$char" ;;
      *) out="$out$(printf '%s' "$char" | od -An -tx1 | tr -d ' \n' | sed 's/../%&/g' | tr 'a-f' 'A-F')" ;;
    esac
  done
  printf '%s\n' "$out"
}
