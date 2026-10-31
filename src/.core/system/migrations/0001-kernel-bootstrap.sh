# shellcheck shell=bash

DESCRIPTION="Points AGENTS.md to dotHey's kernel, moving its guidelines into GUIDELINES.md."

MIGRATION_AGENTS="$DOTHEY_ROOT/AGENTS.md"
MIGRATION_GUIDELINES="$DOTHEY_ROOT/GUIDELINES.md"

migration::bootstrap() {
  cat <<'EOF'
# AGENTS.md

This project is guided by **dotHey**, installed in `.hey/`. Before anything else, read `.hey/.core/KERNEL.md`: it says how dotHey works, which context to load, and how to work here. Then onboard yourself with the `hey-onboarding` skill, especially when the first message is "hey".
EOF
}

# The sections of the old AGENTS.md, from its first "## " heading on, without
# its Onboarding section, which the kernel replaces.
migration::sections() {
  awk '
    /^```/ { fence = !fence }
    !fence && /^## / { started = 1; skipping = ($0 ~ /^## Onboarding[[:space:]]*$/) }
    started && !skipping { print }
  ' "$MIGRATION_AGENTS"
}

migration::write() {
  local file="$1" content="$2"
  printf '%s\n' "$content" > "$file.migrating" && mv -- "$file.migrating" "$file" || { rm -f -- "$file.migrating"; return 1; }
}

migrate() {
  local sections bootstrap
  bootstrap=$(migration::bootstrap)
  if [ ! -f "$MIGRATION_AGENTS" ]; then
    migration::write "$MIGRATION_AGENTS" "$bootstrap"
    return
  fi
  ! grep -qF ".core/KERNEL.md" "$MIGRATION_AGENTS" || return 0
  sections=$(migration::sections) || return 1
  if [ -e "$MIGRATION_GUIDELINES" ] || [ -z "$sections" ]; then
    migration::write "$MIGRATION_AGENTS" "$bootstrap${sections:+

$sections}"
    return
  fi
  migration::write "$MIGRATION_GUIDELINES" "---
name: GUIDELINES.md
description: How to work and communicate in this project: the core principles, the voice, and the reply format. Apply them to every task and every reply.
---

# Guidelines

$sections" || return 1
  migration::write "$MIGRATION_AGENTS" "$bootstrap"
}
