#!/usr/bin/env bash

# What looks like a secret, and the same text with each one masked.

# Known token formats, matched as written.
SECRETS_TOKEN_PATTERN='sk-or-v1-[A-Za-z0-9]{32,}|sk-ant-[A-Za-z0-9_-]{32,}|sk-(proj-)?[A-Za-z0-9_-]{32,}|BEGIN [A-Z ]*PRIVATE KEY|AKIA[0-9A-Z]{16}|hf_[A-Za-z0-9]{30,}|gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|glpat-[A-Za-z0-9_-]{20,}|npm_[A-Za-z0-9]{36}|xox[abposr]-[A-Za-z0-9-]{10,}|[rs]k_live_[A-Za-z0-9]{20,}|AIza[0-9A-Za-z_-]{35}|eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'
# Any secret-named key given a literal value holding a digit with at least 8
# characters on one side of it, as generated secrets do and names, words,
# and prefixes don't; matched in any case: API_KEY=…, "client_secret": "…",
# password: …
SECRETS_ASSIGNMENT_PATTERN='(^|[^A-Za-z0-9_])[A-Za-z0-9_]*(SECRET|TOKEN|PASSWORD|PASSWD|API_?KEY|ACCESS_KEY|PRIVATE_KEY|AUTH)[A-Za-z0-9_]*["'"'"']?[[:space:]]*[:=][[:space:]]*["'"'"']?([A-Za-z0-9+/_.~-]{8,}[0-9][A-Za-z0-9+/_.~-]*|[A-Za-z0-9+/_.~-]*[0-9][A-Za-z0-9+/_.~-]{8,})'
SECRETS_VALUE_PATTERN='[A-Za-z0-9+/_.~-]+$'
SECRETS_MASK="******"
# How much of a masked token or value stays readable, to tell which one it was.
SECRETS_TOKEN_KEPT=6
SECRETS_VALUE_KEPT=4
SECRETS_MAX_MASKS=100

# <text> with every known token cut to its first characters and the value of
# every secret-named key likewise, then the mask: "TOKEN=pat-h2******". Runs
# in the shell, no process spawned.
framework.helpers.secrets::mask() {
  local text="$1" match value replacement count=0 case_rule
  while [ "$count" -lt "$SECRETS_MAX_MASKS" ] && [[ "$text" =~ $SECRETS_TOKEN_PATTERN ]]; do
    match="${BASH_REMATCH[0]}"
    replacement="${match:0:$SECRETS_TOKEN_KEPT}$SECRETS_MASK"
    text=${text//"$match"/$replacement}
    count=$((count + 1))
  done
  case_rule=$(shopt -p nocasematch)
  shopt -s nocasematch
  while [ "$count" -lt "$SECRETS_MAX_MASKS" ] && [[ "$text" =~ $SECRETS_ASSIGNMENT_PATTERN ]]; do
    match="${BASH_REMATCH[0]}"
    [[ "$match" =~ $SECRETS_VALUE_PATTERN ]] || break
    value="${BASH_REMATCH[0]}"
    replacement="${match%"$value"}${value:0:$SECRETS_VALUE_KEPT}$SECRETS_MASK"
    text=${text//"$match"/$replacement}
    count=$((count + 1))
  done
  eval "$case_rule"
  printf '%s' "$text"
}
