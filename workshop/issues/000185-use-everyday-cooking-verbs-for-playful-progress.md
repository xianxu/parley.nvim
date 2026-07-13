---
id: 000185
status: working
deps: []
github_issue:
created: 2026-07-13
updated: 2026-07-13
estimate_hours: 0.50
started: 2026-07-13T16:32:47-07:00
---

# Use everyday cooking verbs for playful progress

## Problem

Parley's playful pending presentation currently rotates among only three
lowercase phrases: `brewing`, `cooking`, and `dragon-slaying`. The pool becomes
repetitive quickly, its fantasy phrase does not fit the desired everyday voice,
and lowercase copy reads less like a polished status label.

## Spec

- Replace the private `chat_pending` verb pool with the 28 operator-approved,
  capitalized cooking and everyday-life words: Baking, Brewing, Caramelizing,
  Chopping, Concocting, Cooking, Crafting, Cultivating, Fermenting, Garnishing,
  Kneading, Marinating, Mulling, Noodling, Percolating, Puttering, Seasoning,
  Simmering, Sketching, Sprouting, Steeping, Stewing, Tinkering, Toasting,
  Unfurling, Whisking, Working, and Zesting.
- Keep random initial selection, non-current activity rotation, idle rotation,
  spinner frames, reveal/minimum timing, and semantic-status handoff unchanged.
- Keep the list private to the existing Neovim adapter. The pure presentation
  reducer continues receiving the verb array through its existing injection
  boundary (`ARCH-DRY`, `ARCH-PURE`).
- Do not add configuration, provider-specific behavior, or fantasy phrases.

## Done when

- The rendered playful copy uses capitalized words from the approved 28-item
  pool and no longer contains `dragon-slaying`.
- Deterministic adapter tests prove the chooser sees exactly 28 entries and
  render every controlled index in the approved order, plus activity/idle
  rotation across distinct entries.
- Mapped response-progress tests, lint, and the full suite pass.

## Plan

- [x] Add a failing adapter regression for the capitalized approved pool.
- [x] Replace the private pool and update deterministic rendering assertions.
- [x] Complete mapped/full verification and prepare the change for close review and publication.

## Estimate

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec       design=0.08 impl=0.02
item: lua-neovim       design=0.06 impl=0.14
item: milestone-review design=0.07 impl=0.08
design-buffer: 0.05
total: 0.50
```

Derived from the provisional repo-local v3.1 calibration. The change reuses
the established pending adapter and deterministic runtime; implementation is a
private data replacement plus an exact table-driven integration oracle.

## Log

### 2026-07-13

The operator selected a curated everyday/cooking vocabulary and explicitly
approved title-case display. The change reuses the existing injected pool and
rotation machinery; no new entity or public surface is warranted.

Fresh spec review strengthened the pool oracle: three sample words would not
detect an omission, duplicate, or unauthorized extra. The adapter test must
observe a count of 28 and render every chooser index in the approved order
through the existing injection boundary (`ARCH-PURPOSE`).

TDD RED proved the old adapter reported a pool size of 3 instead of 28 and
rendered lowercase `cooking` at controlled index 2. GREEN replaced only the
private production pool, then rendered every approved index with an observed
cardinality of 28 and rotated deterministically through Brewing, Caramelizing,
and Zesting. The mapped response-progress suite, lint (265 files, zero
warnings/errors), serialized full repository suite, and scoped diff check pass.
