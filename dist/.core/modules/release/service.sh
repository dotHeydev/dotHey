#!/usr/bin/env bash

dot::use framework.helpers.fs framework.helpers.json framework.helpers.secrets framework.helpers.text

RELEASE_PROJECT="$BASE"
RELEASE_REMOTES_SETTING="release.remotes"
# Marks an example remote, as dotdot's defaults ship one: never used.
RELEASE_PLACEHOLDER_PATTERN='_USER_|_REPO_'
RELEASE_EXCLUDE_SETTING="release.exclude"
RELEASE_TOKEN_CACHE="$HOME/.cache/dotdot-release/socket"
RELEASE_TOKEN_PREFIX="DOT_RELEASE_TOKEN_"
RELEASE_REMOTE_NAME_PATTERN='^[a-z0-9][a-z0-9_-]*$'
RELEASE_REMOTE_URL_PATTERN='^https://[A-Za-z0-9.-]+(:[0-9]+)?/[^[:space:]@]+$'
RELEASE_RESERVED_REMOTES=" help push-all "
RELEASE_VERSION_PATTERN='^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$'
RELEASE_SIGNING_NAME_PATTERN='^[A-Za-z0-9_][A-Za-z0-9._-]*$'
RELEASE_AUTHOR_NAME_PATTERN='^[^[:cntrl:]<>]+$'
RELEASE_AUTHOR_EMAIL_PATTERN='^[^[:space:]<>@]+@[^[:space:]<>@]+$'
RELEASE_TOKEN_PATTERN='^[A-Za-z0-9_-]{20,255}$'
RELEASE_CIPHER_PATTERN='^[A-Za-z0-9+/]+=*$'
RELEASE_CACHE_MINUTES_PATTERN='^[0-9]{1,4}$'
RELEASE_TOKEN_SERVICE="dotdot-release"
RELEASE_KEY_LIFETIME=600
# A line holding this is a known false positive, left out of the scan.
RELEASE_SECRET_ALLOW="dotdot:not-a-secret"
RELEASE_TOKEN_HELPER='!f() { [ "$1" = get ] || return 0; p=; h=; while IFS= read -r line && [ -n "$line" ]; do case $line in protocol=*) p=${line#protocol=} ;; host=*) h=${line#host=} ;; esac; done; [ "$p" = https ] && [ "$h" = "$RELEASE_TOKEN_HOST" ] || return 0; printf "username=x-access-token\npassword=%s\n" "$RELEASE_TOKEN"; }; f'

RELEASE_REMOTES=()
RELEASE_REMOTE_URLS=()
RELEASE_PUSH_TO=()
RELEASE_PUSH_ALL=false
RELEASE_FORCE=false
RELEASE_CACHE_MINUTES=""
RELEASE_WARNINGS=()
RELEASE_AGENT_PID=""

# The remotes in release.remotes ({<name>: <https url>}), into RELEASE_REMOTES
# and RELEASE_REMOTE_URLS; an example one (_USER_, _REPO_ in its url) is
# skipped.
core.modules.release.service::load_remotes() {
  local remotes name url
  RELEASE_REMOTES=()
  RELEASE_REMOTE_URLS=()
  remotes=$(dot::setting "$RELEASE_REMOTES_SETTING" "{}") || dot::abort "Could not read $RELEASE_REMOTES_SETTING."
  case "$remotes" in
    "{"*) ;;
    *) dot::abort "$RELEASE_REMOTES_SETTING must be an object, {<name>: <https url>}." ;;
  esac
  while IFS="$(printf '\t')" read -r name url; do
    [[ ! "$url" =~ $RELEASE_PLACEHOLDER_PATTERN ]] || continue
    [[ "$name" =~ $RELEASE_REMOTE_NAME_PATTERN ]] && [[ "$RELEASE_RESERVED_REMOTES" != *" $name "* ]] \
      || dot::abort "Unusable remote name (letters, digits, _ and -; not help or push-all): $name"
    [[ "$url" =~ $RELEASE_REMOTE_URL_PATTERN ]] \
      || dot::abort "$RELEASE_REMOTES_SETTING.$name must be an https:// url without credentials in it (pushes authenticate with a token): $url"
    RELEASE_REMOTES+=("$name")
    RELEASE_REMOTE_URLS+=("$url")
  done < <(framework.helpers.json::leaves "$remotes")
  [ ${#RELEASE_REMOTES[@]} -gt 0 ] \
    || dot::abort "No remote in $RELEASE_REMOTES_SETTING of $(dot::relative "$SETTINGS_FILE") (examples with _USER_/_REPO_ don't count); at least one is required."
}

core.modules.release.service::remote_url() {
  local index
  for index in "${!RELEASE_REMOTES[@]}"; do
    if [ "${RELEASE_REMOTES[$index]}" = "$1" ]; then
      printf '%s' "${RELEASE_REMOTE_URLS[$index]}"
      return 0
    fi
  done
  dot::abort "No remote $1 in $RELEASE_REMOTES_SETTING of $(dot::relative "$SETTINGS_FILE")."
}

core.modules.release.service::check_push_targets() {
  local name
  for name in ${RELEASE_PUSH_TO[@]+"${RELEASE_PUSH_TO[@]}"}; do
    core.modules.release.service::remote_url "$name" >/dev/null
  done
}

core.modules.release.service::is_targeted() {
  $RELEASE_PUSH_ALL && return 0
  [[ " ${RELEASE_PUSH_TO[*]-} " == *" $1 "* ]]
}

core.modules.release.service::token_store() {
  if [ "$(uname -s)" = Darwin ] && command -v security >/dev/null; then
    printf 'keychain\n'
  elif command -v secret-tool >/dev/null && [ -n "${DBUS_SESSION_BUS_ADDRESS-}" ]; then
    printf 'libsecret\n'
  elif command -v gpg >/dev/null; then
    printf 'gpg\n'
  else
    dot::abort "No secret store found: install gpg, or libsecret's secret-tool."
  fi
}

core.modules.release.service::token_id() {
  printf '%s' "$1" | git hash-object --stdin
}

core.modules.release.service::token_key() {
  local index
  for index in "${!RELEASE_REMOTE_URLS[@]}"; do
    if [ "${RELEASE_REMOTE_URLS[$index]}" = "$1" ]; then
      printf '%s%s' "$RELEASE_TOKEN_PREFIX" "$(framework.helpers.text::upper "${RELEASE_REMOTES[$index]//-/_}")"
      return 0
    fi
  done
  return 1
}

core.modules.release.service::save_token() {
  local url="$1" token="$2" identifier key cipher
  [[ "$token" =~ $RELEASE_TOKEN_PATTERN ]] || dot::abort "That does not look like a token (letters, digits, _ and -)."
  identifier=$(core.modules.release.service::token_id "$url")
  case "$(core.modules.release.service::token_store)" in
    keychain)
      printf 'add-generic-password -U -s %s -a %s -w %s\n' "$RELEASE_TOKEN_SERVICE" "$identifier" "$token" | security -i >/dev/null
      ;;
    libsecret)
      printf '%s' "$token" | secret-tool store --label="dotdot release token for $url" service "$RELEASE_TOKEN_SERVICE" id "$identifier"
      ;;
    gpg)
      key=$(core.modules.release.service::token_key "$url") || return 1
      cipher=$(printf '%s\n%s' "$url" "$token" | gpg --quiet --pinentry-mode loopback --no-symkey-cache \
        --symmetric --cipher-algo AES256 --s2k-mode 3 --s2k-digest-algo SHA512 --s2k-count 65011712 \
        --output - | base64 | tr -d '\n') || return 1
      [[ "$cipher" =~ $RELEASE_CIPHER_PATTERN ]] || return 1
      dot::save_secret "$key" "$cipher" || return 1
      ;;
  esac
  core.modules.release.service::cache_token erase "$url" </dev/null || true
  core.modules.release.service::has_token "$url"
}

core.modules.release.service::decrypt_token() {
  local url="$1" key cipher plain status
  key=$(core.modules.release.service::token_key "$url") && cipher=$(dot::secret "$key") || return 1
  [[ "$cipher" =~ $RELEASE_CIPHER_PATTERN ]] || return 1
  status=$(mktemp) || return 1
  plain=$(printf '%s' "$cipher" | base64 --decode | gpg --quiet --pinentry-mode loopback --no-symkey-cache \
    --status-file "$status" --decrypt) || { rm -f -- "$status"; return 1; }
  if ! grep -q '^\[GNUPG:\] NEED_PASSPHRASE_SYM ' "$status" || ! grep -q '^\[GNUPG:\] DECRYPTION_OKAY' "$status" \
    || grep -q '^\[GNUPG:\] ENC_TO ' "$status"; then
    rm -f -- "$status"
    dot::raise "$key in $(dot::relative "$HOST_ENV_FILE") is not a passphrase-encrypted token; store it again with bash dot release:token."
    return 1
  fi
  rm -f -- "$status"
  if [ "${plain%%$'\n'*}" != "$url" ]; then
    dot::raise "$key in $(dot::relative "$HOST_ENV_FILE") was stored for another url; store it again with bash dot release:token."
    return 1
  fi
  printf '%s' "${plain#*$'\n'}"
}

core.modules.release.service::read_token() {
  local url="$1" identifier token
  identifier=$(core.modules.release.service::token_id "$url")
  token=$(case "$(core.modules.release.service::token_store)" in
    keychain) security find-generic-password -s "$RELEASE_TOKEN_SERVICE" -a "$identifier" -w 2>/dev/null ;;
    libsecret) secret-tool lookup service "$RELEASE_TOKEN_SERVICE" id "$identifier" 2>/dev/null ;;
    gpg) core.modules.release.service::decrypt_token "$url" ;;
  esac) || return 1
  [[ "$token" =~ $RELEASE_TOKEN_PATTERN ]] || return 1
  printf '%s' "$token"
}

core.modules.release.service::cache_token() {
  local action="$1" url="$2" seconds="${3-}" directory
  directory=$(dirname -- "$RELEASE_TOKEN_CACHE")
  mkdir -p "$directory" && chmod 700 "$directory" || return 1
  { printf 'protocol=https\nhost=%s\npath=%s\n' "$RELEASE_TOKEN_SERVICE" "$(core.modules.release.service::token_id "$url")"; cat; echo; } \
    | git credential-cache ${seconds:+--timeout="$seconds"} --socket="$RELEASE_TOKEN_CACHE" "$action"
}

core.modules.release.service::load_token() {
  local url="$1" token=""
  if [ "$RELEASE_CACHE_MINUTES" = 0 ]; then
    core.modules.release.service::cache_token erase "$url" </dev/null || true
  else
    token=$(core.modules.release.service::cache_token get "$url" </dev/null 2>/dev/null | sed -n 's/^password=//p') || token=""
  fi
  [[ "$token" =~ $RELEASE_TOKEN_PATTERN ]] || token=$(core.modules.release.service::read_token "$url") || return 1
  if [ -n "$RELEASE_CACHE_MINUTES" ] && [ "$RELEASE_CACHE_MINUTES" != 0 ]; then
    printf 'username=token\npassword=%s\n' "$token" | core.modules.release.service::cache_token store "$url" $((10#$RELEASE_CACHE_MINUTES * 60)) || return 1
  fi
  printf '%s' "$token"
}

core.modules.release.service::has_token() {
  local url="$1" key
  case "$(core.modules.release.service::token_store)" in
    keychain) security find-generic-password -s "$RELEASE_TOKEN_SERVICE" -a "$(core.modules.release.service::token_id "$url")" >/dev/null 2>&1 ;;
    libsecret) core.modules.release.service::read_token "$url" >/dev/null ;;
    gpg) key=$(core.modules.release.service::token_key "$url") && dot::secret "$key" >/dev/null ;;
  esac
}

core.modules.release.service::remove_token() {
  local url="$1" identifier
  identifier=$(core.modules.release.service::token_id "$url")
  core.modules.release.service::cache_token erase "$url" </dev/null || true
  case "$(core.modules.release.service::token_store)" in
    keychain) security delete-generic-password -s "$RELEASE_TOKEN_SERVICE" -a "$identifier" >/dev/null 2>&1 ;;
    libsecret) core.modules.release.service::has_token "$url" && secret-tool clear service "$RELEASE_TOKEN_SERVICE" id "$identifier" ;;
    gpg) core.modules.release.service::has_token "$url" && dot::remove_secret "$(core.modules.release.service::token_key "$url")" ;;
  esac
}

core.modules.release.service::push_with_token() {
  local repository="$1" name="$2" url="$3" token host
  shift 3
  token=$(core.modules.release.service::load_token "$url") && [ -n "$token" ] \
    || { dot::raise "No token for $name. Store one: bash dot release:token $name"; return 1; }
  host="${url#https://}"
  host="${host%%/*}"
  RELEASE_TOKEN=$token RELEASE_TOKEN_HOST=$host GIT_TERMINAL_PROMPT=0 GIT_TRACE_REDACT=1 \
    env -u GIT_ASKPASS -u SSH_ASKPASS -u GIT_SSL_NO_VERIFY \
    git -C "$repository" -c credential.helper= -c "credential.helper=$RELEASE_TOKEN_HELPER" -c core.askPass= \
    -c core.hooksPath=/dev/null -c http.sslVerify=true \
    push "$name" "$@"
}

core.modules.release.service::repo() {
  git -C "$RELEASE_DESTINATION" "$@"
}

core.modules.release.service::point_remotes() {
  local index
  for index in "${!RELEASE_REMOTES[@]}"; do
    if core.modules.release.service::repo remote get-url "${RELEASE_REMOTES[$index]}" >/dev/null 2>&1; then
      core.modules.release.service::repo remote set-url "${RELEASE_REMOTES[$index]}" "${RELEASE_REMOTE_URLS[$index]}"
    else
      core.modules.release.service::repo remote add "${RELEASE_REMOTES[$index]}" "${RELEASE_REMOTE_URLS[$index]}"
    fi
    core.modules.release.service::repo config --unset-all "remote.${RELEASE_REMOTES[$index]}.pushurl" || true
  done
}

core.modules.release.service::open_repository() {
  local branch="$1"
  [ -d "$RELEASE_DESTINATION/.git" ] || dot::abort "No release repo at $RELEASE_DESTINATION; run bash dot release:create <version> first."
  [ "$(core.modules.release.service::repo symbolic-ref --short HEAD)" = "$branch" ] || dot::abort "Release repo is not on branch $branch."
}

core.modules.release.service::check_signing_identity() {
  [[ "$RELEASE_SIGNING_NAME" =~ $RELEASE_SIGNING_NAME_PATTERN ]] \
    || dot::abort "RELEASE_SIGNING_KEY must be a file name in $HOME/.ssh/, not a path: $RELEASE_SIGNING_NAME"
  [[ "$RELEASE_SIGNING_NAME" != *.pub ]] \
    || dot::abort "RELEASE_SIGNING_KEY names the private key (e.g. ${RELEASE_SIGNING_NAME%.pub}), not its .pub: $RELEASE_SIGNING_NAME"
  [[ "$RELEASE_AUTHOR_NAME" =~ $RELEASE_AUTHOR_NAME_PATTERN ]] || dot::abort "Invalid RELEASE_AUTHOR_NAME (control characters or < >)."
  [[ "$RELEASE_AUTHOR_EMAIL" =~ $RELEASE_AUTHOR_EMAIL_PATTERN ]] || dot::abort "Invalid RELEASE_AUTHOR_EMAIL (not a single address)."
  RELEASE_SIGNING_KEY="$HOME/.ssh/$RELEASE_SIGNING_NAME"
  RELEASE_PUBLIC_KEY="$RELEASE_SIGNING_KEY.pub"
  [ -f "$RELEASE_SIGNING_KEY" ] || dot::abort "Private signing key not found: $RELEASE_SIGNING_KEY"
  [ -f "$RELEASE_PUBLIC_KEY" ] || dot::abort "Public key not found (needed to verify the signature): $RELEASE_PUBLIC_KEY"
}

core.modules.release.service::check_tokens() {
  local index
  for index in "${!RELEASE_REMOTES[@]}"; do
    core.modules.release.service::is_targeted "${RELEASE_REMOTES[$index]}" || continue
    core.modules.release.service::has_token "${RELEASE_REMOTE_URLS[$index]}" \
      || dot::abort "No token for ${RELEASE_REMOTES[$index]}; store one first: bash dot release:token ${RELEASE_REMOTES[$index]}"
  done
}

# The paths release.exclude lists, left out of the export; "!<path>" names a
# git-ignored one to copy from disk instead.
core.modules.release.service::read_exclusions() {
  local line resolved include list
  list=$(dot::setting "$RELEASE_EXCLUDE_SETTING" "[]") || dot::abort "Could not read $RELEASE_EXCLUDE_SETTING; nothing released."
  case "$list" in
    "["*) list=$(framework.helpers.json::values "$list" '.[]') ;;
    *) dot::abort "$RELEASE_EXCLUDE_SETTING must be a list, e.g. [\".dot/\", \"dot\"]; nothing released." ;;
  esac
  RELEASE_EXCLUDED=()
  RELEASE_COPIED=()
  while IFS= read -r line; do
    line=$(framework.helpers.text::trim "$line")
    [ -n "$line" ] || continue
    include=false
    if [[ "$line" == '!'* ]]; then
      include=true
      line="${line#!}"
    fi
    case "$(framework.helpers.fs::pattern_kind "$line")" in
      start) dot::abort "$RELEASE_EXCLUDE_SETTING takes paths, folders (x/), and folder contents (x/*), not a start (x*): $line" ;;
    esac
    line=$(framework.helpers.fs::pattern_path "$line")
    resolved=$(framework.helpers.fs::within "$line" "$RELEASE_PROJECT") && [ "$resolved" != "$RELEASE_PROJECT" ] || dot::abort "Listed path is outside the project: $line"
    if ! $include; then
      git cat-file -e "HEAD:$line" 2>/dev/null || git check-ignore -q -- "$line" \
        || RELEASE_WARNINGS+=("Excluded path is neither in HEAD nor git-ignored, nothing to leave out: $line")
      RELEASE_EXCLUDED+=("$line")
      continue
    fi
    [ -e "$line" ] && git check-ignore -q "$line" || dot::abort "!$line must be a git-ignored path on disk."
    ! framework.helpers.fs::is_inside "$HOST_ENV_FILE" "$resolved" || dot::abort "!$line holds the project's .env."
    [ -z "$(find "$line" -type l -print -quit)" ] || dot::abort "!$line holds symlinks."
    RELEASE_COPIED+=("$line")
  done <<< "$list"
  RELEASE_PATHSPEC=(.)
  for line in ${RELEASE_EXCLUDED[@]+"${RELEASE_EXCLUDED[@]}"}; do
    RELEASE_PATHSPEC+=(":(exclude,literal)$line")
  done
  [ -n "$(git ls-files -- "${RELEASE_PATHSPEC[@]}")" ] || dot::abort "The exclude list leaves nothing to release."
}

# Whether what the export takes (RELEASE_PATHSPEC, from read_exclusions) has
# no uncommitted or untracked changes, so the release is exactly HEAD.
core.modules.release.service::ships_clean() {
  [ -z "$(git status --porcelain -- "${RELEASE_PATHSPEC[@]}")" ]
}

core.modules.release.service::prepare_repository() {
  local branch="$1" tag="$2"
  mkdir -p "$RELEASE_DESTINATION"
  RELEASE_DESTINATION=$(cd "$RELEASE_DESTINATION" && pwd -P)
  ! framework.helpers.fs::is_inside "$RELEASE_PROJECT" "$RELEASE_DESTINATION" || dot::abort "Destination must not contain this repo: $RELEASE_DESTINATION"
  if [ ! -d "$RELEASE_DESTINATION/.git" ]; then
    [ -z "$(ls -A "$RELEASE_DESTINATION")" ] || dot::abort "Destination is neither empty nor a git repo: $RELEASE_DESTINATION"
    git init -q -b "$branch" "$RELEASE_DESTINATION"
  fi
  core.modules.release.service::open_repository "$branch"
  [ -z "$(core.modules.release.service::repo status --porcelain)" ] || [ -z "$(core.modules.release.service::repo rev-parse -q --verify HEAD)" ] \
    || dot::abort "Release repo has uncommitted changes: $RELEASE_DESTINATION"
  ! core.modules.release.service::repo rev-parse -q --verify "refs/tags/$tag" >/dev/null || dot::abort "Tag already exists: $tag"
}

core.modules.release.service::configure_signing() {
  local tool signers="$RELEASE_DESTINATION/.git/allowed_signers"
  for tool in ssh-keygen ssh-agent ssh-add; do
    command -v "$tool" >/dev/null || dot::abort "$tool not found; it is needed to sign with an SSH key."
  done
  core.modules.release.service::repo config user.name "$RELEASE_AUTHOR_NAME"
  core.modules.release.service::repo config user.email "$RELEASE_AUTHOR_EMAIL"
  printf '%s namespaces="git" %s\n' "$RELEASE_AUTHOR_EMAIL" "$(cat "$RELEASE_PUBLIC_KEY")" > "$signers"
  core.modules.release.service::repo config gpg.format ssh
  core.modules.release.service::repo config user.signingkey "$RELEASE_PUBLIC_KEY"
  core.modules.release.service::repo config gpg.ssh.allowedSignersFile "$signers"
  core.modules.release.service::repo config commit.gpgsign true
  core.modules.release.service::repo config tag.gpgsign true
  RELEASE_SIGNERS="$signers"
}

core.modules.release.service::stop_agent() {
  [ -n "$RELEASE_AGENT_PID" ] || return 0
  SSH_AGENT_PID="$RELEASE_AGENT_PID" ssh-agent -k >/dev/null 2>&1 || true
  RELEASE_AGENT_PID=""
  unset SSH_AUTH_SOCK SSH_AGENT_PID
}

core.modules.release.service::start_agent() {
  local probe agent
  framework.helpers.fs::make_temp_dir probe || dot::abort "Could not create a temp directory."
  dot::on_exit core.modules.release.service::stop_agent
  agent=$(ssh-agent -s -a "$probe/agent") || dot::abort "Could not start ssh-agent for signing."
  RELEASE_AGENT_PID=$(sed -n 's/^SSH_AGENT_PID=\([0-9][0-9]*\);.*/\1/p' <<< "$agent")
  [ -n "$RELEASE_AGENT_PID" ] || dot::abort "Could not start ssh-agent for signing."
  export SSH_AUTH_SOCK="$probe/agent" SSH_AGENT_PID="$RELEASE_AGENT_PID"
  ssh-add -q -t "$RELEASE_KEY_LIFETIME" -- "$RELEASE_SIGNING_KEY" \
    || dot::abort "Cannot load $RELEASE_SIGNING_KEY (wrong passphrase, or the file is readable by others: chmod 600)."
  printf 'release signing probe\n' > "$probe/payload"
  ssh-keygen -Y sign -q -f "$RELEASE_PUBLIC_KEY" -n git "$probe/payload" || dot::abort "Cannot sign with $RELEASE_SIGNING_KEY."
  ssh-keygen -Y verify -q -f "$RELEASE_SIGNERS" -I "$RELEASE_AUTHOR_EMAIL" -n git -s "$probe/payload.sig" < "$probe/payload" >/dev/null \
    || dot::abort "$RELEASE_PUBLIC_KEY does not verify signatures made with $RELEASE_SIGNING_KEY."
}

core.modules.release.service::export() {
  local path
  find "$RELEASE_DESTINATION" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
  git archive --format=tar HEAD -- "${RELEASE_PATHSPEC[@]}" | tar -x -C "$RELEASE_DESTINATION"
  for path in ${RELEASE_COPIED[@]+"${RELEASE_COPIED[@]}"}; do
    mkdir -p "$RELEASE_DESTINATION/$(dirname -- "$path")"
    cp -R -- "$path" "$RELEASE_DESTINATION/$path"
  done
}

# Refuses an export holding the project's .env, a known token, or a secret-named
# setting with a literal value; reports path:line only, never what matched.
core.modules.release.service::scan_secrets() {
  local hits
  [ ! -e "$RELEASE_DESTINATION/$(dot::relative "$HOST_ENV_FILE")" ] \
    || dot::abort "$(dot::relative "$HOST_ENV_FILE") is in the export, nothing committed; untrack or exclude it."
  hits=$(
    {
      grep -rInE --exclude-dir=.git -e "$SECRETS_TOKEN_PATTERN" -- "$RELEASE_DESTINATION" || true
      grep -rIniE --exclude-dir=.git -e "$SECRETS_ASSIGNMENT_PATTERN" -- "$RELEASE_DESTINATION" || true
    } | { grep -vF -- "$RELEASE_SECRET_ALLOW" || true; } | cut -d: -f1,2 | sed "s|^$RELEASE_DESTINATION/||" | sort -u
  )
  [ -z "$hits" ] || dot::abort "Possible secrets in export, nothing committed (mark a false positive with $RELEASE_SECRET_ALLOW on its line):
$hits"
}

# git in the release repo as the release author, author and committer alike:
# GIT_AUTHOR_* and GIT_COMMITTER_* in the environment (a Codespace sets the
# committer to GitHub) win over user.name and user.email, and GitHub verifies
# a signature only for a committer email of the signing key's account.
core.modules.release.service::repo_as_author() {
  GIT_AUTHOR_NAME="$RELEASE_AUTHOR_NAME" GIT_AUTHOR_EMAIL="$RELEASE_AUTHOR_EMAIL" \
    GIT_COMMITTER_NAME="$RELEASE_AUTHOR_NAME" GIT_COMMITTER_EMAIL="$RELEASE_AUTHOR_EMAIL" \
    core.modules.release.service::repo "$@"
}

core.modules.release.service::commit() {
  local tag="$1"
  core.modules.release.service::repo add -A
  [ ${#RELEASE_COPIED[@]} -eq 0 ] || core.modules.release.service::repo add -f -- "${RELEASE_COPIED[@]}"
  ! core.modules.release.service::repo diff --cached --quiet || dot::abort "No changes since the last release."
  core.modules.release.service::repo_as_author commit -q -S -m "Release $tag" -m "Source: $(git rev-parse --short HEAD)"
  core.modules.release.service::repo verify-commit HEAD >/dev/null 2>&1 || dot::abort "Release commit is not validly signed by $RELEASE_PUBLIC_KEY; not tagged."
  [ "$(core.modules.release.service::repo log -1 --format='%ae %ce')" = "$RELEASE_AUTHOR_EMAIL $RELEASE_AUTHOR_EMAIL" ] \
    || dot::abort "Release commit is not authored and committed as $RELEASE_AUTHOR_EMAIL; not tagged."
  core.modules.release.service::repo_as_author tag -s "$tag" -m "Release $tag"
  core.modules.release.service::repo verify-tag "$tag" >/dev/null 2>&1 || dot::abort "Tag $tag is not validly signed by $RELEASE_PUBLIC_KEY."
}
