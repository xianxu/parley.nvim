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
  enumeration plus stat/read operations use asynchronous process/libuv APIs.
  In-memory metadata parsing is scheduled in slices capped by both 25 files and
  5ms of elapsed work, whichever comes first, before yielding to the event loop.
  One file's already-read payload remains the atomic parsing unit; the bound
  prevents a large file set from monopolizing timers, input, redraw, or Esc.
- The shared loader takes an immutable snapshot of roots and finder options plus
  an injected asynchronous producer. It synchronously publishes `loading`, and
  settles exactly once with one of four outcomes: `success(items)`,
  `partial(items, failed_root_count)`, `failure(failed_root_count)`, or
  `cancelled`. The producer returns an idempotent cancellation handle; the
  session exposes cancellation/subscription and rejects every repeated or stale
  settlement. A root counts as successful even when it contains zero matches.
- Results replace the loading state as one complete, deterministically sorted
  set. Do not progressively reorder a list beneath the user's cursor. Existing
  titles, item rendering, primary sort order, facets, sticky queries, recall,
  selection, delete/move actions, and view cycling remain unchanged after
  loading. When primary sort values tie, every finder uses canonical absolute
  item path ascending as the stable secondary key.
- Extract deterministic file-list-to-entry policy from filesystem/process glue
  where practical. Finder-specific parsing and rendering remain separate, while
  shared enumeration, batching, and lifecycle mechanics stay reusable and
  injectable (`ARCH-PURE`).
- Markdown discovery runs once per ordinary repo or super-repo member through
  asynchronous Git-aware file listing. It includes tracked and untracked
  non-ignored `*.md` files, honors repository and global Git ignore rules,
  retains `markdown_finder_max_depth`, never descends into `.git`, and does not
  follow symlinked directories. Depth is counted from the member root by path
  components: a root-level file has depth 1, matching the existing glob policy.
  Nested repositories and submodules are opaque to the parent listing and are
  not descended; a super-repo member is listed only by its own Git invocation.
  A missing Git executable, a root that is not a Git worktree, or a non-zero Git
  listing exit is that root's scan failure; there is no ignore-violating
  filesystem fallback. Super-repo labels, aggregation, ordering, and repository
  facets otherwise remain unchanged.
- Chat and Note prewarming uses the same asynchronous discovery path as an
  explicit open. If a prewarm is already in flight, opening the finder displays
  the loading picker and subscribes to that producer instead of hiding the
  request or starting a duplicate scan. The prewarm owns its work: cancelling a
  joined picker only unsubscribes and invalidates that picker generation; it
  does not cancel the shared prewarm. Success, partial failure, or total failure
  from the prewarm settles every still-live subscriber through the same outcome
  contract.
- Missing optional roots continue to contribute no entries. In a multi-root or
  super-repo scan, a failure in one root preserves successful results from the
  others and emits one warning. An absent optional directory is skipped rather
  than attempted, and all-absent optional roots therefore produce successful
  `(no matches)`. A configured root that is attempted but cannot be enumerated
  is a failure; if every attempted root fails, the loading row becomes an error
  state and the picker remains cancellable. Existing required-root
  misconfiguration checks still warn and return before opening a picker.
- Cancelling a loading picker requests cancellation of owned external work when
  supported and always invalidates its generation. Timers, handles, callbacks,
  and finder `opened` flags are retired exactly once on cancel, completion,
  failure, or picker/window destruction.
- Successful empty discovery ends in the existing `(no matches)` presentation;
  it is distinct from a scan failure. Reopening after cancellation or failure
  starts a fresh session normally.
- A partial outcome emits at most one user warning per finder session; a total
  failure replaces loading with one nonselectable error row. Each message is at
  most 240 bytes, reports only the failed-root count and finder name, and never
  includes raw process output. Per-root technical diagnostics may be logged,
  but each is independently truncated to 240 bytes. Confirming an error/empty
  status row performs no selection action.
- Update README and atlas documentation for immediate asynchronous finder
  loading, the five-finder scope, Markdown's Git-ignore-aware boundary, and the
  shared lifecycle (`ARCH-PURPOSE`).

## Done when

- Each of the five disk-backed finder entry points synchronously returns with a
  visible animated loading picker before its injected discovery completes.
- A scheduled sentinel and spinner tick run while a deliberately delayed scan
  is pending, proving the UI is not merely painted before blocking work.
- Injected async read/stat completion plus a metadata set exceeding both slice
  limits proves parsing yields after 25 files or 5ms and later resumes without
  dropping or duplicating entries.
- Esc during loading closes the picker, retires its spinner/session, resets the
  finder `opened` flag, and ignores a later completion; reopening then succeeds.
- Successful, empty, partial-failure, and total-failure scans produce complete
  results, `(no matches)`, bounded warning plus partial results, and bounded
  nonselectable error state respectively, without leaked timers or duplicate
  terminal work. All-absent optional roots are specifically covered as a
  successful empty scan.
- Chat and Note opens join an in-flight asynchronous prewarm and do not perform
  a duplicate scan.
- Ordinary and super-repo Markdown Finder include tracked and untracked
  non-ignored Markdown files, exclude Git-ignored files and Markdown reachable
  only through symlinked directories, treat nested repos/submodules as opaque,
  enforce root-relative component depth, fail safely when Git listing is
  unavailable, and retain existing display labels, primary sorting, and facets.
- Equal primary sort values resolve by canonical item path for deterministic
  ordering in all five finders.
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

## Revisions

### 2026-07-15 — fresh-context spec review

- Reason: review found that the first draft named the shared architecture but
  left responsiveness bounds, loader outcomes, joined-prewarm ownership,
  missing-root behavior, Git edge cases, deterministic ties, and bounded error
  presentation insufficiently precise for implementation planning.
- Delta: defined async stat/read seams plus 25-file/5ms parsing slices; an
  exactly-once four-outcome loader contract; subscriber-only cancellation for
  joined prewarms; success/failure rules for absent versus attempted roots;
  Git/depth/nested-repo behavior; canonical-path tie-breaking; and 240-byte,
  nonselectable failure presentation.
