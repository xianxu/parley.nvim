---
id: 000189
status: working
deps: []
github_issue:
created: 2026-07-14
updated: 2026-07-15
estimate_hours: 3.2
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
  In-memory metadata parsing is scheduled in slices bounded by injected item and
  monotonic-time budgets before yielding to the event loop. One file's
  already-read payload remains the atomic parsing unit; the implementation plan
  owns the concrete budgets and their deterministic test clocks.
- The shared loader takes an immutable snapshot of roots and finder options plus
  an injected asynchronous producer. It synchronously publishes `loading`, and
  settles exactly once with one of four outcomes: `success(records)`,
  `partial(records, failed_root_count, failed_record_count)`,
  `failure(failed_root_count)`, or `cancelled`. Records are finder-specific raw
  discovery/metadata values, not rendered picker items. Each subscriber applies
  its own immutable open-time options through a deterministic materializer
  after settlement. The producer returns an idempotent cancellation handle; the
  session exposes cancellation/subscription and rejects every repeated or stale
  settlement. A root counts as successful even when it contains zero matches.
- Enumeration failure makes the whole root fail and discards every record
  staged for that root. After successful enumeration, an individual async
  stat/read or parser failure discards only that record and increments
  `failed_record_count`; other records and roots continue. Any record failure,
  or any failed root beside at least one successful root, produces `partial`.
  `failure` means every attempted root failed enumeration. A successfully
  enumerated root whose every record later fails therefore settles as partial
  with an empty record set, not as total failure.
- A per-file adapter returns exactly `record`, intentional `skip`, or
  `failure(kind)`. Expected nonmatches and benign policy exclusions are skips
  and do not inflate failure counts. Failure kinds are static bounded enums;
  arbitrary thrown values, raw file payloads, and process bodies are never
  converted into diagnostics.

  | Session state | Event | Required effect |
  |---|---|---|
  | loading | subscribe | register one subscriber for the immutable snapshot |
  | loading | producer settles | store one outcome and deliver it once to every live subscriber |
  | loading | owned picker cancels | invalidate generation, unsubscribe, and invoke producer cancel once |
  | loading | joined-prewarm picker cancels | invalidate/unsubscribe only; prewarm keeps ownership |
  | settled | subscribe before session retirement | replay the stored outcome once |
  | settled/cancelled | repeated settle or cancel | no-op |

  A normal picker-owned session retires after delivery or cancellation. The
  separate prewarm retention/cache rule below governs its ownerless terminal.
- Results replace the loading state as one complete, deterministically sorted
  set. Do not progressively reorder a list beneath the user's cursor. Existing
  titles, item rendering, primary sort order, facets, sticky queries, recall,
  selection, delete/move actions, and view cycling remain unchanged after
  loading. When primary sort values tie, every finder uses one shared path-key
  policy as the stable secondary key: `realpath` when available, otherwise
  normalized absolute path; separators normalized to `/`; compared as
  case-sensitive UTF-8 bytes with no locale collation.
- Before sorting, canonical-key collisions are deduplicated independently of
  async arrival order. The retained record is the minimum deterministic source
  tuple `(ordered root ordinal, normalized unresolved absolute path)`; tests
  cover overlapping roots and symlink aliases.
- Loading and total-failure presentation is picker status, not a synthetic item:
  it bypasses fuzzy/sticky-query filtering, never enters the selectable item
  list, and ignores confirm/double-click. A retained query therefore cannot hide
  `scanning…` or the error state. Only settled success/partial records are
  materialized and installed as selectable items.
- The visible prompt query remains live while loading. Query edits/clears update
  the finder's existing sticky/query state immediately and are never restored
  from the open-time snapshot. Settlement materializes the complete item/facet
  domain from immutable scan/recency options, installs it, then filters with the
  prompt buffer's current query. Facet state may be snapshotted because facet
  controls do not exist until their settled domain is installed.
- Extract deterministic file-list-to-entry policy from filesystem/process glue
  where practical. Finder-specific parsing and rendering remain separate, while
  shared enumeration, batching, and lifecycle mechanics stay reusable and
  injectable (`ARCH-PURE`).
- Markdown discovery runs once per ordinary repo or super-repo member through
  asynchronous Git-aware file listing. Its inclusion set is all tracked `*.md`
  files (even if a current ignore rule also matches them) union untracked
  non-ignored `*.md` files. Repository and global Git ignore rules therefore
  govern untracked discovery exactly as Git does. Discovery retains
  `markdown_finder_max_depth`, never descends into `.git`, and does not
  follow symlinked directories. Depth is counted from the member root by path
  components: a root-level file has depth 1, matching the existing glob policy.
  Nested repositories and submodules are opaque to the parent listing and are
  not descended; a super-repo member is listed only by its own Git invocation.
  A missing Git executable, a root that is not a Git worktree, or a non-zero Git
  listing exit is that root's scan failure; there is no ignore-violating
  filesystem fallback. Listing uses NUL-delimited output and incremental stream
  parsing, so paths containing newlines remain one record. A non-zero exit
  discards every staged stdout path for that root. Super-repo labels,
  aggregation, ordering, and repository facets otherwise remain unchanged.
- Chat and Note prewarming uses the same asynchronous discovery path as an
  explicit open. If a prewarm is already in flight, opening the finder displays
  the loading picker and subscribes to that producer instead of hiding the
  request or starting a duplicate scan. The prewarm owns its work: cancelling a
  joined picker only unsubscribes and invalidates that picker generation; it
  does not cancel the shared prewarm. Success, partial failure, or total failure
  from the prewarm settles every still-live subscriber through the same outcome
  contract. A picker joins only when its shared path-key-normalized root list
  and discovery-policy fingerprint exactly equal the immutable prewarm snapshot.
  That fingerprint contains finder kind, ordered normalized root records
  (path/label/primary identity), traversal recursion/depth, filename pattern,
  and backend-affecting enumeration options; recency, facets, and live query are
  materializer/UI policy and are excluded. A mismatch starts a separate
  picker-owned producer while the prewarm continues. Prewarm
  produces the complete unfiltered raw metadata set. Each joined opener
  snapshots its own current recency/cutoff and facet options and materializes
  that shared set independently, so joining never applies stale prewarm-time UI
  policy or repeats concurrent disk discovery. Once an ownerless prewarm
  settles, its terminal records are not
  replayed as a later picker's result: only the existing per-file mtime metadata
  cache remains. A later open always performs fresh asynchronous enumeration,
  prunes cache entries no longer present, and reuses unchanged metadata; changed
  mtimes are reread. Ownerless partial/total prewarm failure is logged once and
  not cached as a terminal outcome, so the next open retries normally.
- Missing optional roots continue to contribute no entries. In a multi-root or
  super-repo scan, a failure in one root preserves successful results from the
  others and emits one warning. An absent optional directory is skipped rather
  than attempted, and all-absent optional roots therefore produce successful
  `(no matches)`. A configured root that is attempted but cannot be enumerated
  is a failure; if every attempted root fails, the loading state becomes an error
  status and the picker remains cancellable. Existing required-root
  misconfiguration checks still warn and return before opening a picker.
- Cancelling a loading picker requests cancellation of owned external work when
  supported and always invalidates its generation. Timers, handles, callbacks,
  and finder `opened` flags are retired exactly once on cancel, completion,
  failure, or picker/window destruction.
- Successful empty discovery ends in the existing `(no matches)` presentation;
  it is distinct from a scan failure. Reopening after cancellation or failure
  starts a fresh session normally.
- A partial outcome emits at most one user warning per finder session; a total
  failure replaces loading with one nonselectable error status. Each message is
  bounded, reports only the finder name plus aggregate failed-root and
  failed-record counts, and never includes raw process output. Per-root
  technical diagnostics may be logged,
  but capture is bounded at the source: stderr readers and the one incomplete
  NUL path fragment retain only their configured caps, and an overlong fragment
  fails that root. Per-session diagnostic count is capped with one bounded
  omitted-count summary. Before display/logging, diagnostic text replaces
  control characters with spaces and truncates at a valid UTF-8 boundary. The
  implementation plan owns the concrete byte/count budgets.
- The parser batcher accepts an injected monotonic clock, checks budgets between
  atomic records, and yields before beginning the next record after either
  budget is exhausted. No wall-clock guarantee is claimed inside one atomic
  parser call.
- Update README and atlas documentation for immediate asynchronous finder
  loading, the five-finder scope, Markdown's Git-ignore-aware boundary, and the
  shared lifecycle (`ARCH-PURPOSE`).

## Done when

- Each of the five disk-backed finder entry points synchronously returns with a
  visible animated loading picker before its injected discovery completes.
- A scheduled sentinel and spinner tick run while a deliberately delayed scan
  is pending, proving the UI is not merely painted before blocking work.
- Injected async read/stat completion plus a metadata set exceeding both slice
  limits proves, with a controlled monotonic clock, that parsing checks budgets
  between atomic records and yields before beginning the next out-of-budget
  record; later slices resume without dropping or duplicating entries.
- Esc during loading closes the picker, retires its spinner/session, resets the
  finder `opened` flag, and ignores a later completion; reopening then succeeds.
- Successful, empty, partial-failure, and total-failure scans produce complete
  results, `(no matches)`, bounded warning plus partial results, and bounded
  nonselectable error state respectively, without leaked timers or duplicate
  terminal work. All-absent optional roots are specifically covered as a
  successful empty scan.
- A failed stat/read/parser drops only its record and yields partial success;
  failed root enumeration drops that root's staged records; total failure occurs
  only when every attempted root fails enumeration.
- Intentional per-record skips remain distinct from failures and never increase
  warning/error counts; thrown adapter values collapse to static failure kinds
  without stringifying arbitrary data.
- Chat and Note opens join an in-flight asynchronous prewarm without duplicating
  its scan only for an exactly matching normalized root/policy snapshot;
  mismatches start independent work. Different opener recency snapshots
  materialize matching raw prewarm records independently. After prewarm settles
  without a subscriber, a later open re-enumerates, reuses only unchanged mtime
  metadata, prunes stale cache entries, and retries prior partial/total failures.
- Ordinary and super-repo Markdown Finder include all tracked Markdown files
  plus untracked non-ignored Markdown files, exclude ignored untracked files and
  Markdown reachable only through symlinked directories, treat nested
  repos/submodules as opaque, enforce root-relative component depth, fail safely
  when Git listing is unavailable, and retain existing display labels, primary
  sorting, and facets.
- NUL-delimited Git process fakes cover newline-bearing filenames, incremental
  chunks, non-zero exit with staged stdout, bounded stderr/pending fragments,
  tracked-but-ignored files, global excludes, nested repositories, submodules,
  and root-relative depth.
- Equal primary sort values resolve by canonical item path for deterministic
  ordering in all five finders; canonical-key collisions deduplicate by the
  deterministic source tuple before sorting.
- Existing finder interaction regressions remain green after results load, and
  automated tests cover the shared loader plus all five production entry-point
  seams.
- Loading and error status remains visible under a retained query and cannot be
  selected or confirmed through keyboard or mouse paths.
- Text typed or cleared while loading remains the visible/stored query and is
  applied to settled items; completion never restores the invocation-time
  query.

## Plan

- [ ] M1 — Add shared scan/session/picker primitives and ship Markdown as the
  first Git-aware asynchronous vertical slice.
- [ ] M2 — Migrate Chat and Note, including exact-snapshot joinable prewarm and
  metadata-only settled cache retention.
- [ ] Migrate Issue and Vision, reconcile docs/atlas/traceability, and run
  focused, mapped, full, and manual verification before the final issue-close
  boundary.

## Estimate

```estimate
model: estimate-logic-v3.1
familiarity: 1.5
item: lua-neovim              design=0.40 impl=0.40
item: tui-screen              design=0.25 impl=0.26
item: cross-cutting-refactor  design=0.12 impl=0.14
item: real-api-discovery      design=0.00 impl=0.18
item: atlas-docs              design=0.10 impl=0.05
item: milestone-review        design=0.10 impl=0.36
design-buffer: 0.15
total: 3.20
```

Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md`
against `baseline-v3.1.md`. Method A only. Design values apply the thorough-spec
discount; implementation values are already scaled to 40% of the v2/v2.1
primitive table. Familiarity is 1.5 because streaming libuv/Git cancellation is
novel-but-bounded in this Lua codebase. The calibration source was stale on
2026-07-15, so the estimate is provisional.

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

### 2026-07-15 — second fresh-context spec review

- Reason: review found unresolved coupling between prewarm and opener options,
  possible query/selection treatment of lifecycle rows, ambiguity for tracked
  files matching ignore rules, and a nondeterministic 5ms acceptance oracle.
- Delta: made producers return raw metadata for per-subscriber pure
  materialization; moved loading/error into nonfilterable, nonselectable picker
  status; defined Markdown inclusion as tracked union non-ignored untracked;
  and specified an injected monotonic clock checked between atomic records.

### 2026-07-15 — third fresh-context spec review

- Reason: review found undefined per-record failure effects, completed-prewarm
  freshness/replay, cross-platform tie comparison, and diagnostic capture/log
  volume.
- Delta: record failures now produce partial results while root enumeration is
  transactional; completed prewarm retains only an mtime metadata cache and
  later opens re-enumerate; a shared normalized bytewise path key owns ties;
  Git paths stream NUL-delimited with bounded fragments/stderr; and per-session
  technical diagnostic count is capped.

### 2026-07-15 — fourth fresh-context spec review

- Reason: review found that a changed root set could incorrectly join an
  in-flight prewarm and that a query edited during loading could be overwritten
  by immutable opener options.
- Delta: joining now requires an exact normalized root/discovery-policy snapshot
  match; mismatches start independent work. Query stays live in the prompt and
  is applied only after settled items install. Diagnostics also sanitize control
  characters and truncate on UTF-8 boundaries.

### 2026-07-15 — fifth fresh-context review and operator decision

- Reason: the fifth permitted review still found canonical-key collisions,
  underspecified prewarm-policy equality, and record exceptions reaching the
  diagnostic path. The operator approved proceeding without a sixth review and
  agreed that numeric batching/buffer constants belong in the implementation
  plan rather than the product spec.
- Delta: added arrival-order-independent deduplication, enumerated the exact
  discovery fingerprint, defined `record`/`skip`/static `failure(kind)`, and
  moved concrete time/item/byte/count budgets to the durable plan while retaining
  the responsiveness and source-bounded invariants.

### 2026-07-15 — durable implementation planning

- Reason: the approved spec spans shared UI lifecycle, two IO backends, five
  production finders, prewarm ownership, process fakes, and documentation, so a
  checkable multi-boundary plan is required before source changes.
- Delta: added the canonical durable plan, two intermediate milestones plus the
  final issue-close boundary, concrete operational budgets, and an estimate
  derived from estimate-logic-v3.1 rather than memory.
