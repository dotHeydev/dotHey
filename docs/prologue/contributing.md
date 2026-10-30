---
title: Contributing
description: Reporting issues, proposing changes, and running the test suite.
order: 4
---

# Contributing

- **Issues and ideas:** open an issue on [GitHub](https://github.com/dotHeydev/dotHey/issues), with what you did, what you expected, and what happened.
- **Changes:** fork the repo, change what lives in `dist/` (it's what installs ship), and open a pull request with the reason for the change.
- **Docs:** follow the [docs style guide](docs-style-guide.md).

## Running the tests

The suite runs on bash with standard Unix tools. While you work, run only the tests that cover your change; run the whole suite once, before you open the pull request:

```sh
bash tests/run.sh --file kernel                # one test file
bash tests/run.sh --case help                  # the tests whose name contains "help"
bash tests/run.sh                              # everything, with shellcheck
```

## Releasing

The command reference in `docs/reference/` is generated from each command's `--help`. Regenerate it before every release, and commit what changed:

```sh
bash tools/reference.sh                        # rewrites docs/reference/ and its nav entry
bash hey release:create <version>              # ships only what is committed
```
