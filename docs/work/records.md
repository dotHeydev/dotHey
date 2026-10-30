---
title: Records
description: Features, decisions, notes, and tasks: the numbered documents that outlive the chat.
order: 4
---

# Records

Records are the project's numbered documents, each in its own directory of `.hey/`, each created by a command that picks the next number and the file name for you.

| Record | Directory | Created with |
|---|---|---|
| Feature | `Features/fNNN--slug.md` | `bash hey features:create` |
| Decision | `Decisions/dNNN--slug.md` | `bash hey decisions:create` |
| Note | `Notes/nNNN--slug.md` | `bash hey notes:create` |
| Xray | `Xrays/xNNN--slug.md` | `bash hey xrays:create` |
| Task | `Tasks/tNNN--slug.md`, or GitHub issues | `bash hey tasks:create` |

## Features

A feature is a specification: what to build, its constraints, the decisions it relies on, and, once planned, how to build it. The template's sections become flags:

```sh
bash hey features:create "Password reset" \
  --description "Lets a user reset a forgotten password by email." \
  --specification "Given a registered user… When… Then…" \
  --related-features 7
```

## Decisions

A decision is a rule the project has settled, written as one first-person sentence anyone can obey: *"We keep the session JWT in an httpOnly cookie."* Decisions link the ones that shaped them and the features they affect, and dotHey keeps those links honest.

```sh
bash hey decisions:create "JWT in httpOnly cookie" \
  --statement "We keep the session JWT in an httpOnly cookie." \
  --explanation "Every authenticated response sets it as one." \
  --status accepted --influenced-by 002 --impacts 7

bash hey decisions:impact 002,005                  # the features citing these decisions
bash hey decisions:impact --term session,jwt       # the docs mentioning these terms
bash hey decisions:citers 004                      # the decisions pointing at 004
bash hey decisions:update 002 --status superseded --by 007
bash hey decisions:check                           # every link between decisions resolves
```

## Notes

A note parks an idea for later, with no commitment. Without a name it gets a random one, like `swift-otter`.

```sh
bash hey notes:create "Cache idea"
```

## Tasks

Tasks live in the service you choose with `bash hey tasks:initialize`: plain files in `.hey/Tasks/`, or GitHub issues labelled `task`. Every `tasks:*` command works the same either way.

```sh
bash hey tasks:create "Throttle failed logins" --description "Brute-force attempts aren't throttled."
bash hey tasks:list --status todo,doing --sort updated --order desc
bash hey tasks:doing t004
bash hey tasks:update t004 --done-when "- [x] lock after 5" --status done
```
