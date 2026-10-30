# shellcheck shell=bash

# GitHub through the gh CLI: as DOT_GH_TOKEN's owner when it is set (gh then
# takes it over its own login), else as the logged-in user. Each operation
# prints what the service expects, gh's error on stderr.

GITHUB_CLI="gh"

framework.integrations.github.internal.cli::is_installed() {
  command -v "$GITHUB_CLI" >/dev/null
}

framework.integrations.github.internal.cli::is_logged_in() {
  framework.integrations.github.internal.cli::gh auth status >/dev/null 2>&1
}

framework.integrations.github.internal.cli::gh() {
  local token
  token=$(dot::secret DOT_GH_TOKEN 2>/dev/null) || token=""
  if [ -n "$token" ]; then
    GH_TOKEN="$token" GH_PROMPT_DISABLED=1 "$GITHUB_CLI" "$@"
  else
    GH_PROMPT_DISABLED=1 "$GITHUB_CLI" "$@"
  fi
}

# An issue as the service's row: number, state (OPEN or CLOSED), its labels
# comma-separated, created, updated, title.
GITHUB_CLI_ROW='[.number, .state, ([.labels[].name] | join(",")), .createdAt, .updatedAt, (.title | gsub("[\t\n\r]"; " "))] | @tsv'
GITHUB_CLI_FIELDS="number,title,state,labels,createdAt,updatedAt"

framework.integrations.github.internal.cli::tarball() {
  framework.integrations.github.internal.cli::gh api "repos/$1/tarball/$2" > "$3"
}

framework.integrations.github.internal.cli::reach() {
  framework.integrations.github.internal.cli::gh repo view "$1" --json nameWithOwner >/dev/null
}

framework.integrations.github.internal.cli::issues() {
  framework.integrations.github.internal.cli::gh issue list --repo "$1" --label "$2" --state all --limit "$3" \
    --json "$GITHUB_CLI_FIELDS" --jq ".[] | $GITHUB_CLI_ROW"
}

framework.integrations.github.internal.cli::issue() {
  framework.integrations.github.internal.cli::gh issue view "$2" --repo "$1" --json "$GITHUB_CLI_FIELDS" --jq "$GITHUB_CLI_ROW"
}

framework.integrations.github.internal.cli::issue_body() {
  framework.integrations.github.internal.cli::gh issue view "$2" --repo "$1" --json body --jq .body
}

framework.integrations.github.internal.cli::create_issue() {
  local url
  url=$(framework.integrations.github.internal.cli::gh issue create --repo "$1" --title "$2" --body-file "$3" --label "$4") || return 1
  printf '%s\n' "${url##*/}"
}

framework.integrations.github.internal.cli::edit_issue() {
  local arguments=()
  [ -z "$3" ] || arguments+=(--title "$3")
  [ -z "$4" ] || arguments+=(--body-file "$4")
  [ ${#arguments[@]} -gt 0 ] || return 0
  framework.integrations.github.internal.cli::gh issue edit "$2" --repo "$1" "${arguments[@]}" >/dev/null
}

framework.integrations.github.internal.cli::label_issue() {
  local label arguments=()
  for label in $(printf '%s' "$3" | tr ',' ' '); do arguments+=(--add-label "$label"); done
  for label in $(printf '%s' "$4" | tr ',' ' '); do arguments+=(--remove-label "$label"); done
  [ ${#arguments[@]} -gt 0 ] || return 0
  framework.integrations.github.internal.cli::gh issue edit "$2" --repo "$1" "${arguments[@]}" >/dev/null
}

framework.integrations.github.internal.cli::close_issue() {
  local reason=completed
  [ "$3" != not_planned ] || reason="not planned"
  framework.integrations.github.internal.cli::gh issue close "$2" --repo "$1" --reason "$reason" >/dev/null
}

framework.integrations.github.internal.cli::reopen_issue() {
  framework.integrations.github.internal.cli::gh issue reopen "$2" --repo "$1" >/dev/null
}

framework.integrations.github.internal.cli::delete_issue() {
  framework.integrations.github.internal.cli::gh issue delete "$2" --repo "$1" --yes >/dev/null
}

framework.integrations.github.internal.cli::save_label() {
  framework.integrations.github.internal.cli::gh label create "$2" --repo "$1" --color "$3" --description "$4" --force >/dev/null
}
