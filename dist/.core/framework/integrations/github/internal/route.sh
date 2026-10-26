#!/usr/bin/env bash

# The one way every GitHub operation runs: through gh first, as
# DOT_GH_TOKEN's owner when it is set (it always takes precedence) or else
# the logged-in user; then, with DOT_GH_TOKEN set, through the API as the
# same owner, never falling back to the gh login. When every route fails, one
# error names each attempt, its reason, and what to do.

dot::use framework.integrations.github.internal.cli framework.integrations.github.internal.api

GITHUB_TOKEN_KEY="DOT_GH_TOKEN"

framework.integrations.github.internal.route::has_token() {
  dot::secret "$GITHUB_TOKEN_KEY" >/dev/null 2>&1
}

# Whether some route can run as someone: gh with a token or a login, or the
# API with a token.
framework.integrations.github.internal.route::is_ready() {
  framework.integrations.github.internal.route::has_token && return 0
  framework.integrations.github.internal.cli::is_installed && framework.integrations.github.internal.cli::is_logged_in
}

# A short reason for an attempt's error text.
framework.integrations.github.internal.route::reason() {
  local error="$1"
  case "$error" in
    *"rate limit"* | *"HTTP 429"*) printf 'rate-limited by GitHub' ;;
    *"HTTP 401"* | *"Bad credentials"* | *"auth login"* | *"not logged"*) printf 'not authorized (the token or login is invalid or expired)' ;;
    *"HTTP 403"*) printf 'forbidden (the account lacks access, or the token the scope)' ;;
    *"HTTP 404"* | *"Could not resolve to a"* | *"Not Found"* | *"not found"*) printf 'not found, or no access to it' ;;
    *"network"* | *"Could not resolve host"* | *"connect"* | *"timed out"* | *"Timeout"*) printf 'no connection to GitHub' ;;
    "") printf 'failed' ;;
    *) printf '%s' "$(printf '%s\n' "$error" | sed -n '1p')" ;;
  esac
}

# What to do, from the routes there were and how the last one failed.
framework.integrations.github.internal.route::advice() {
  local reason="$1" token="$2" installed="$3" logged_in="$4"
  if [ -z "$token" ] && ! $installed; then
    printf 'Please install gh (https://cli.github.com) and run gh auth login, or set %s in .env.' "$GITHUB_TOKEN_KEY"
    return
  fi
  if [ -z "$token" ] && ! $logged_in; then
    printf 'Please run gh auth login, or set %s in .env.' "$GITHUB_TOKEN_KEY"
    return
  fi
  case "$reason" in
    rate-limited*) printf 'Please wait for the rate limit to reset, then try again.' ;;
    "not authorized"*) [ -n "$token" ] && printf 'Please renew %s in .env.' "$GITHUB_TOKEN_KEY" || printf 'Please run gh auth login again.' ;;
    forbidden* | "not found"*) printf 'Please check that the repo exists and that the account can read it (a token needs that scope).' ;;
    "no connection"*) printf 'Please check the network connection.' ;;
    *) printf 'Please try again; if it keeps failing, run it with gh directly to see why.' ;;
  esac
}

# Runs <operation> (one of internal/cli.sh and internal/api.sh, same name and
# arguments) to <what>; prints its output, or raises the error and fails.
framework.integrations.github.internal.route::run() {
  local what="$1" operation="$2" token installed=false logged_in=false who errors output attempts="" reason=""
  shift 2
  token=$(dot::secret "$GITHUB_TOKEN_KEY" 2>/dev/null) || token=""
  errors=$(mktemp) || return 1
  who="as your gh login"
  [ -z "$token" ] || who="as $GITHUB_TOKEN_KEY's owner"
  if framework.integrations.github.internal.cli::is_installed; then
    installed=true
    [ -n "$token" ] || ! framework.integrations.github.internal.cli::is_logged_in || logged_in=true
    if [ -n "$token" ] || $logged_in; then
      if output=$("framework.integrations.github.internal.cli::$operation" "$@" 2>"$errors"); then
        rm -f -- "$errors"
        [ -z "$output" ] || printf '%s\n' "$output"
        return 0
      fi
      reason=$(framework.integrations.github.internal.route::reason "$(cat -- "$errors")")
      attempts="gh $who: $reason"
    else
      attempts="gh: not logged in"
    fi
  else
    attempts="gh: not installed"
  fi
  if [ -n "$token" ]; then
    if output=$("framework.integrations.github.internal.api::$operation" "$@" 2>"$errors"); then
      rm -f -- "$errors"
      [ -z "$output" ] || printf '%s\n' "$output"
      return 0
    fi
    reason=$(framework.integrations.github.internal.route::reason "$(cat -- "$errors")")
    attempts="$attempts; API as $GITHUB_TOKEN_KEY's owner: $reason"
  else
    attempts="$attempts; API: no $GITHUB_TOKEN_KEY set"
  fi
  rm -f -- "$errors"
  dot::raise "Couldn't $what." "   Tried ${attempts//; /$'\n'   Tried }" "$(framework.integrations.github.internal.route::advice "$reason" "$token" "$installed" "$logged_in")"
}
