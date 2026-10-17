---
id: 000369
status: open
deps: []
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
card_mirror: 'abd65a45d2aa4fed403335bbc29e590943fa7d67' # card fields mirrored from issue-cards; edit via sdlc
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

- [ ]

## Log

Filed from #362's bounded investigation. The local guard already protects its
own invocation; this is independent shared-tool work for another slot.
