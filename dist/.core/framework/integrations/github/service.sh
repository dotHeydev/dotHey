# shellcheck shell=bash

# Everything dotdot does on GitHub, behind one service: each operation runs
# through internal/route.sh (gh, then the API with DOT_GH_TOKEN), so callers
# never choose a route. Releases are apart: they push with their own tokens.

dot::use framework.integrations.github.internal.route framework.helpers.net

GITHUB_HOST_URL="https://github.com/"
GITHUB_REPOSITORY_PATTERN='^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$'
GITHUB_REF_PATTERN='^[A-Za-z0-9][A-Za-z0-9._/-]*$'
GITHUB_COMMIT_PATTERN='comment=[0-9a-f]\{40\}'
GITHUB_HEADER_BYTES=1024

framework.integrations.github.service::is_repository() {
  [[ "$1" =~ $GITHUB_REPOSITORY_PATTERN ]]
}

framework.integrations.github.service::is_ref() {
  [[ "$1" =~ $GITHUB_REF_PATTERN ]] && [[ "$1" != *..* ]]
}

framework.integrations.github.service::url() {
  printf '%s%s\n' "$GITHUB_HOST_URL" "$1"
}

# Whether GitHub can be reached as someone: gh logged in, or DOT_GH_TOKEN.
framework.integrations.github.service::is_ready() {
  framework.integrations.github.internal.route::is_ready
}

# The owner/name of the GitHub repo <directory>'s origin remote points at, or
# nothing.
framework.integrations.github.service::repository_of() {
  local url
  url=$(git -C "$1" remote get-url origin 2>/dev/null) || return 0
  url="${url%.git}"
  case "$url" in
    https://github.com/*/*) url="${url#https://github.com/}" ;;
    git@github.com:*/*) url="${url#git@github.com:}" ;;
    ssh://git@github.com/*/*) url="${url#ssh://git@github.com/}" ;;
    *) return 0 ;;
  esac
  ! framework.integrations.github.service::is_repository "$url" || printf '%s\n' "$url"
}

# Downloads <repository>@<ref> as a tarball into <file>: from the public
# archive first, needing no one, then through the routes as for any other
# operation.
framework.integrations.github.service::download() {
  local repository="$1" ref="$2" file="$3"
  framework.helpers.net::download "$GITHUB_HOST_URL$repository/archive/$ref.tar.gz" "$file" 2>/dev/null && return 0
  framework.integrations.github.internal.route::run "download $repository@$ref, which the public archive doesn't have (a private repo, or no such ref)" tarball "$repository" "$ref" "$file"
}

# The commit a downloaded tarball holds, from its header.
framework.integrations.github.service::tarball_commit() {
  gzip -dc -- "$1" 2>/dev/null | head -c "$GITHUB_HEADER_BYTES" | tr -d '\000' \
    | grep -ao "$GITHUB_COMMIT_PATTERN" | cut -d= -f2 || true
}

framework.integrations.github.service::can_reach() {
  framework.integrations.github.internal.route::run "reach $1" reach "$1"
}

# Issues as rows: number, state (OPEN or CLOSED), labels comma-separated,
# created, updated, title, tab-separated.
framework.integrations.github.service::issues() {
  framework.integrations.github.internal.route::run "list the issues of $1" issues "$1" "$2" "$3"
}

framework.integrations.github.service::issue() {
  framework.integrations.github.internal.route::run "read issue #$2 in $1" issue "$1" "$2"
}

framework.integrations.github.service::issue_body() {
  framework.integrations.github.internal.route::run "read issue #$2 in $1" issue_body "$1" "$2"
}

# Creates an issue (<repository> <title> <body file> <label>); prints its number.
framework.integrations.github.service::create_issue() {
  framework.integrations.github.internal.route::run "create an issue in $1" create_issue "$@"
}

# <repository> <number> <title> <body file>, either empty to keep it.
framework.integrations.github.service::edit_issue() {
  framework.integrations.github.internal.route::run "edit issue #$2 in $1" edit_issue "$@"
}

# <repository> <number> <labels to add> <labels to remove>, comma-separated.
framework.integrations.github.service::label_issue() {
  framework.integrations.github.internal.route::run "change the labels of issue #$2 in $1" label_issue "$@"
}

# <repository> <number> <reason: completed or not_planned>.
framework.integrations.github.service::close_issue() {
  framework.integrations.github.internal.route::run "close issue #$2 in $1" close_issue "$@"
}

framework.integrations.github.service::reopen_issue() {
  framework.integrations.github.internal.route::run "reopen issue #$2 in $1" reopen_issue "$@"
}

framework.integrations.github.service::delete_issue() {
  framework.integrations.github.internal.route::run "delete issue #$2 in $1" delete_issue "$@"
}

# Creates or updates a label: <repository> <name> <color> <description>.
framework.integrations.github.service::save_label() {
  framework.integrations.github.internal.route::run "save the label $2 in $1" save_label "$@"
}
