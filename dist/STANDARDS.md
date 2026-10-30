---
name: STANDARDS.md
description: The non-negotiable engineering practices for this codebase. Apply them throughout the work — while writing code, while reviewing it, and before shipping it.
ignore: true
---

# Engineering Standards

## Writing Code
- Avoid code comments and comment blocks — the code must be clear and understandable by itself.
- NEVER write line comments!
- Avoid hard-coded, repeated values, magic strings, and magic numbers. Instead: declare variables, constants, or configuration values.
- Avoid repeated logic. Instead: if something appears more than once, abstract it.
- Avoid deeply nested conditionals and control structures. Instead: use guard clauses (early return / early continue), flatten logic, and extract complex branches into well-named methods.
- Avoid deeply nested validations and intertwined execution logic. Instead: validate early, fail fast, and keep execution paths linear and predictable.
- Avoid dense one-liners and compressed expressions. Instead: break logic into readable steps with clear intermediate variables and explicit intent.
- Avoid god classes and multi-responsibility superclasses. Instead: enforce SoC and SRP; use services, repositories, concerns, traits, and cohesive components.
- Avoid multipurpose functions/methods. Instead: split logic into focused methods that do one thing well.
- Avoid unnecessary complexity and reinventing framework capabilities. Instead: leverage built-in functionalities and established patterns.
- Avoid hard-coded values in tests. Instead: Write tests programmatically, detached from variable values and contexts.

## Code Review
_What must happen before code merges?_

## Testing
_What level of testing is expected for new work?_

- Run tests only when executable code changed; a change to docs, comments, help text, or other prose needs no run.
- Target every run: check the test runner's options (its `--help`, the suite's scripts) for filters by case, file, and directory, and run only the tests that cover the code you changed.
- The full suite is rare: run it once, at the end of a coding round, never after each change.
- A test can always be improved, never weakened: no looser assertion, removed case, or skip to make it pass.
- Test functionality, not content: status and exit codes, state, files, and the structure of output. An expected failure asserts its exact code, never just that it failed.
- Text is no proof of an outcome: a message can say "all went ok" when it didn't, and its wording changes, so a test asserting it fails for nothing or passes for the wrong reason. Assert a value only when it is a keyed part of the functionality: an `errors` key in its place in a JSON proves errors were reported, while which error is proven by its code, not its message. Text is asserted only when it is the contract itself (a help page's sections, an API's field names).
- Tests depend only on the project and its own fixtures and stubs, never on ignored or external files.

## Critical Paths
_Which parts of the system need extra caution, review, or coverage before changing?_

## Style & Conventions
_Where do language/style conventions live, and what's the general philosophy?_

## Data Handling
_What rules govern how user data is logged, stored, or passed around in code?_

## Definition of Done
_What must be true before a change is considered complete, not just merged?_
