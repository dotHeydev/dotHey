---
title: bash hey release:*
description: Every release command, with its usage, options, and examples.
order: 9
---

# bash hey release:*

## `release:create`

Make a signed release commit in the release repo.

```text
Exports every file committed in HEAD, minus release.exclude, into the release
repo as one signed commit tagged v<version>, and pushes it only where --push
says. It runs no build or tests: do those first.

Usage:
  bash hey release:create <version> [--push [<remote>,...]] [options]

Arguments:
  <version>                 A semantic version, like 1.2.0 or 1.2.0-rc.1.

Options:
  --push [<remote>,...]     Optional. Push to every remote, or to those named,
                            without asking (names are release.remotes' keys).
                            Without it, nothing is pushed.
  --keep-tokens <minutes>   Optional. Keep the unlocked tokens that many
                            minutes, so pushes until then don't ask for the
                            passphrase (0 forgets them).
  --force                   Optional. Force-push, replacing the remotes'
                            history; each remote's name must be typed to
                            confirm, at a terminal.
  -h, --help                Show this help.

Examples:
  bash hey release:create 1.2.0
  bash hey release:create 1.2.0 --push github
  bash hey release:create 1.2.0 --push --keep-tokens 15

Settings:
  In .hey/hey.json; any of them may be "@env:<KEY>".

  release.destination   The release repo's directory, from the project root.
  release.exclude       Paths left out; "!<path>" ships a git-ignored one.
  release.versionFiles  {"<file>": "<JSON path>"}: where the release writes
                        <version> in what it ships.
  release.branch        The release repo's branch.
  release.remotes       {"<name>": "<https url>"}, at least one.
  release.signingKey    The private SSH key's file name in ~/.ssh/.
  release.authorName    The name on release commits.
  release.authorEmail   The email on release commits; GitHub only shows
                        "Verified" when the signing key's account owns it.

Notes:
  - It stops on uncommitted changes in what it ships, a key that doesn't match,
    anything that looks like a secret, or a --push remote with no token.
  - The project's .env never ships. Save tokens with bash hey release:token.
```

## `release:push`

Push the release to its remotes.

```text
Pushes the release repo's branch and tags, asking remote by remote; use it to
retry or finish a release's push. Each remote uses its own token.

Usage:
  bash hey release:push [<remote>...] [--all] [options]

Arguments:
  <remote>                  Push to that remote without asking; repeatable or
                            comma-separated. Names are release.remotes' keys.

Options:
  --all                     Optional. Push to every remote without asking.
  --keep-tokens <minutes>   Optional. Keep the unlocked tokens that many minutes
                            (0 forgets them).
  --force                   Optional. Force-push, replacing the remotes'
                            history; each remote's name must be typed to
                            confirm, at a terminal.
  -h, --help                Show this help.

Examples:
  bash hey release:push
  bash hey release:push github
  bash hey release:push --all --keep-tokens 15

Notes:
  - Without a terminal it pushes only to the remotes given, or all with --all.
```

## `release:token`

Save the token a release remote pushes with.

```text
Asks for a remote's personal access token (never as an argument) and saves it
encrypted for that remote's url: in the macOS keychain, the desktop keyring,
or, without either, gpg-encrypted in .env with a passphrase you choose.

Usage:
  bash hey release:token <remote>

Arguments:
  <remote>     The remote, a key of release.remotes in .hey/hey.json.

Options:
  -h, --help   Show this help.

Examples:
  bash hey release:token github

Notes:
  - Give the token write access to the release repo, and nothing else.
  - Saving again replaces it; a changed remote url needs a new one.
  - bash hey release:token:delete <remote> removes it.
```

## `release:token:delete`

Remove the token a release remote pushes with.

```text
Removes the token saved for a remote's url by bash hey release:token.

Usage:
  bash hey release:token:delete <remote>

Arguments:
  <remote>     The remote, a key of release.remotes in .hey/hey.json.

Options:
  -h, --help   Show this help.

Examples:
  bash hey release:token:delete github
```
