---
id: 000186
status: working
deps: []
github_issue:
created: 2026-07-14
updated: 2026-07-14
estimate_hours: 2.24
started: 2026-07-14T12:24:51-07:00
---

# issue finder in repo mode should present repo facet search

check on the implementation and style of chat finder's facet search bar. we should have that in issue finder in repo mode, with:

[ALL] [NONE]   [REPO1] [REPO2] ...

## Problem

Issue Finder aggregates issues from every member repository in super-repo mode,
but the only repository discriminator is the `{repo}` prefix embedded in each
result row. Users can type that prefix into the fuzzy query, but cannot quickly
include/exclude repositories, select none, or restore all repositories through
the facet UI already established by Chat Finder. Reopening Issue Finder or
switching between its `issues` and `history` views must not discard either the
typed search or repository selection.

## Spec

### Extract Chat Finder's facet behavior as the canonical model

Chat Finder's current facet behavior and styling are the reference contract.
Extract its deterministic state/filter/projection behavior into a reusable
finder-facet module without changing Chat Finder's visible behavior:

- the picker renders `[ALL] [NONE]   [facet…]` through the existing
  `float_picker` tag bar;
- enabled, disabled, ALL, NONE, and mixed highlighting/click behavior remain
  unchanged;
- entries use OR semantics: an entry survives when any of its facets is
  enabled;
- discovered facets merge into persistent state, with new facets enabled by
  default and prior choices preserved; temporarily undiscovered facet keys
  remain in state so rediscovery restores the user's previous choice;
- facet updates refresh the picker in place without clearing its query.

The reusable module owns deterministic facet-state merging, filtering,
ALL/NONE/toggle transitions, and projection to the picker tag list
(`ARCH-DRY`, `ARCH-PURE`). Finder modules remain thin owners of their persistent
session state and item-specific facet extraction.

Chat Finder consumes the extracted module for its existing tag facets,
including the empty-string untagged facet. Its current ordering, filtering,
state persistence, mouse interaction, and query behavior are regression-locked;
this issue does not redesign them.

### Repository facets in Issue Finder

Issue Finder supplies one facet per repository only when super-repo expansion
returns a complete set of non-empty repository labels for every scanned root
and at least two unique repositories. In ordinary single-root mode it supplies
no facet bar, preserving the existing layout and behavior. A partially labelled
or unlabelled expanded root set fails closed to the existing unfiltered picker:
the entire repo facet bar is omitted and no repository filtering is applied.
It must never show a partial bar whose NONE action leaves unrepresented rows
visible or impossible to re-enable.

Repository facet labels use the same deterministic ordering as the canonical
facet model. The Issue Finder session owns one shared
`repo_facet_state` across both `issues` and `history` views. Switching views,
closing/reopening the finder, changing the fuzzy query, or toggling facets does
not reset the other state. Newly discovered super-repo members default enabled
without re-enabling a repository the user disabled earlier.

Issue scanning, the existing issues/history partition, and view-specific sort
run as today. Repository facet filtering then selects rows by `issue.repo_name`;
the fuzzy picker query applies to the resulting items. Facet clicks use the
existing in-place picker update so the complete typed query and current finder
session remain intact (`ARCH-PURPOSE`). ALL enables every repository, NONE
disables every repository, and an individual button toggles only that
repository.

### Reuse boundary for #187

#187 is not implemented here. It must be able to adopt the extracted facet
model for Markdown Finder repository facets without changing the model API or
copying Chat/Issue Finder policy. Item-to-facet mapping stays injected so tags,
repositories, and future facet kinds can share the same state machine while
retaining finder-specific entries and persistent state.

### Documentation and safety

Update the Issue Finder lifecycle/behavior map and traceability for the shared
facet model and super-repo repository bar. No new user notification or error
path is introduced: incomplete repository labelling omits the entire bar and
preserves the unfiltered picker. README changes are required only if an existing user-facing Issue
Finder description mirrors the changed super-repo behavior.

## Done when

- Chat Finder uses the extracted reusable facet model with no visible or state-behavior regression.
- With a completely labelled super-repo root set containing at least two unique repositories, Issue Finder shows the existing `[ALL] [NONE]` facet-bar style followed by one toggle per repository; incomplete labelling omits the entire bar and repo filtering.
- Repository toggles, ALL, and NONE filter Issue Finder rows in place with OR semantics while preserving the complete typed query.
- Repository facet state persists across closes/reopens and across both `issues` and `history` views; newly discovered repositories default enabled without resetting prior choices.
- Single-root Issue Finder remains unchanged and has no repository facet bar.
- Pure tests pin facet merging/filtering/transitions/projection, and production-shaped tests cover Chat Finder compatibility plus Issue Finder super-repo filtering and persistence.
- The shared boundary is directly reusable by #187 without copying finder-specific facet policy.
- Atlas and traceability describe the new shared surface and Issue Finder behavior.

## Estimate

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: lua-neovim             design=0.4 impl=0.4
item: lua-neovim             design=0.4 impl=0.4
item: cross-cutting-refactor design=0.12 impl=0.14
item: atlas-docs             design=0.025 impl=0.05
item: milestone-review       design=0.02 impl=0.14
design-buffer: 0.15
total: 2.24
```

The two Lua/Neovim primitives cover the reusable facet model plus Chat Finder
adapter and the production-shaped Issue Finder repository-facet integration.
The cross-cutting refactor item covers replacing Chat Finder's inline policy
while preserving its established behavior. Design uses the thorough-spec
discount; implementation values use the v3.1 40% ship-wall-clock calibration.
No library shortcut applies because this extends the repo's existing Lua and
float-picker surfaces. The calibration source is currently marked stale, so
the number is provisional pending #127's recalibration.

*Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against
`baseline-v3.1.md`. Method A only.*

## Plan

- [ ] Extract and regression-lock Chat Finder's canonical facet model.
- [ ] Integrate persistent repository facets into super-repo Issue Finder.
- [ ] Cover single-root, multi-root, query, view, reopen, and new-repository behavior.
- [ ] Update atlas/traceability and pass focused plus full verification.

## Log

### 2026-07-14

Claimed and designed the issue. The approved direction extracts Chat Finder's
existing facet behavior unchanged, reuses it for persistent Issue Finder
repository facets only in super-repo mode, and keeps the boundary generic for
#187 (`ARCH-DRY`, `ARCH-PURE`, `ARCH-PURPOSE`).

### 2026-07-14 — spec review revision

Fresh-context review found mixed labelled/unlabelled roots ambiguous. The spec
now omits the entire facet bar and all repo filtering unless every expanded
root has a non-empty label and at least two unique repositories are present.
It also preserves temporarily undiscovered facet keys so rediscovery restores
the prior selection.

## Revisions

### 2026-07-14T12:45:00-07:00 — fresh-context spec review

- Reason: partial root labelling left ALL/NONE and unrepresented row behavior
  undefined; rediscovery persistence was only implicit.
- Delta: require a complete multi-repository label set before enabling the bar,
  otherwise retain the existing unfiltered picker, and explicitly retain
  undiscovered facet-state keys.

### 2026-07-14T17:01:00-07:00 — code-entry plan-quality gate

- Reason: finder adapter fakes could not directly prove that the real picker's
  live prompt and fuzzy query survive an in-place facet update.
- Delta: add a production-shaped real `float_picker` regression before adapter
  changes, while retaining adapter tests that prove facet callbacks use that
  update path.
