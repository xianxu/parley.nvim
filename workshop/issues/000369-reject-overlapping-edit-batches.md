---
id: 000369
status: codecomplete
deps: []
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
card_mirror: 'd6c7bf0bb6c56a7d2e6715c6705cdb292f5fbf66' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-16T21:03:50-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "115ddbc9", done: "ac38b154"}
actual_hours: 0.04
---

# Reject overlapping edit batches

## Problem

Found while implementing #362's local chat protection. The shared pure
parley.skill_edits.compute_edits accepts overlapping old_string spans,
positions every edit against the original content, then applies them in
reverse order without rejecting overlap. A shorter nested replacement shifts
later bytes into an earlier replacement's original range, damaging text outside
the intended span while returning ok=true.

Concrete input: content is alpha followed by newline, # Chat, newline, secret.
Edits are alpha -> x and pha -> empty. Current result is xChat followed by
newline and secret: the heading prefix and boundary newline were consumed.
#362's local invocation-owned validator rejects overlaps, but other callers of
the shared edit engine remain exposed. Do not depend on model instructions.

## Spec

Reject overlapping replacements atomically in the shared edit engine. Adjacent
and disjoint edits keep their existing behavior. A failed batch must leave the
artifact unchanged through both synchronous and asynchronous tool paths.

## Done when

- A pure regression for the concrete overlapping batch fails before the fix,
  then returns a clear overlap error with no content result.
- Containment, partial overlap, identical spans, adjacency and disjoint spans
  are covered; real tool IO confirms atomic refusal without backup or write.

## Plan

Quick flow. Once every edit has its unique position, `skill_edits.compute_edits` sorts the edits by start and refuses the batch when an edit starts before the previous one ends, or at the same start. A same start covers identical spans and zero-length old_strings, whose order would be ambiguous. The error names both edits by their batch numbers, and the result has no content. Adjacent edits (one starts exactly where the previous ends) and disjoint edits behave as before. Both IO paths, `propose_edits.handler` (sync) and `async_builtin.file_body` (async), already return before the backup and the write when the transform fails; specs pin that for an overlapping batch.

- [x] Pure specs (tests/unit/skill_edits_spec.lua):
  - the issue's reproducer is refused with no content (red before the fix);
  - containment, partial overlap and identical spans are refused, in either batch order;
  - adjacency and disjoint spans apply as before.
- [x] The overlap check in compute_edits.
- [x] Sync IO spec: an overlapping batch leaves the file unchanged and writes no backup.
- [x] Async IO spec: the same through execute_async on the fake tool filesystem.

## Log


- 2026-10-16: closed — Pure specs: the issue reproducer (alpha then pha) and the containment, partial-overlap, identical-span and same-start shapes in both batch orders are refused, with no content and the pair named; adjacent and disjoint spans apply as before. All six were red before the fix. IO: propose_edits.handler (sync) and execute_async on the fake tool filesystem (async) both return the overlap error with the file unchanged and no backup. With the guard removed, all eight new specs fail. skill_edits, propose_edits, async_builtin, file_transform and review specs green; lint clean.; review verdict: SHIP
Filed from #362's bounded investigation. The local guard already protects its
own invocation; this is independent shared-tool work for another slot.
- 2026-10-16: the six overlap specs failed before the fix and pass after it. With the guard removed, the reproducer, all four shapes, the named-pair spec and both IO specs fail. The skill_edits, propose_edits, async_builtin, file_transform and review specs are green.

