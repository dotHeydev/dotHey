---
title: Your first feature
description: A walkthrough from describing a feature to tested, working code.
order: 4
---

# Your first feature

This walkthrough takes one feature from an idea to tested code. It assumes dotHey is [installed](installation.md) and the [context is prepared](preparing-the-context.md).

## 1. Describe it

Tell your agent what you want, in your own words:

> Users should be able to reset a forgotten password by email.

The agent asks whether to document it as a feature, then drafts `.hey/Features/f001--auth-password-reset.md` with its specification: the golden path, the edge cases, and the adversarial ones, in Given/When/Then. It asks only what it can't infer, usually two to four questions with its best guess in each.

## 2. Review the specification

Read the file and correct anything that's off. The specification is what the tests come from, so this is the moment to get it right.

## 3. Let it build

Say *"build it"*. The `hey-build-full-feature` skill asks once whether to stop at each stage or run through, then:

1. drafts the implementation plan into the same file;
2. writes the tests, and runs them to see them fail for the right reason;
3. writes the code, one test at a time, until every test passes;
4. updates the feature's File Map and any decisions it touched.

It stops and asks only for what is yours to decide: a new dependency, a change to the data model, or a plan that turns out wrong.

## 4. Check the result

The agent replies in the same short format every time: what landed, anything that needs your attention, and what you must do next, if anything.

Next: learn the [workflow](../work/workflow.md) in depth.
