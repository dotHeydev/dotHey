---
name: hey-setup
description: Finishes dotHey's setup for this project — links it to the user's harnesses, resumes a setup stopped halfway, splits the harnesses' instruction files into dotHey's docs, settles top-level docs no harness claims, and checks the integration. Use it when `bash hey adopt --scan --json` shows `setup.harnesses` empty or `setup.pending` holding any item other than `context`, or when the user asks to set up, link, or relink dotHey, or to add a harness. Filling the project's context files is `hey-context`'s job, not this one's.
license: MIT
metadata:
  internal: true
  author: dotHey
---

# dotHey Setup

Output exactly:
```
⚙️⚙️⚙️ SETTING UP DOTHEY
```

## Goal
dotHey linked to the harnesses the user works with, and nothing left in `setup.pending` but `context`, which is `hey-context`'s. Nothing outside `.hey/` is moved, deleted, or rewritten without the user's go-ahead.

## 0. Read the state
Reuse the scan the start-up checks just ran; otherwise run `bash hey adopt --scan --json` once. Read:

- `setup.harnesses`, `setup.type`, `setup.location`: the user's choices.
- `setup.pending`: what is left, in order.
- `detected`: the harnesses found in the project.
- `items`: what the harnesses' places already hold (instructions, skills, agents, rules).

## 1. Link the harnesses
Only when `setup.harnesses` is `[]`. Ask in one Interview Tool round:

- Which harnesses, those in `detected` first.
- Only when `items` lists skills or agents: `centralize` or `parallel` (see step 3).

Check the flags with `bash hey setup --help --json`, apply with `bash hey setup --harness <a,b> --type <type> --yes`, then run the scan again. If the command says it needs a person at a terminal, hand the user that exact command and stop.

## 2. Confirm what is left
When `setup.harnesses` wasn't empty, one plain message first: what the user chose and what is left, e.g. "You set dotHey up for Claude Code and Codex, centralizing your skills. I'll finish it: propose how to split CLAUDE.md, and check every harness reads what moved. Go ahead?"

Skip it when the user's message already asks for setup. If they decline, stop here: change nothing, and report what is still left.

## 3. Know the type
`setup.type` is how the user wants dotHey to treat the project's existing context:

- **`parallel`:** the project's files stay the source. Leave them where they are; take into dotHey's docs only what the user confirms, as a summary or a reference to the file, never moving or deleting it.
- **`centralize`:** dotHey becomes the source. Once the user confirms, move a file's content into the dotHey doc it belongs to, and leave behind only what its harness needs (the import or link setup added).
- **`null`:** no one chose yet. Ask which of the two they intend before changing anything outside `.hey/`.

## 4. Work through `setup.pending`
One item at a time, in order. Run `bash hey setup:done <item>` as each is finished, and also when the user decides to leave it, so nothing is raised twice.

- **`apply`:** setup stopped halfway; only setup clears it, and it comes before anything else. Rerun it with the recorded choice: `bash hey setup --harness <setup.harnesses> --type <setup.type> --yes`, then scan again.
- **`context`:** not this skill's. Leave it pending for `hey-context`.
- **`split:<path>`** (centralize): propose, part by part, where the file's content belongs (`RULES`, `STANDARDS`, `TECHSTACK`, ...), flagging every conflict with dotHey's docs. Move what the user approves; leave the file with only what its harness needs.
- **`unsure:<path>`:** a top-level doc no harness claims (`IDEAS.md`, `QUALITY.md`, ...). Raise all of them in one message, each with your guess (fold into a context doc, reference it, keep it out, or make it a note), and ask whether they belong to the project's context. Read one only once the user says it does, then act on it per the type.
- **`verify`** (centralize): `bash hey link --preview` says everything is linked, and a fresh scan lists none of the moved items back in a harness's places as real files. Point out any agent in `.hey/Agents/` with `tools` or `model` in its frontmatter: those fields don't port between harnesses. Fix what isn't right with dotHey's commands, or tell the user what is wrong.

Change links only through `links` in `.hey/hey.json` followed by `bash hey link`, or through `bash hey setup` for a harness's links; never with your own scripts or `ln`. `skip` in `links` is the user's: add to it only when they ask.

## 5. Report
In the reply format of `DOTHEY.md`:

- ✅ The harnesses linked, and what moved or was referenced.
- ⚠️ What the user chose to leave, and what didn't go as planned.
- ❌ A command that failed, with its output.
- 🔷 A command the user must run themselves.

Output exactly:
```
✅✅✅ DOTHEY IS SET UP
```

Then stop: touch no other file and code nothing. Go on with the next start-up check in `DOTHEY.md`.
