---
id: 000187
status: codecomplete
deps: []
github_issue:
created: 2026-07-14
updated: 2026-07-14
estimate_hours: 2.96
started: 2026-07-14T18:42:45-07:00
actual_hours: 5.12
---

# markdown finder in repo mode should present repo facet search

markdown finder (<C-g>m) should have facet search bar.

check on the implementation and style of chat finder's facet search bar. we should have that in issue finder in repo mode, with:

[ALL] [NONE]   [REPO1] [REPO2] ...

This is similar to issue #186. search terms and filters (facet) should be persisted across finder sessions.


## Problem

Markdown Finder uses one bespoke tag-bar implementation for two different
meanings: top-level directories in ordinary repo mode and repository names in
super-repo mode. The super-repo behavior currently emerges indirectly because
member scanning overwrites each entry's directory tag with its repo name. The
two modes also share module-local selection state, so directory and repository
keys can collide or leak across mode changes, and there is no finder-level test
that defends the intended super-repo UI.

The picker also preserves only structured `{repo}` fragments today. Ordinary
search text is lost when the finder is reopened, despite the desired workflow
being to resume the same Markdown search and facet selection.

## Spec

### Mode-specific facet bar

- In ordinary repo mode, Markdown Finder keeps its existing top-level-directory
  facet bar, including the current first-appearance order derived from
  mtime-sorted entries.
- In super-repo mode, the same bar represents repositories exclusively and is
  rendered as `[ALL] [NONE]   [repo…]`; top-level-directory facets are not mixed
  into that bar.
- Repository roots and labels come from the active `parley.super_repo` runtime
  state API, not by independently interpreting its transient config cache.
  Facets are derived from those roots, not only from the current Markdown result
  rows. A member with no matching Markdown files therefore remains a stable
  facet choice.
- The repo facet bar appears only for a valid multi-repo expansion: member
  labels must be complete and there must be at least two distinct repositories.
- When an active expansion is ineligible for repository facets, keep all rows
  scanned successfully from its members unfiltered and omit the bar. Do not
  substitute directory facets or fall back to single-repo scanning.
- An eligible expansion with no Markdown rows still opens an empty picker with
  its repository bar. A member containing no Markdown files is not an error.

### State and interaction

- Directory facet state and repository facet state are separate. Switching
  between ordinary and super-repo modes cannot reinterpret or overwrite keys
  from the other facet domain.
- Previously unseen facets default to enabled. Temporarily absent facets retain
  their selection so rediscovery does not reset user intent.
- Facet toggles, ALL, and NONE update the existing picker in place without
  changing its live search query.
- NONE may produce an empty picker; the facet bar remains available so ALL can
  restore the results.
- Store the complete prompt query verbatim on every query change, including
  leading/trailing whitespace and the empty string, and pass that exact value as
  the next invocation's `initial_query`. Do not normalize it through
  `finder_sticky`. A facet repaint neither rewrites nor re-emits the query.
- Both mode-specific facet selections persist across finder invocations within
  the current Neovim session. Persistence across Neovim restarts is out of
  scope.
- Mode changes take effect on the next Markdown Finder invocation; live
  reclassification of an already-open picker is out of scope. Both domain
  states remain retained across those invocations.

### Architecture

- Reuse `parley.finder_facets` for discovery, state merging, immutable
  transitions, filtering, projection, and shared facet-set eligibility. Move
  Issue Finder's existing complete-label/multiple-distinct-label eligibility
  rule into that canonical model rather than copying it (`ARCH-DRY`).
- The deterministic Markdown policy accepts the active mode, scanned entries,
  member roots, directory state, and repository state; it returns visible
  entries, projected tags, updated states, and the eligible facet domain without
  reading `_parley`, Vim, or module-local state (`ARCH-PURE`). Filesystem
  scanning, super-repo state lookup, session-state assignment, and
  `float_picker.open/update` remain the thin IO/UI shell. Unit-test the policy
  directly and cover that shell through finder-entry tests.
- Update the finder and super-repo atlas pages whose current text says Markdown
  preserves only structured query fragments (`ARCH-PURPOSE`).

## Done when

- Ordinary repo mode shows only top-level-directory facets.
- Super-repo mode shows only stable repository facets in the requested
  `[ALL] [NONE]   [repo…]` presentation.
- Directory and repository choices persist independently across mode switches
  and finder reopenings; newly discovered repos default on and absent repos keep
  their prior choice.
- Complete search text persists across reopenings and is unchanged by facet
  repaint, including exact whitespace and explicit clearing.
- NONE remains recoverable through ALL from an empty picker.
- Ineligible super-repo expansions remain aggregated but unfiltered, while an
  eligible expansion with zero Markdown rows retains its recoverable repo bar.
- Automated tests cover both modes, eligibility, persistence, mode switching,
  ALL/NONE/toggle behavior, query independence, and empty-result recovery.
- Atlas documentation describes the mode-specific facet and query behavior.

## Estimate

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec         design=0.70 impl=0.04
item: cross-cutting-refactor design=0.20 impl=0.20
item: lua-neovim        design=0.60 impl=0.60
item: atlas-docs        design=0.10 impl=0.08
item: milestone-review  design=0.00 impl=0.20
design-buffer: 0.15
total: 2.96
```

Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md`
against `baseline-v3.1.md`. Method A only. The focused Lua/Neovim primitive
uses the thorough-spec design discount; the cross-cutting primitive covers the
shared eligibility API and Issue Finder migration; and v3.1 scales the selected
high-end implementation hours to 40%. The estimate includes the already
completed issue-spec work, the extensive finder-entry test surface, full
verification, and one single-pass close review. The calibration source is
currently marked stale, so the derived total is provisional pending the
repo-local recalibration tracked by that source.

## Plan

- [x] Write and approve the durable implementation plan.
- [x] Implement the mode-specific Markdown facet adapter with canonical helpers.
- [x] Add finder-level regressions for state, query, and picker behavior.
- [x] Update atlas documentation and run the full verification suite.

## Log

### 2026-07-14
- 2026-07-14: closed — TDD RED evidence captured for shared eligibility, pure Markdown policy, and runtime adapter; fresh focused suites passed 74/74 assertions (finder_facets 17, markdown_finder 15, issue_finder 19, super_repo 23); make lint checked 270 files with 0 warnings/errors; make test passed all 105 unit and 40 integration/architecture spec files; git diff --check, issue validation, atlas traceability review, and stale-claim shadow search were clean. Atlas updated under modes/super_repo, ui/pickers, issues/issue-management, and traceability.; review verdict: FIX-THEN-SHIP

- Recovered the interrupted session at the design checkpoint. Inspection found
  that super-repo scanning already overwrote directory tags with repo names, but
  the behavior was implicit, untested, and shared state across two facet
  domains. Chose an explicit contextual bar—directories in ordinary repo mode,
  repositories in super-repo mode—reusing `finder_facets` and preserving the
  complete in-session query.
- `sdlc change-code` refused the first plan-quality pass: the estimate compressed
  the extensive test/verification surface, example commits omitted required
  trailers, and ordinary directory ordering was not pinned. Revised the plan
  and estimate rather than bypassing the gate.
- Implemented canonical labelled-facet eligibility and source-order discovery,
  then moved Markdown Finder onto a pure contextual policy with a thin runtime
  adapter (`ARCH-DRY`, `ARCH-PURE`). Ordinary mode retains source-ordered
  directory facets; super-repo mode uses root-derived alphabetical repo facets,
  with invalid expansions unfiltered and zero-row/NONE states recoverable.
- Finder-entry regressions drive real temporary Markdown trees, picker updates,
  runtime mode switches, exact whitespace/cleared queries, empty results, and
  source-window selection. Per-task spec and quality reviews passed after adding
  the missing picker identity/selection assertions and correcting two atlas
  eligibility descriptions.
- Verification at `550b180`: `make lint` checked 270 files with zero warnings or
  errors; focused finder suites passed 74/74 assertions; `make test` passed all
  105 unit and 40 integration/architecture spec files; `git diff --check`, issue
  validation, and the stale-claim shadow search were clean.
- Resolved the close review's `FIX-THEN-SHIP` findings by documenting
  `:ParleyMarkdownFinder` / `<C-g>m` in README and correcting both stale module
  comments. The review-run fixture flakes reproduced cleanly in isolation
  (`chat_progress_process_spec.lua` 7/7 and `tools_builtin_find_spec.lua` 4/4),
  then a fresh complete `make test` passed all 105 unit and 40
  integration/architecture spec files. Compacted the generated review sidecar
  to durable findings, resolutions, verdict, and evidence before commit.

## Revisions

### 2026-07-14T20:35:46-07:00 — fresh spec review

Clarified that shared eligibility belongs in `finder_facets`, named the pure
policy and IO/UI shell, specified ineligible and empty super-repo behavior, and
made complete-query persistence verbatim. Also anchored member discovery to the
active `super_repo` runtime state API and scoped mode changes to finder reopen.

### 2026-07-14T21:42:44-07:00 — implementation plan

Added the calibrated v3.1 estimate and durable implementation plan after spec
approval. The plan keeps one close boundary and threads TDD through shared
eligibility, the pure contextual policy, the runtime adapter, and atlas updates.

### 2026-07-14T21:46:57-07:00 — plan review

Corrected focused test commands, made invalid member labels safe at the scan
boundary, expanded picker traceability, and separated post-plan close artifact
handling from implementation checkboxes. Noted that the current calibration
source is stale, so the reconciled estimate remains provisional.

### 2026-07-14T21:50:25-07:00 — change-code refusal

Raised the v3.1 estimate from 1.70 to 2.96 hours using separate
cross-cutting-refactor and high-end focused Lua primitives, made every planned
commit policy-compliant, and specified that ordinary directory facets retain
their existing first-appearance order while repo facets remain alphabetized.

### 2026-07-14T22:28:48-07:00 — implementation complete

Landed the shared facet policy, pure Markdown policy, runtime adapter, 15-test
Markdown suite, and picker/super-repo atlas mappings. Reconciled all durable
plan checkboxes after independent lint, focused, full-suite, diff, schema, and
shadow-search verification; the remaining transition is the binary-owned close
review and close-artifact commit.
