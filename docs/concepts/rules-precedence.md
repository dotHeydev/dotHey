---
title: Rules precedence
description: How dotHey's rules sit beneath your organization's policies and above personal preferences.
order: 2
---

# Rules precedence

**dotHey is not a harness**, so it doesn't enforce a hierarchy of rules on its own. It assumes your organization provisions its own policies, and that dotHey sits beneath them. When rules conflict, agents are told to flag the conflict, never to resolve it silently.

The recommended precedence, highest first:

1. **Organization policies.** Provisioned on your system by your organization; ideally read-only for you.
2. **Project guidelines** (dotHey). Agreed by the team and committed with the project.
3. **User preferences.** Yours alone, in `.hey/USER.md`, ideally not committed.
