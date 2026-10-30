---
title: Releases
description: Publishing a clean, signed history of your project.
order: 4
---

# Releases

Releases are behind the `featureFlags.release` [feature flag](../configuration/feature-flags.md).

`bash hey release:create` turns the project into a clean, signed public history: each release is one commit in a separate release repo, holding every committed file but the ones you exclude.

```sh
bash hey release:token github                       # save the remote's push token, once
bash hey release:create 1.2.0                       # export, sign, tag; push nothing
bash hey release:create 1.2.0 --push --keep-tokens 15   # ...and push to every remote
bash hey release:push github                        # push, retry or finish a push
bash hey release:token:delete github                # forget a saved token
```

Tokens live in your system's keychain (macOS) or keyring (libsecret), which ask for them with their own prompt; elsewhere they're gpg-encrypted in `.env`, the token asked through pinentry on the terminal and the passphrase by gpg, also on the terminal. dotHey never prompts for a secret itself, and a push hands the token to git through a pipe into git's own credential cache, private to that push. The signing key's passphrase is ssh-add's to ask.

`--force` force-pushes, replacing a remote's history, only once you type that remote's name at a terminal. It stops on uncommitted changes in what it ships, a signing key that doesn't match, anything that looks like a secret, or a remote without a token. It runs no build or tests: do those in your own workflow first.

| Setting | Meaning |
|---|---|
| `release.destination` | The release repo's directory, from the project root |
| `release.exclude` | Paths left out; `"!<path>"` ships a git-ignored one (a build) |
| `release.versionFiles` | `{"<file>": "<JSON path>"}`: where the release writes its version into what it ships, e.g. `{"dist/hey.json": "state.version"}`; the source keeps whatever it holds |
| `release.branch` | The release repo's branch |
| `release.remotes` | `{"<name>": "<https url>"}`, each pushed with its own token |
| `release.signingKey` | The private SSH key's file name in `~/.ssh/`, with its `.pub` next to it |
| `release.authorName`, `release.authorEmail` | The author and committer of release commits |

> [!IMPORTANT]
> For GitHub to show **Verified**, add the signing key's `.pub` to your account as a **signing key**, and use an email verified on that account. dotHey sets the author and committer itself, so a host that overrides `GIT_COMMITTER_*` can't break the signature.
