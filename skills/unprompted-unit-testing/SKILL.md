---
name: unprompted-unit-testing
description: Use when writing unit tests the user did not request. Unprompted tests may be flaky or become false positives; keep them in a Trash tests subfolder and tell the user they can delete or promote them after the task.
---

# Unprompted Unit Testing

You may write unit tests without being prompted, but these tests are too likely to be flaky or become false positives in the future.

- Create unprompted tests in a `Trash tests` subfolder of the relevant test project or test directory, using the existing test framework and conventions.
- Do not move existing tests into this folder or place explicitly requested tests there.
- After finishing the task, tell the user where the tests are and that they may delete them by hand or promote them to proper tests.
