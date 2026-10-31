---
name: STANDARDS.md
description: The non-negotiable engineering practices for this codebase, independent of language and framework. Apply them throughout the work — while designing, writing, testing, reviewing, and shipping code.
---

# Engineering Standards

These hold for any language, framework, and platform. The stack's own conventions (`TECHSTACK.md`, and the standards plugins add) refine them, and win where they are stricter.

## Principles
- Weigh every tradeoff in this order: secure, correct, efficient, simple, clear. Never trade an earlier one for a later one without saying so.
- Build the simplest thing that meets today's requirements without compromising the state or the architect of the project. No speculative generality, no abstraction without a second real use.
- One source of truth for every piece of knowledge: a rule, a value, or a format is defined once and referenced everywhere else. Code that only looks alike is not duplication.
- Separate concerns: each module, type, and function has one responsibility and one reason to change. High cohesion inside, low coupling between.
- Explicit over implicit: no hidden side effects, no magic behavior, no surprises for the next reader.
- Make invalid states unrepresentable: validate at the boundary, then let the types and structures inside carry only valid data.

## Architecture
- Structure follows the domain: modules map to the product's concepts and their terms (`DATAMODEL.md`, `NOMENCLATURE.md`), not only to technical layers.
- Dependencies point inward: business logic never depends on frameworks, storage, transport, or UI. Side effects (I/O, network, time, randomness) live at the edges, behind interfaces the core owns.
- Every module exposes a small, deliberate public interface and keeps its internals private. Nothing reaches past it.
- Prefer composition over inheritance, and plain data and functions over class hierarchies.
- State has one owner. Share it by passing it, never through globals or ambient singletons.
- Configuration lives outside the code: environment-specific values come from configuration or the environment, with safe defaults.
- Public contracts (APIs, schemas, events, CLIs, file formats) stay backward compatible. Change them by versioning or migrating, never by breaking callers silently.
- Operations that can be retried or delivered twice are idempotent.

## Writing Code
- Names reveal intent; follow `NOMENCLATURE.md`.
- Code explains itself through names and structure. A comment says why (a constraint, a tradeoff, a non-obvious consequence), never what; no commented-out code.
- Avoid hard-coded, repeated values, magic strings, and magic numbers. Instead: declare constants or configuration values.
- If the same logic appears more than once, abstract it. Avoid repeated logic.
- Use guard clauses (early return, early continue), flatten logic, and extract complex branches into well-named functions. Avoid deeply nested conditionals and control structures.
- Validate early, fail fast, and keep execution paths linear and predictable. Avoid intertwined validation and execution.
- Break logic into readable steps with clear intermediate names and explicit intent. Avoid dense one-liners and compressed expressions.
- Split modules, objects, classes, and functions into focused units that each do one thing well, at one level of abstraction. Avoid god objects, god modules, and multipurpose functions.
- Prefer pure functions and immutable data; isolate mutation and side effects where they are easy to see.
- Use the built-in capability and its established patterns. Avoid reinventing what the language, the standard library, or the framework already provides.
- Delete dead code, unused parameters, and leftovers from a change.
- Always leave the code you touch better than you found it.

## Error Handling
- Fail fast, where the problem is detected, with an error that says what went wrong and what to do about it.
- Never swallow an error. Handle it where something meaningful can be done; otherwise propagate it with context.
- Expected failures (invalid input, not found, conflict, denied) are part of the interface: distinct types or machine-readable codes, never only a message.
- Errors shown to callers never expose secrets, internals, or stack traces.
- Release resources (files, connections, locks) on every path, failure included.
- Every call that leaves the process has a timeout. Retry only idempotent operations, with backoff and a limit.

## Security
- Apply `SECURITY.md` throughout, not just at review time.
- Security is designed in: identify the trust boundaries of every change, and what crosses them, before writing it.

## Data
- Change the shape of persisted data only through the project's migrations: versioned, repeatable, and safe to run while the previous version of the code is still live.
- Enforce integrity where the data lives (constraints, uniqueness, references), not only in application code.
- Writes that must succeed together happen atomically (a transaction, or a compensating action when none is possible).
- Store and compute time in UTC with time zones applied at the edges; money and other exact quantities never in floating point; text in one explicit encoding.
- Collect and keep only the data the product needs, for as long as it needs it (`COMPANY.md` → Compliance).

## Performance & Scalability
- Measure before optimizing, then optimize the bottleneck the measurement shows.
- Know the complexity of hot paths, and pick the data structure that fits the access pattern.
- Bound everything that grows with users, data, or time: paginate, batch, and stream; never load an unbounded set into memory, and never query or call once per item in a loop.
- Cache deliberately: every cache has an owner, an invalidation rule, and an expiry.
- Move slow or heavy work off the path a user waits on.
- Design for more than one instance: no correctness that depends on local memory, local files, or a single process.
- Every shared resource has a limit: pool sizes, queue lengths, rate limits, payload sizes.

## Observability
- Log events, not noise: structured, at a meaningful level, with the context to act on them, and never secrets or personal data.
- An error is logged once, where it is handled, not at every layer it passes through.
- What runs in production is observable: health, key metrics, and failures can be seen without attaching a debugger.

## Dependencies
- Prefer the standard library and what the project already uses; every new dependency must earn its place (`SECURITY.md` → Supply Chain, `RULES.md` → Ask First).
- Pin versions and commit the lockfile, so every environment builds the same thing.
- Wrap a third-party API that much of the code would touch behind an interface the project owns.

## Code Review

- One concern per change, small enough to review in one sitting; no unrelated edits riding along.
- Review your own diff before handing it over: correctness, security, tests, naming, and leftovers.
- A reviewer's question is answered in the code (a clearer name, a test, a comment on why), not only in the conversation.

## Testing

- Only write tests for code changes and run the test suite only when you worked with code in your task. Do not wirte tests neither run the test suite for content nor context changes.
- The full suite is rare: run it once, at the end of a coding round, never after each change.
- Target every run: check the test runner's options (its `--help`, the suite's scripts) for filters by case, file, and directory, and run only the tests that cover the code you changed. Record what you find in `TECHSTACK.md` → Commands.
- Run tests only when executable code changed; a change to docs, comments, help text, or other prose needs no run.
- Every behavior change ships with tests, and every bug fix with a test that reproduces the bug first.
- Write and verify:
  - Golden-path tests: Verify that expected user journeys and core workflows succeed.
  - Edge-case tests: Probe boundary conditions and unusual but valid inputs.
  - Adversarial tests: Check that the system withstands deliberately hostile or manipulative inputs.
  - Negative tests: Confirm that invalid inputs and expected failure conditions are handled safely and correctly.
- A test can always be improved, never weakened: no looser assertion, removed case, or skip to make it pass.
- Most tests are fast unit tests of logic; integration tests cover the boundaries (storage, network, other services); end-to-end tests cover only the critical journeys.
- Tests are deterministic: no real network, clock, randomness, or sleep. Inject them, and mock only what crosses a boundary.
- Avoid hard-coded values in tests. Instead: derive expectations programmatically, detached from incidental values and contexts.
- Test functionality, not content: status and exit codes, state, files, and the structure of output. Assertions test exact codes, statuses, and outcomes, never one of them.
  - Text is no proof of an outcome: a message can be misleading, and its wording changes, so a test asserting it fails for nothing or passes for the wrong reason. 
  - Assert a value only when it is a keyed part of the functionality: an `errors` key in its place in a JSON proves errors were reported, while which error is proven by its code, not its message. 
- Tests depend only on the project and its own fixtures and stubs, never on ignored or external files.

## Critical Paths
_Which parts of the system need extra caution, review, or coverage before changing?_

Until the project names its own, these are critical: authentication and authorization, payments and billing, data migrations and deletions, secrets and cryptography, and public contracts other systems depend on.

## Style & Conventions
_Where do language/style conventions live, and what's the general philosophy?_

- The project's formatter and linter are the authority on style: run them as soon as you're done with the coding part and before the test suite, never hand-format against them.
- Follow the tech stack's conventions (`TECHSTACK.md`, the standards plugins add); consistency with the surrounding code beats personal preference.

## Data Handling
_What rules govern how user data is logged, stored, or passed around in code?_

- Personal and sensitive data is never logged, never sent to a service that doesn't need it, and never copied into fixtures or examples (`SECURITY.md` → Data Handling).

## Definition of Done
_What must be true before a change is considered complete, not just merged?_

- The behavior matches its specification, including its edge and adversarial cases.
- The tests covering it pass, and the full suite passes once, at the end.
- The formatter, linter, and static analysis report nothing new.
- No dead code, debug output, or untracked TODO is left behind.
- The records and context it changed are updated: features, decisions, `DATAMODEL.md`, `SCHEMA.md`.
- Every Critical Path change is reported to the user.
