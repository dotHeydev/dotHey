---
title: GitHub access
description: How dotHey reaches GitHub for plugins and tasks.
order: 5
---

# GitHub access

Everything dotHey does on GitHub (plugin downloads, tasks kept as issues) takes the first route that works:

1. **`gh`**, as your logged-in account, or as `HEY_GH_TOKEN`'s owner when that's set in `.env`. A token always wins over the login, for this project only.
2. **GitHub's API**, with `HEY_GH_TOKEN`, when `gh` is missing or fails.

When every route fails, one error names each attempt, why it failed, and what to do. Public plugins download without any of this; private repos need read access, and tasks need issues and labels. Releases use their own tokens.
