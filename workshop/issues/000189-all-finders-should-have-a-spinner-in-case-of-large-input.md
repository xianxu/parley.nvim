---
id: 000189
status: working
deps: []
github_issue:
created: 2026-07-14
updated: 2026-07-15
estimate_hours:
started: 2026-07-15T17:02:57-07:00
---

# all finders should have a spinner in case of large input

## Problem

Parley's five disk-backed finders—Chat, Note, Issue, Vision, and Markdown—scan
their roots before opening the picker. On a large root or in super-repo mode,
that synchronous work can leave Neovim apparently unresponsive with no visible
indication that discovery is in progress. Markdown Finder is the clearest case:
it repeatedly expands depth globs across every peer and can inspect ignored or
imported package trees that are outside the repository's useful document set.

## Spec

- Scope this work to the five disk-backed finders: Chat, Note, Issue, Vision,
  and Markdown. In-memory agent, model, system-prompt, skill, and similar
  pickers retain their current behavior.
- Every disk-backed finder opens its picker shell synchronously before discovery
  begins. While discovery is pending, the results surface shows an animated
  `scanning…` state using the canonical frames from `parley.progress`; users can
  cancel immediately with the picker's existing controls.
- Loading is a shared picker/session lifecycle rather than five finder-local
  spinners. The shared boundary owns loading/result/error transitions,
  idempotent teardown, cancellation, and generation identity so a late callback
  cannot update or reopen a closed or superseded picker (`ARCH-DRY`).
- Discovery must be genuinely asynchronous. Deferring an unchanged synchronous
  glob/parse call until after the first spinner frame is not sufficient: disk
  enumeration runs off the main event-loop turn, and metadata transformation is
  processed in bounded scheduled batches so timers, input, redraw, and Esc stay
  responsive.
- Results replace the loading state as one complete, deterministically sorted
  set. Do not progressively reorder a list beneath the user's cursor. Existing
  titles, item rendering, sorting, facets, sticky queries, recall, selection,
  delete/move actions, and view cycling remain unchanged after loading.
- Extract deterministic file-list-to-entry policy from filesystem/process glue
  where practical. Finder-specific parsing and rendering remain separate, while
  shared enumeration, batching, and lifecycle mechanics stay reusable and
  injectable (`ARCH-PURE`).
- Markdown discovery runs once per ordinary repo or super-repo member through
  asynchronous Git-aware file listing. It includes tracked and untracked
  non-ignored `*.md` files, honors repository and global Git ignore rules,
  retains `markdown_finder_max_depth`, never descends into `.git`, and does not
  follow symlinked directories. Super-repo labels, aggregation, ordering, and
  repository facets remain unchanged.
- Chat and Note prewarming uses the same asynchronous discovery path as an
  explicit open. If a prewarm is already in flight, opening the finder displays
  the loading picker and joins that work instead of hiding the request or
  starting a duplicate scan.
- Missing optional roots continue to contribute no entries. In a multi-root or
  super-repo scan, a failure in one root preserves successful results from the
  others and emits one bounded warning. If no root can be scanned, the loading
  row becomes a bounded error state and the picker remains cancellable.
- Cancelling a loading picker requests cancellation of owned external work when
  supported and always invalidates its generation. Timers, handles, callbacks,
  and finder `opened` flags are retired exactly once on cancel, completion,
  failure, or picker/window destruction.
- Successful empty discovery ends in the existing `(no matches)` presentation;
  it is distinct from a scan failure. Reopening after cancellation or failure
  starts a fresh session normally.
- Update README and atlas documentation for immediate asynchronous finder
  loading, the five-finder scope, Markdown's Git-ignore-aware boundary, and the
  shared lifecycle (`ARCH-PURPOSE`).

## Done when

- Each of the five disk-backed finder entry points synchronously returns with a
  visible animated loading picker before its injected discovery completes.
- A scheduled sentinel and spinner tick run while a deliberately delayed scan
  is pending, proving the UI is not merely painted before blocking work.
- Esc during loading closes the picker, retires its spinner/session, resets the
  finder `opened` flag, and ignores a later completion; reopening then succeeds.
- Successful, empty, partial-failure, and total-failure scans produce complete
  results, `(no matches)`, bounded warning plus partial results, and bounded
  error state respectively, without leaked timers or duplicate terminal work.
- Chat and Note opens join an in-flight asynchronous prewarm and do not perform
  a duplicate scan.
- Ordinary and super-repo Markdown Finder include tracked and untracked
  non-ignored Markdown files, exclude Git-ignored files and Markdown reachable
  only through symlinked directories, enforce maximum depth, and retain existing
  display labels, sorting, and facets.
- Existing finder interaction regressions remain green after results load, and
  automated tests cover the shared loader plus all five production entry-point
  seams.

## Plan

- [ ] Add the shared loading-picker/session lifecycle and async scan primitives.
- [ ] Move Markdown discovery to Git-aware async listing and bounded entry
  transformation.
- [ ] Wire Chat, Note, Issue, and Vision—including Chat/Note prewarm—to the
  shared lifecycle without changing post-load behavior.
- [ ] Reconcile README/atlas/traceability and run focused, mapped, and full
  verification.

## Log

### 2026-07-14

- Initial request: show progress for large finder inputs, keep Neovim
  responsive, and avoid irrelevant Markdown traversal such as `.git` and
  imported package paths.

### 2026-07-15

- Claimed before design. Scope is the five disk-backed finders only. Approved
  an immediate picker-shell spinner, atomic result replacement, one shared
  cancellation/loading lifecycle, and Git-ignore-aware Markdown discovery that
  does not follow symlinked directories (`ARCH-DRY`, `ARCH-PURE`,
  `ARCH-PURPOSE`).
