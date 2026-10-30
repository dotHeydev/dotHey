# shellcheck shell=bash

DESCRIPTION="Move dotdot to another place in the project."
DOCS="relocating"

dot::use framework.console.args framework.console.output framework.console.prompt framework.helpers.fs framework.helpers.text

usage() {
  cat <<EOF
Moves all of dotdot, as it is, to <dir> in the project (.agents/.dot, so it
sits in the project's .agents/ folder), points the dot entry at it, rewrites
the paths in dotdot's files, and relinks everything it linked. It previews
the move and asks first; with no one at a terminal to ask, it only previews.

Usage:
  bash dot relocate <dir> [--preview] [-y, --yes]

Arguments:
  <dir>        Where dotdot goes, from the project root; it must not exist,
               or be an empty directory.

Options:
  --preview    Show the move, and stop. Also --dry-run.
  -y, --yes    Move without asking. Only at a terminal, or when dotdot itself
               runs it.
  -h, --help   Show this help.

Examples:
  bash dot relocate .agents/.dot
  bash dot relocate .dot
EOF
}

# Whether <dir> may hold dotdot: a project path outside .git/, .env, the dot
# entry, and dotdot itself, free or an empty directory.
is_place() {
  local dir="$1" absolute
  [ -n "$dir" ] && [[ "$dir" != /* ]] && guards::stays_inside "$dir" || return 1
  case "/$dir/" in
    */./* | */.git/* | /dot/ | "/${HOST_ENV_FILE##*/}/" | "/$DOTDOT_NAME/"*) return 1 ;;
  esac
  absolute="$BASE/$dir"
  [ ! -L "$absolute" ] || return 1
  [ ! -e "$absolute" ] || { [ -d "$absolute" ] && [ -z "$(ls -A -- "$absolute")" ]; }
}

# Rewrites every "<old>/" path in dotdot's text files to "<new>/", only where
# it starts a path, so a longer one holding it is never changed twice.
rewrite_paths() {
  local old="$1" new="$2" pattern replacement file separator=$'\001'
  pattern=$(printf '%s' "$old/" | sed 's/[][\.*^$|+?(){}]/\\&/g')
  replacement=$(framework.helpers.text::escape_replacement "$new/")
  while IFS= read -r -d '' file; do
    sed -E "s$separator(^|[^A-Za-z0-9_./-])$pattern$separator\\1$replacement${separator}g" "$file" > "$file.relocated" || { rm -f -- "$file.relocated"; return 1; }
    [ ! -x "$file" ] || chmod +x "$file.relocated"
    mv -- "$file.relocated" "$file" || return 1
  done < <(grep -rl --null --binary-files=without-match --exclude-dir=.git -F -- "$old/" "$DOTDOT_ROOT")
}

handle() {
  local dir="" preview=false confirmed=false old target
  while [ $# -gt 0 ]; do
    case "$1" in
      --preview | --dry-run) preview=true ;;
      -y | --yes) confirmed=true ;;
      -*) framework.console.args::unexpected "$1" ;;
      *)
        [ -z "$dir" ] || framework.console.args::unexpected "$1"
        dir="${1%/}"
        ;;
    esac
    shift
  done
  [ -n "$dir" ] || framework.console.args::invalid "Where should dotdot go?"
  ! $confirmed || guards::skip_confirmation \
    || framework.console.output::fail_as "$EXIT_PRECONDITION" "-y only works in a terminal, so nothing changed unseen." "$OUTPUT_MANUAL_RUN bash dot relocate $dir"
  if [ "$dir" = "$DOTDOT_NAME" ]; then
    framework.console.output::success "dotdot already lives in $DOTDOT_NAME/."
    return 0
  fi
  is_place "$dir" || framework.console.args::invalid "dotdot can't move to $dir: it must be a free place in the project, outside .git/ and $DOTDOT_NAME/."
  old="$DOTDOT_NAME"
  target="$BASE/$dir"
  framework.console.output::line "This will:"
  framework.console.output::entry blue "$UI_MARK_LINKED" "$old/ $UI_ARROW $dir/" "every path in dotdot's files rewritten"
  framework.console.output::entry blue "$UI_MARK_LINKED" "dot $UI_ARROW $dir/.core/system/bin/dot"
  framework.console.output::entry blue "$UI_MARK_LINKED" "every link to $old/" "relinked to $dir/"
  if $preview || { ! $confirmed && ! framework.console.prompt::can_ask; }; then
    $preview || framework.console.output::line "No one at a terminal to confirm, so this is only a preview."
    framework.console.output::line "Preview only — nothing changed."
    return 0
  fi
  $confirmed || framework.console.prompt::confirm_or_exit "Do you want to move dotdot to $dir/?" y "bash dot relocate $dir"
  # dotdot moves, so a fallback for this run's files can't be in it.
  FS_TEMP_FALLBACK="$BASE/$DOT_PROJECT_TEMP_DIR"
  framework.console.output::detach || framework.console.output::fail "Couldn't create a temporary directory; please check free space and \$TMPDIR."
  rewrite_paths "$old" "$dir" || framework.console.output::fail "Couldn't rewrite dotdot's paths; please check that its files are writable."
  mkdir -p -- "${target%/*}" && { [ ! -d "$target" ] || rmdir -- "$target"; } && mv -- "$DOTDOT_ROOT" "$target" \
    || framework.console.output::fail "Couldn't move $old/ to $dir/." "bash dot relocate $dir runs it again."
  rm -f -- "$ENTRY_LINK" && ln -s -- "$dir/.core/system/bin/dot" "$ENTRY_LINK" \
    || framework.console.output::fail "Moved dotdot, but couldn't point dot at it." "Please run: ln -sf $dir/.core/system/bin/dot dot"
  framework.console.output::success "Moved dotdot to $dir/."
  DOT_INTERNAL_CALL=1 bash "$target/.core/system/bin/dot" link -y --relink-from "$old" \
    || framework.console.output::fail "Linking didn't finish; see above, then run: bash dot link"
}
