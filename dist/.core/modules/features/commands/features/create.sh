# shellcheck shell=bash

DESCRIPTION="Document a new feature from the template."
DOCS="work/records#features"
JSON=true

hey::use framework.console.args core.modules.features.service framework.helpers.fs framework.console.output framework.helpers.template framework.helpers.text framework.console.prompt

usage() {
  local heading key
  cat <<EOF
Creates the next numbered feature in Features/ from the feature template;
one flag per template section, and sections left out read "None". To change
it afterwards, edit its file.

Usage:
  bash hey features:create <title> --description <text> [--<section> <text>]...

Arguments:
  <title>                        The feature's title; becomes its file name.

Options:
  --description <text>           Required. A one-line summary.
EOF
  while IFS= read -r heading; do
    key=$(framework.helpers.template::key "$heading")
    [ "$key" != "$FEATURE_DESCRIPTION_KEY" ] || continue
    printf '  --%-29s %s\n' "$key <text>" "$heading"
  done < <(framework.helpers.template::headings "$FEATURE_TEMPLATE")
  cat <<EOF
  --json                         Print {"id", "path"}.
  -h, --help                     Show this help.

Examples:
  bash hey features:create "Password reset" \\
    --description "Lets a user reset a forgotten password by email." \\
    --specification "Given a registered user… When… Then…" \\
    --related-features 7

Notes:
  - The section flags come from the feature template.
  - At a terminal, a missing title or --description is asked for.
EOF
}

handle() {
  local name="" has_name=false sections_dir key slug path
  [ -f "$FEATURE_TEMPLATE" ] || framework.console.output::fail "The template $(hey::relative "$FEATURE_TEMPLATE") is missing." "bash hey upgrade restores it."
  framework.helpers.fs::make_temp_dir sections_dir || framework.console.output::fail "Couldn't create a temporary directory; please check free space and \$TMPDIR."
  while [ $# -gt 0 ]; do
    case "$1" in
      --*)
        key="${1#--}"
        framework.helpers.template::has_key "$FEATURE_TEMPLATE" "$key" || framework.console.args::invalid "--$key isn't a feature section."
        framework.console.args::require_value "$@"
        printf '%s' "$2" > "$sections_dir/$key"
        shift 2
        ;;
      -*) framework.console.args::unexpected "$1" ;;
      *)
        ! $has_name || framework.console.args::unexpected "$1"
        name="$1"
        has_name=true
        shift
        ;;
    esac
  done
  local asked=false description=""
  [ ! -e "$sections_dir/$FEATURE_DESCRIPTION_KEY" ] || description=$(cat -- "$sections_dir/$FEATURE_DESCRIPTION_KEY")
  $has_name && [ -n "$description" ] || asked=true
  name=$(framework.console.prompt::require "$name" "The feature's title" "A feature needs a title.")
  description=$(framework.console.prompt::require "$description" "A one-line summary" "A feature needs --$FEATURE_DESCRIPTION_KEY.")
  printf '%s' "$description" > "$sections_dir/$FEATURE_DESCRIPTION_KEY"
  ! $asked || framework.console.prompt::hint "bash hey features:create \"$name\" --$FEATURE_DESCRIPTION_KEY \"$description\""
  slug=$(framework.helpers.text::slug "$name")
  [ -n "$slug" ] || framework.console.args::invalid "The name needs at least one letter or digit."
  path=$(core.modules.features.service::create "$slug" "$sections_dir") || framework.console.output::fail "Couldn't create the feature; please try again."
  framework.console.output::created "Documented feature $(framework.helpers.record::number "$(basename -- "$path")")." "$(basename -- "$path" .md)" "$(hey::relative "$path")"
}
