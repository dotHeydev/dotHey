# shellcheck shell=bash

FS_MAX_LINK_HOPS=40
# Where temporary files go when the system's temporary folder can't take
# them: set by whoever runs the code (dotdot's boot), and changed for a run
# that moves that place itself. Leftovers older than FS_TEMP_STALE_MINUTES,
# from a run that was killed, are cleared as the fallback is used.
: "${FS_TEMP_FALLBACK:=}"
FS_TEMP_STALE_MINUTES=1440

framework.helpers.fs::resolve() {
  local fs_resolved
  framework.helpers.fs::resolve_to fs_resolved "$1" || return 1
  printf '%s\n' "$fs_resolved"
}

# resolve, into the variable named $1 rather than printed: no subshell. A
# path whose last part isn't a link and whose directory exists resolves with
# the shell's own cd -P; anything else is walked part by part.
framework.helpers.fs::resolve_to() {
  local fs_target="$1" pending="$2" resolved="" part link hops=0 fs_directory fs_name fs_here="$PWD" fs_previous="${OLDPWD-}"
  case "$pending" in
    /*) ;;
    *) pending="$PWD/$pending" ;;
  esac
  fs_name="${pending##*/}"
  fs_directory="${pending%/*}"
  case "$fs_name" in
    "" | . | ..) ;;
    *)
      if [ ! -L "$pending" ] && CDPATH='' cd -P -- "${fs_directory:-/}" 2>/dev/null; then
        resolved="$PWD"
        cd -- "$fs_here" 2>/dev/null || true
        OLDPWD="$fs_previous"
        [ "$resolved" != / ] || resolved=""
        printf -v "$fs_target" '%s' "$resolved/$fs_name"
        return 0
      fi
      ;;
  esac
  while [ -n "$pending" ]; do
    part="${pending%%/*}"
    if [ "$part" = "$pending" ]; then
      pending=""
    else
      pending="${pending#*/}"
    fi
    case "$part" in
      "" | .) continue ;;
      ..) resolved="${resolved%/*}"; continue ;;
    esac
    if [ ! -L "$resolved/$part" ]; then
      resolved="$resolved/$part"
      continue
    fi
    hops=$((hops + 1))
    [ "$hops" -le "$FS_MAX_LINK_HOPS" ] || return 1
    link=$(readlink "$resolved/$part") || return 1
    case "$link" in
      /*) resolved="" ;;
    esac
    pending="$link/$pending"
  done
  printf -v "$fs_target" '%s' "${resolved:-/}"
}

framework.helpers.fs::relative() {
  local target from up="" rest="" path
  target=$(framework.helpers.fs::resolve "$1") || return 1
  from=$(framework.helpers.fs::resolve "$2") || return 1
  [ "$target" != / ] || target=""
  [ "$from" != / ] || from=""
  while [ "$target" != "$from" ] && [ "${target#"$from"/}" = "$target" ]; do
    from="${from%/*}"
    up="../$up"
  done
  [ "$target" = "$from" ] || rest="${target#"$from"/}"
  path="$up$rest"
  path="${path%/}"
  printf '%s\n' "${path:-.}"
}

framework.helpers.fs::is_inside() {
  [ "$1" = "$2" ] || [ "${1#"$2"/}" != "$1" ]
}

framework.helpers.fs::within() {
  local path="$1" anchor="$2" resolved
  case "$path" in
    /*) ;;
    *) path="$anchor/$path" ;;
  esac
  resolved=$(framework.helpers.fs::resolve "$path") || return 1
  framework.helpers.fs::is_inside "$resolved" "$anchor" || return 1
  printf '%s\n' "$resolved"
}

# A temporary folder, its path into the variable named <target>, removed when
# the run ends: in the system's temporary folder, or else in <fallback>
# (FS_TEMP_FALLBACK by default).
framework.helpers.fs::make_temp_dir() {
  framework.helpers.fs::make_temp "$1" -d "${2-}"
}

# make_temp_dir, for a file.
framework.helpers.fs::make_temp_file() {
  framework.helpers.fs::make_temp "$1" "" "${2-}"
}

# Removes the folder <path> when nothing is left in it; quiet otherwise.
framework.helpers.fs::remove_if_empty() {
  rmdir -- "$1" 2>/dev/null || true
}

framework.helpers.fs::make_temp() {
  local fs_temp_target="$1" fs_temp_kind="$2" fs_temp_fallback="${3:-$FS_TEMP_FALLBACK}" fs_temp_path fs_temp_fell_back=false
  # shellcheck disable=SC2086
  if ! fs_temp_path=$(mktemp $fs_temp_kind 2>/dev/null); then
    [ -n "$fs_temp_fallback" ] && mkdir -p -- "$fs_temp_fallback" || return 1
    find "$fs_temp_fallback" -mindepth 1 -maxdepth 1 -mmin +"$FS_TEMP_STALE_MINUTES" -exec rm -rf -- {} + 2>/dev/null || true
    # shellcheck disable=SC2086
    fs_temp_path=$(mktemp $fs_temp_kind "$fs_temp_fallback/XXXXXX") || return 1
    fs_temp_fell_back=true
  fi
  dot::on_exit rm -rf -- "$fs_temp_path"
  # The fallback folder goes too, once nothing else is in it.
  ! $fs_temp_fell_back || dot::on_exit framework.helpers.fs::remove_if_empty "$fs_temp_fallback"
  printf -v "$fs_temp_target" '%s' "$fs_temp_path"
}

framework.helpers.fs::write() {
  local file="$1" partial
  partial="$file.dot-$$"
  if cat > "$partial" && mv -f -- "$partial" "$file"; then
    return 0
  fi
  rm -f -- "$partial"
  return 1
}

framework.helpers.fs::replace() {
  local file="$1" partial
  partial="$file.dot-$$"
  if cp -p -- "$file" "$partial" 2>/dev/null && cat > "$partial" && mv -f -- "$partial" "$file"; then
    return 0
  fi
  rm -f -- "$partial"
  return 1
}

framework.helpers.fs::link() {
  local target="$1" link="$2" directory
  directory=$(dirname -- "$link")
  mkdir -p -- "$directory" || return 1
  ln -s -- "$(framework.helpers.fs::relative "$target" "$directory")" "$link" || return 1
  [ -L "$link" ]
}

framework.helpers.fs::prune_empty_parents() {
  local directory stop="$2"
  directory=$(dirname -- "$1")
  while [ "$directory" != "$stop" ] && rmdir -- "$directory" 2>/dev/null; do
    directory=$(dirname -- "$directory")
  done
}

# How a path pattern written in a setting or a map reads, wherever one is
# taken: <path> is that path exactly; <path>/ that folder, itself and all
# inside it; <path>/* all inside that folder, one by one, not the folder
# itself; <start>* (any other ending in *) anything starting with <start>.
# The kind of <pattern>: path, folder, contents, or start.
framework.helpers.fs::pattern_kind() {
  case "$1" in
    */\*) printf 'contents\n' ;;
    *\*) printf 'start\n' ;;
    */) printf 'folder\n' ;;
    *) printf 'path\n' ;;
  esac
}

# The path <pattern> is about, its ending (/, /*, or *) taken off.
framework.helpers.fs::pattern_path() {
  case "$1" in
    */\*) printf '%s\n' "${1%/\*}" ;;
    *\*) printf '%s\n' "${1%\*}" ;;
    */) printf '%s\n' "${1%/}" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

# Whether <path> is one <pattern> takes (see pattern_kind).
framework.helpers.fs::pattern_matches() {
  local path="${1%/}" pattern="$2" base
  case "$pattern" in
    */\*) base="${pattern%/\*}/"; [ "${path#"$base"}" != "$path" ] ;;
    *\*) base="${pattern%\*}"; [ "${path#"$base"}" != "$path" ] ;;
    */) base="${pattern%/}"; [ "$path" = "$base" ] || [ "${path#"$base"/}" != "$path" ] ;;
    *) [ "$path" = "$pattern" ] ;;
  esac
}

# Whether <pattern> takes a folder's contents (ends in /*), without a subshell.
framework.helpers.fs::is_contents_pattern() {
  case "$1" in
    */\*) return 0 ;;
  esac
  return 1
}
