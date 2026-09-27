---
id: '000084'
status: punt
created: 2026-04-09
updated: 2026-05-05
---

# transcript-driven filesystem reconciliation (backtrack)

## Problem

Parent: [issue 000081](./000081-support-anthropic-tool-use-protocol.md)

Elevate parley's chat transcript from a historical record into a **declarative specification** of the filesystem. The transcript becomes the source of truth; the filesystem state is derived by applying the recorded tool calls against a captured initial state. Editing the transcript re-derives the filesystem.

Mathematically:

```
apply(initial_filesystem, transcript) → current_filesystem
```
