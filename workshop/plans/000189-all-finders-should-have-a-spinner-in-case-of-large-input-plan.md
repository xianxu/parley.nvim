# Asynchronous Disk-Backed Finders Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Open Chat, Note, Issue, Vision, and Markdown pickers immediately with an animated scanning status while bounded asynchronous discovery runs, with Git-aware Markdown inclusion.

**Architecture:** Introduce one pure scan-policy module and two narrow IO adapters: a libuv filesystem source for Parley artifacts and a streaming Git source for Markdown. A shared loader session connects those producers to a status-capable `float_picker`, owns cancellation/generation identity, and materializes one immutable result set at settlement; each finder retains its existing rendering, facets, actions, and query policy.

The only legal pipeline is:

```text
enumerate candidate paths
  → async stat/read enrichment
  → SliceBatcher invokes finder adapter
  → accumulate root/record outcomes
  → FinderLoadSession settles once with raw finder metadata
  → subscribers apply total pure recency/facet/render materialization
```

No subscriber or picker bridge performs parsing or other failure-counting work
after settlement. A prewarm shares the settled raw finder metadata, never
unparsed file payloads and never rendered items.

**Estimate allocation:** M1 shared core + Markdown is 8.0 hours; M2 Chat/Note is
4.5 hours; the final Issue/Vision/docs/integration slice is 4.1 hours, totaling
16.6. After M1, a measured cumulative actual outside 5.6–10.4 hours (±30%)
requires an appended estimate Revision before M2. After M2, a cumulative actual
outside 8.75–16.25 hours (±30% around 12.5) requires the same revision before
the final slice.

**Tech Stack:** Lua, Neovim `vim.uv`/`vim.loop`, `uv.spawn`, plenary/busted tests, Git `ls-files` NUL streams.

---

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `ScanSnapshot` | `lua/parley/finder_scan.lua` | new |
| `ScanOutcome` | `lua/parley/finder_scan.lua` | new |
| `PathIdentity` | `lua/parley/finder_scan.lua` | new |
| `DiagnosticPolicy` | `lua/parley/finder_scan.lua` | new |
| `MarkdownPathPolicy` | `lua/parley/markdown_finder.lua` | new |
| `ChatFinderRecord` | `lua/parley/chat_finder_records.lua` | new |
| `NoteFinderRecord` | `lua/parley/note_finder_records.lua` | new |
| `IssueFinderRecord` | `lua/parley/issue_finder_records.lua` | new |
| `VisionFinderRecord` | `lua/parley/vision_finder_records.lua` | new |

- **`ScanSnapshot`** — immutable finder kind, ordered normalized root records, and backend-affecting discovery options used for producer identity.
  - **Relationships:** one snapshot owns 1:N roots; one loading session owns exactly one snapshot; multiple subscribers may join one matching prewarm snapshot.
  - **DRY rationale:** Chat and Note must compare precisely the same producer identity, and every finder needs stable root ordinals.
  - **Future extensions:** add a backend option only when it changes which raw records discovery can return; UI query/facets never enter this entity.

  The snapshot is an opaque proxy over closure-private deep-copied data. Its
  public API is `fingerprint()` and `copy()`; `copy()` always returns a new deep
  copy, assignment to the proxy errors, and neither callers nor sessions receive
  the private table. `FinderLoadSession` exposes only `fingerprint()` and
  `snapshot_copy()` delegates.
- **`ScanOutcome`** — the closed `success`/`partial`/`failure` settlement algebra plus aggregate root/record failure counts. Cancellation retires a session without publishing an outcome.
  - **Relationships:** one session settles to at most one outcome; an outcome owns 0:N raw records and is replayed once to each live subscriber.
  - **DRY rationale:** all five finders need identical empty/partial/failure semantics.
  - **Future extensions:** new presentation detail belongs in bounded diagnostics, not additional terminal states.
- **`PathIdentity`** — canonical comparison key (`realpath` or normalized absolute path) plus deterministic unresolved source tuple.
  - **Relationships:** one raw file record has one identity; N colliding records reduce to one winner before sorting.
  - **DRY rationale:** deduplication and tie-breaking must not vary across asynchronous producers or finders.
  - **Future extensions:** platform-specific separator normalization remains isolated here.

  It is strictly string-pure:

  ```lua
  M.path_identity({
      unresolved_absolute = "/lexical/path",
      resolved_absolute = "/optional/async-realpath/result",
      root_ordinal = 1,
  })
  ```

  `AsyncFileSource` performs optional asynchronous `fs_realpath`; lookup failure
  supplies no `resolved_absolute` and is a benign fallback, not a path-identity
  IO dependency or record failure.
- **`DiagnosticPolicy`** — sanitizes static failure kinds and bounded technical messages.
  - **Relationships:** one session retains at most ten diagnostics; each stored/logged diagnostic is at most 512 bytes and one omitted-count summary is allowed.
  - **DRY rationale:** process and filesystem failures need one non-leaking boundary.
  - **Future extensions:** structured debug sinks may consume the same bounded records.

  `finder_scan.FAILURE_KIND` is the only failure vocabulary:

  ```lua
  {
      root_enumeration = "root_enumeration",
      stat = "stat",
      open = "open",
      read = "read",
      parse = "parse",
      invalid_adapter_result = "invalid_adapter_result",
      adapter_exception = "adapter_exception",
      process_spawn = "process_spawn",
      process_stream = "process_stream",
      process_exit = "process_exit",
      path_fragment_too_long = "path_fragment_too_long",
      invalid_path = "invalid_path",
      invalid_read_policy = "invalid_read_policy",
      read_policy_exception = "read_policy_exception",
      producer_acquire_exception = "producer_acquire_exception",
      producer_finalize_exception = "producer_finalize_exception",
      producer_cache_hook_exception = "producer_cache_hook_exception",
      producer_factory_exception = "producer_factory_exception",
      subscriber_exception = "subscriber_exception",
      materializer_exception = "materializer_exception",
      terminal_hook_exception = "terminal_hook_exception",
      retire_hook_exception = "retire_hook_exception",
  }
  ```

  IO sources and all five adapters import these values; they do not introduce
  finder-local strings. Expected filename/suffix/policy nonmatches remain
  `skip`, not failures.
- **`MarkdownPathPolicy`** — transforms NUL-delimited Git paths into depth-checked Markdown candidates and deterministic picker entries.
  - **Relationships:** one member root yields 0:N relative paths; one path belongs to exactly one member invocation.
  - **DRY rationale:** ordinary and super-repo mode must apply identical inclusion/depth rules.
  - **Future extensions:** additional tracked document extensions widen the suffix predicate, not Git invocation semantics.
- **`ChatFinderRecord`** — converts cached metadata or ten already-read header lines plus path/stat/root identity into a raw chat record, then materializes it for one opener's recency/facets.
  - **Relationships:** one canonical path+mtime resolves to either one cached-metadata input or one newly-read-lines input, never both.
  - **DRY rationale:** cache/read decisions and display/query policy no longer live inside the 900-line UI entry point.
  - **Future extensions:** additional cached header fields widen this record only.
- **`NoteFinderRecord`** — classifies an enumerated path/stat/root record and materializes it for one opener's recency policy.
  - **Relationships:** one file produces one record or one intentional template skip.
  - **DRY rationale:** recursive path classification/cache behavior is independently testable from UI orchestration.
  - **Future extensions:** new special folders extend classification data.
- **`IssueFinderRecord`** — parses an already-read issue payload plus filename/stat metadata without filesystem calls.
  - **Relationships:** one Markdown file produces zero or one issue record.
  - **DRY rationale:** synchronous `issues.scan_issues` and the async finder share interpretation without adding another responsibility to `issues.lua`.
  - **Future extensions:** vocabulary validation remains outside discovery.
- **`VisionFinderRecord`** — produces one file-level bundle containing the
  namespace/file/root identity and the 0:N initiatives parsed from an
  already-read YAML payload; its total materializer deduplicates bundles by file
  identity before flattening initiatives.
  - **Relationships:** one YAML file produces exactly one bundle, then 0:N
    initiatives. Each flattened initiative carries its source file identity and
    stable parser ordinal; its secondary key is the length-prefixed file key plus
    ordinal, so initiatives from one file cannot collide during sorting.
  - **DRY rationale:** synchronous vision commands and the async picker retain one policy without growing the 2,000-line `vision.lua` domain module.
  - **Future extensions:** alternate vision formats would add adapters, not IO to the pure parser.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `AsyncFileSource` | `lua/parley/async_file_source.lua` | new | libuv directory/stat/open/read/realpath APIs |
| `AsyncOperationQueue` | `lua/parley/async_operation_queue.lua` | new | shared concurrency/cancellation cap for libuv requests |
| `AsyncFileEnrichment` | `lua/parley/async_file_enrichment.lua` | new | shared stat/realpath/read-policy/open/read/close pipeline |
| `GitMarkdownSource` | `lua/parley/git_markdown_source.lua` | new | streaming `git ls-files` subprocesses |
| `FinderProducer` | `lua/parley/finder_producer.lua` | new | shared acquisition-to-settlement orchestration |
| `FinderLoadSession` | `lua/parley/finder_loader.lua` | new | producer ownership, subscribers, scheduling, warnings, and picker lifecycle |
| `SliceBatcher` | `lua/parley/finder_batcher.lua` | new; re-exported by `finder_scan.new_batcher` | injected monotonic clock and event-loop scheduler |
| `PickerStatus` | `lua/parley/float_picker.lua` | modified | results-buffer status rendering and local spinner timer |
| `PickerStatusController` | `lua/parley/picker_status.lua` | new | status state and timer lifecycle |
| `FakeGitFileList` | `tests/fixtures/fake_git_file_list` | new | process-level Git stdout/stderr/chunk/exit behavior |

- **`SliceBatcher`** — stateful scheduled adapter controller that yields after
  25 completed records or 5ms of injected monotonic time.
  - **Injected into:** `FinderProducer`; unit tests inject a deterministic clock
    and scheduler, while production uses the Neovim event loop.
  - **Future extensions:** budgets may become configuration only if profiling
    shows a user-facing need.

- **`AsyncFileSource`** — asynchronously traverses configured roots without following directory symlinks, with at most 16 filesystem operations in flight and idempotent cancellation.
  - **Injected into:** finder producers through `finder_loader`; tests use a deterministic callback fake while integration tests exercise real libuv temp directories.
  - **Future extensions:** alternate filename predicates and recursion depth are snapshot options.
  - **Path-list enrichment:** `read_paths(opts, on_complete)` owns Markdown's
  asynchronous stat/realpath/read acquisition. Cancellation, record failures,
  and concurrency are identical to traversal.

  Exact acquisition API:

  ```lua
  local handle = async_file_source.scan({
      roots = opaque_snapshot:copy().roots,
      recurse = true,
      max_depth = 4,
      match = function(relative, entry_type) return true end,
      read = "none" or "all" or { head_lines = 10 },
      read_policy = nil or function(stat_record) return read_decision end,
      concurrency = 16,
  }, on_root, on_complete)

  local enrich_handle = async_file_source.read_paths({
      root = root_record,
      root_ordinal = 1,
      paths = { "relative/from/root.md" },
      read = "none" or "all" or { head_lines = 10 },
      read_policy = nil or function(stat_record) return read_decision end,
      concurrency = 16,
  }, on_complete)

  handle:cancel()       -- idempotent; suppresses every future callback
  handle:is_cancelled()
  ```

  `read` and `read_policy` are mutually exclusive. After async stat/realpath and
  before queueing any open/read, `read_policy(stat_record)` returns exactly one
  of:

  ```lua
  { kind = "ready", value = opaque_cached_value }
  { kind = "read", mode = "all" or { head_lines = 10 } }
  { kind = "none" }
  ```

  `ready` emits a candidate with `precomputed = value` and performs no open/read;
  `read` asynchronously fills `payload`; and `none` emits stat metadata only.
  The policy is a synchronous injected cache lookup with no mutation or IO.
  Invalid results and exceptions become per-record `invalid_read_policy` and
  `read_policy_exception` failures without stringifying thrown values. The
  cancellation token is checked after policy evaluation and again before a
  queued read begins, so cancellation between phases suppresses IO and every
  later callback.

  `scan` calls `on_root(event)` exactly once per ordered root, though root events
  may arrive in any order, then `on_complete()` exactly once after every root
  event. Cancellation suppresses both callbacks. Event schemas are:

  ```lua
  { root_ordinal, status = "skipped", reason = "absent_optional" }
  { root_ordinal, status = "failed",
    failure = { kind = FAILURE_KIND.root_enumeration, diagnostic = bounded } }
  { root_ordinal, status = "success", candidates = { enriched_record... },
    failures = { record_failure... } }

  enriched_record = {
      root, root_ordinal, relative,
      unresolved_absolute, resolved_absolute, -- resolved may be nil
      stat, payload, precomputed, -- exactly the fields selected by read policy
  }
  record_failure = {
      relative, unresolved_absolute,
      kind = FAILURE_KIND.stat|open|read,
      diagnostic = bounded,
  }
  ```

  `read_paths` calls its `on_complete({ candidates, failures })` once and has no
  root-enumeration status because successful Git listing already established the
  root boundary. Both APIs return the same cancellation-handle shape.
- **`GitMarkdownSource`** — spawns one Git command per member, incrementally parses NUL records, caps stderr at 4096 bytes and the pending unterminated path fragment at 16384 bytes, and discards staged stdout on non-zero exit.
  - **Injected into:** Markdown producer; the executable/runtime is replaceable so tests run the process-level fixture.
  - **Future extensions:** cancellation and concurrency remain per-root even if Git gains another listing mode.

  Exact process API:

  ```lua
  local handle = git_markdown_source.list({
      root = "/repo",
      root_ordinal = 1,
      executable = "git",
      env = nil,
  }, function(result) end)

  success = { root_ordinal, status = "success", paths = { raw_relative... } }
  failure = { root_ordinal, status = "failed",
      failure = { kind = FAILURE_KIND.process_spawn|process_stream|
          process_exit|path_fragment_too_long, diagnostic = bounded } }
  handle:cancel()
  handle:is_cancelled()
  ```

  Completion runs exactly once asynchronously unless cancelled. `paths` remain
  raw NUL-framed relative strings for the pure Markdown path policy; any failure
  discards staged paths.
- **`FinderProducer`** — one thin injected runner used by every finder; it owns
  acquisition event consumption, root/record accumulation, sliced adapter
  execution, final dedup/sort, cache hooks, composite cancellation, and one
  settlement call.
  - **Injected into:** each `FinderLoadSession.producer_factory`; filesystem
  finders inject `AsyncFileSource.scan`, while Markdown injects a small
  acquisition function that composes Git `list` with `read_paths` but emits the
  identical root event schema.
  - **Future extensions:** new disk-backed finders provide acquisition, adapter,
  and total finalizer functions without copying lifecycle code.

  Exact runner API:

  ```lua
  local handle = finder_producer.run({
      roots = opaque_snapshot:copy().roots,
      acquire = function(on_root, on_complete) return acquisition_handle end,
      adapter = function(enriched_candidate) return record_or_skip_or_failure end,
      finalize = function(records) return deterministic_raw_records end,
      batch = { item_budget = 25, time_budget_ms = 5,
          now = monotonic_now, schedule = schedule },
      on_record = function(raw_record) end, -- optional cache update
      on_root_success = function(root_ordinal, seen_keys) end, -- optional prune
      diagnostic = function(kind) end, -- bounded static-kind sink
  }, settle_once)
  handle:cancel()
  handle:is_cancelled()
  ```

  The runner accepts each root event once in any order, translates acquisition
  failures into the shared accumulator, batches adapters for successful-root
  candidates, isolates optional cache hooks, waits for every batch, applies the
  total `finalize`, and invokes `settle_once(outcome)` once. A throwing
  acquisition becomes a total `producer_acquire_exception`; a throwing
  finalizer becomes a total `producer_finalize_exception`; and a throwing cache
  hook records `producer_cache_hook_exception` without suppressing the record or
  later hooks. Cancellation calls
  the acquisition and pending-batch cancellation handles once, suppresses later
  callbacks, and does not settle again. Acquisition/adapter/finalizer exceptions
  collapse to registered static kinds without stringifying thrown values.
- **`FinderLoadSession`** — binds a lazy producer factory to explicit
  subscriber handles and one ownership/retirement policy; it never drives
  parsing or batching.
  - **Injected into:** the five finder entry points; producer factory, logger,
  picker opener, `ownership = "picker" | "retained"`, `on_terminal`, and
  `on_retire` are dependencies. The producer owns scheduler/clock/batcher; the
  picker bridge only subscribes and materializes a terminal raw-metadata
  outcome.
  - **Future extensions:** other disk-backed pickers can opt in without changing `float_picker` semantics. Session settlement never clears the finder's `opened` flag; only actual picker close/select/cancel does.

  Exact API:

  ```lua
  local session = finder_loader.new_session({
      snapshot = opaque_snapshot,
      ownership = "picker" or "retained",
      producer_factory = function(settle_once) return cancel_producer end,
      on_terminal = function(outcome, had_subscribers) end,
      on_retire = function() end,
  })
  local subscription = session:subscribe(function(outcome) end)
  subscription:cancel() -- idempotent; never directly cancels retained producer
  session:start()       -- idempotent; only point that invokes producer_factory
  session:cancel_owner() -- idempotent explicit producer-owner cancellation
  session:fingerprint()
  session:snapshot_copy()
  session:is_settled()
  session:is_retired()
  session:subscriber_count()
  ```

  With `ownership = "picker"`, the last live subscription cancelling while
  loading invokes `cancel_producer` once and retires. With `"retained"`, zero
  subscribers never cancels loading work. Settlement freezes the current
  subscriber queue, delivers each callback once, admits/replays subscribers
  added during that delivery turn, calls `on_terminal(outcome,
  had_subscribers)`, then drops the stored outcome, calls `on_retire`, and
  refuses later subscriptions. Chat/Note set `on_retire` to clear their one
  in-flight prewarm registry; `on_terminal` logs bounded partial/failure only
  when `had_subscribers == false`. Their per-file caches were already updated by
  producer adapters before settlement and are not mutated from terminal hooks.
- **`PickerStatus`** — allows `float_picker.open({ status = ... })` with zero items, keeps status outside filtering/selection, and exposes `set_status`, `update`, `current_query`, and `close`.
  - **Injected into:** `FinderLoadSession`; timer creation is injectable in unit tests and uses `parley.progress.frame` at 120ms in production.
  - **Future extensions:** other nonselectable lifecycle statuses can reuse the same API.
- **`PickerStatusController`** — owns status/tick state and idempotent 120ms timer teardown, leaving `float_picker.lua` responsible only for rendering and input routing.
  - **Injected into:** `float_picker`; tests inject timer/schedule callbacks without opening Neovim windows.
  - **Future extensions:** elapsed-time or phase labels can widen the controller output without adding UI state to `float_picker`.
- **`FakeGitFileList`** — emits configurable NUL-separated chunks, stderr, and exit codes as a real child process.
  - **Injected into:** `GitMarkdownSource` integration tests through the executable path.
  - **Future extensions:** delayed output modes can exercise cancellation/backpressure.

The change deliberately uses existing `finder_facets`, `finder_sticky`, recency, delete/move, recall, and rendering policies as materializers after settlement. It does not create a generic “finder framework”; only lifecycle, file acquisition, batching, outcome, and path identity are shared (`ARCH-DRY`, `ARCH-PURE`, Simplicity First). New focused modules target 120–350 lines each; if one exceeds 400 lines during implementation, stop and split by pure policy versus IO/lifecycle before proceeding.

## Chunk 1: Shared lifecycle and Markdown vertical slice

### Task 1: Specify pure scan policy and batching

**Files:**
- Create: `lua/parley/finder_scan.lua`
- Create: `lua/parley/finder_batcher.lua`
- Create: `tests/unit/finder_scan_spec.lua`

- [x] **Step 1: Write failing snapshot/fingerprint tests**

  Cover immutable deep-copied ordered roots and every included/excluded
  fingerprint field. Mutate constructor input, an object returned by `copy()`,
  and the proxy itself; only proxy assignment errors and none changes the
  fingerprint or a later copy.

- [x] **Step 2: Run the focused test and confirm RED**

  Run: `nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/finder_scan_spec.lua" -c qa`
  Expected: FAIL because `parley.finder_scan` does not exist.

- [x] **Step 3: Implement `ScanSnapshot` and fingerprinting**

  Export the first two exact pure seams:

  ```lua
  M.snapshot(opts) -- -> immutable { kind, roots, recursion, max_depth, pattern, backend }
  M.fingerprint(snapshot) -- -> deterministic length-prefixed string
  ```

- [x] **Step 4: Run snapshot tests and confirm GREEN**

  Run the focused command from Step 2; expected snapshot/fingerprint examples PASS while later path tests are not yet present.

- [x] **Step 5: Write failing path identity/dedup/sort tests**

  Pass unresolved/resolved path strings directly. Cover `/` normalization,
  resolved-string preference and nil fallback, root ordinals, bytewise ties,
  overlapping roots, and arrival-order-independent canonical collision winners.

- [x] **Step 6: Run path tests and confirm RED**

  Run the focused command; expected FAIL because `path_identity` is nil.

- [x] **Step 7: Implement path identity, dedup, and stable sort**

  Export:

  ```lua
  M.path_identity({ unresolved_absolute, resolved_absolute, root_ordinal })
      -- -> { key, source = { root_ordinal, unresolved } }
  M.deduplicate(records) -- -> one record per identity.key, minimum source tuple
  M.sort(records, primary_less) -- primary comparator, then identity.key bytewise
  ```

  Normalize supplied strings lexically; never call IO, use locale collation, or
  depend on async arrival order.

- [x] **Step 8: Run path tests and confirm GREEN**

  Run the focused command; expected snapshot and path groups PASS.

- [x] **Step 9: Write failing outcome-algebra tests**

  Exercise all-absent success, partial roots/records, all attempted roots failed, and intentional skips.

- [x] **Step 9a: Run outcome tests and confirm RED**

  Run: `nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/finder_scan_spec.lua" -c qa`
  Expected: FAIL because `new_accumulator`/`outcome` are nil.

- [x] **Step 10: Implement outcome reducers**

  Export:

  ```lua
  M.new_accumulator(root_count)
  M.root_skipped(acc, ordinal)
  M.root_succeeded(acc, ordinal, records)
  M.root_failed(acc, ordinal, kind, diagnostic)
  M.record_failed(acc, kind, diagnostic)
  M.outcome(acc) -- success|partial|failure
  ```

- [x] **Step 11: Write failing diagnostic-policy tests**

  Cover the exact exported `FAILURE_KIND` table above, arbitrary thrown values,
  invalid adapter results, ten-diagnostic cap, control-character replacement,
  and 512-byte UTF-8-safe truncation.

- [x] **Step 11a: Run diagnostic tests and confirm RED**

  Run the exact focused command from Step 9a; expected FAIL because `sanitize_diagnostic` is nil and exception containment is absent.

- [x] **Step 12: Implement diagnostic policy**

  Export:

  ```lua
  M.sanitize_diagnostic(text, byte_cap)
  ```

- [x] **Step 13: Write failing batch-budget tests**

  With an injected clock/scheduler, prove exact yielding after 25 records or 5ms, resume without loss/duplication, and adapter `pcall` containment.

- [x] **Step 13a: Run batch tests and confirm RED**

  Run the exact focused command from Step 9a; expected FAIL because `new_batcher` is nil.

- [x] **Step 14: Implement `SliceBatcher`**

  Export:

  ```lua
  M.new_batcher({ item_budget = 25, time_budget_ms = 5, now = now, schedule = schedule })
  ```

  The batcher wraps adapter calls with `pcall`, accepts only
  `{ kind = "record", value = ... }`, `{ kind = "skip" }`, or
  `{ kind = "failure", failure_kind = M.FAILURE_KIND.<member> }`, rejects any
  unregistered string as `invalid_adapter_result`, and schedules before the next
  record after either budget is exhausted.

- [x] **Step 15: Run the complete pure spec and diff check**

  Run the focused test from Step 2 and `git diff --check`; expected all groups PASS and silent diff check.

- [x] **Step 16: Commit pure scan policy**

  ```bash
  git add lua/parley/finder_scan.lua lua/parley/finder_batcher.lua tests/unit/finder_scan_spec.lua
  git commit -m "finder: #189 add deterministic scan policy"
  ```

### Task 2: Add cancellable asynchronous filesystem acquisition

**Files:**
- Create: `lua/parley/async_file_source.lua`
- Create: `lua/parley/async_operation_queue.lua`
- Create: `lua/parley/async_file_enrichment.lua`
- Create: `tests/unit/async_file_source_spec.lua`
- Create: `tests/integration/async_file_source_spec.lua`

- [x] **Step 1: Write failing traversal tests against an injected uv fake**

  Specify the exact `scan(opts, on_root, on_complete)` event and cancellation
  schemas above for absent roots, transactional enumeration failure, symlink
  directories, and component depth. Root preflight `ENOENT` skips an optional
  root; other preflight errors, any required-directory `fs_scandir` open/drain
  error, or an unknown entry type needed for safe traversal fails the root and
  discards staged candidates.

- [x] **Step 2: Run unit tests and confirm RED**

  Run: `nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/async_file_source_spec.lua" -c qa`
  Expected: FAIL with `module 'parley.async_file_source' not found`.

- [x] **Step 3: Implement asynchronous traversal**

  Use async root preflight and `fs_scandir`; directory links are file candidates only and never traversal roots. Stage candidate paths/types until every directory in that root drains successfully. Only after this transactional enumeration boundary publish candidates into async per-record stat/read enrichment; candidate stat/open/read failures increment record failures and never roll back the root.

- [x] **Step 4: Run traversal tests and confirm GREEN**

  Run the unit command; expected traversal group PASS.

- [x] **Step 5: Write failing concurrency/cancellation tests**

  Assert at most 16 operations in flight, idempotent cancel, and no callbacks
  after cancellation. Exercise `read_policy` after stat: cache-hit `ready`
  performs zero opens/reads, changed-mtime `read` queues the requested header
  read, invalid/throwing policies become static record failures, cancellation
  between policy evaluation and queued read suppresses that read, and root
  completion waits for every conditional read.

- [x] **Step 5a: Run concurrency/cancellation tests and confirm RED**

  Run: `nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/async_file_source_spec.lua" -c qa`
  Expected: FAIL because traversal is uncapped and cancellation cleanup is incomplete.

- [x] **Step 6: Implement the shared operation queue and cancellation token**

  Route traversal stat work through the capped queue and close queued/active handles exactly once.

- [x] **Step 7: Write failing `read_paths` tests**

  Specify the exact `read_paths(opts, on_complete)` schema above with async
  stat/realpath/read, the identical per-path `read_policy` decisions, one
  completion payload, record failures, the shared concurrency cap, and the
  shared cancellation handle.

- [x] **Step 7a: Run `read_paths` tests and confirm RED**

  Run the exact unit command from Step 5a; expected FAIL because `read_paths` is nil.

- [x] **Step 8: Implement `read_paths` and descriptor cleanup**

  Use async `fs_open`, repeated `fs_read`, `fs_close`, and optional `fs_realpath`; close every descriptor exactly once.

- [x] **Step 9: Run all unit groups and confirm GREEN**

  Run the unit command; expected zero failures.

- [x] **Step 10: Write real-libuv integration coverage**

  Build temp roots with nested files, missing optional roots, a symlinked directory, and a denied/unreadable-or-injected-failing root. Verify a scheduled sentinel runs before completion and cancellation drains handles without a late terminal callback.

- [x] **Step 11: Run the integration spec and confirm GREEN**

  Run the integration command below; expected zero failures.

- [x] **Step 12: Run final checks**

  Run:

  ```bash
  nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/async_file_source_spec.lua" -c qa
  nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/async_file_source_spec.lua" -c qa
  git diff --check
  ```

  Expected: both specs report zero failures; diff check is silent.

- [x] **Step 13: Commit the async file source**

  ```bash
  git add lua/parley/async_file_source.lua lua/parley/async_operation_queue.lua lua/parley/async_file_enrichment.lua tests/unit/async_file_source_spec.lua tests/integration/async_file_source_spec.lua
  git commit -m "finder: #189 add asynchronous file source"
  ```

### Task 3: Teach the picker a nonselectable animated status

**Files:**
- Create: `lua/parley/picker_status.lua`
- Modify: `lua/parley/float_picker.lua`
- Create: `tests/unit/picker_status_spec.lua`
- Modify: `tests/unit/float_picker_spec.lua`

- [x] **Step 1: Write failing controller timer tests**

  Assert 120ms injected ticks use `progress.frame` and stop is idempotent.

- [x] **Step 2: Run controller tests and confirm RED**

  Run the `picker_status_spec.lua` command below; expected module-not-found.

- [x] **Step 3: Implement the focused status controller**

  Keep it under 120 lines and expose start/set/stop/current-render state.

- [x] **Step 4: Run controller tests and confirm GREEN**

  Run the controller command; expected zero failures.

- [x] **Step 5: Write failing float-picker status-render tests**

  Assert empty loading opens, status survives live query filtering, update clears it atomically, and error remains visible.

- [x] **Step 6: Write failing nonselection/teardown tests**

  Assert confirm, double-click, movement, and mappings cannot select status; Esc/window destruction stops once and calls cancel once.

- [x] **Step 7: Run float-picker tests and confirm RED**

  Run the `float_picker_spec.lua` command below; expected failure because empty status pickers warn and return.

- [x] **Step 8: Integrate the controller without synthetic items**

  Keep `status` separate from `items`/`filtered`; render it directly and suppress selection/highlighting/confirm while active. Return:

  ```lua
  {
      update = update,
      set_status = set_status,
      current_query = current_query_from_buffer,
      close = close_all,
      is_closed = function() return closed end,
  }
  ```

  Use `require("parley.progress").frame(tick)`; do not call the singleton `progress.start` bar.

- [x] **Step 9: Run picker/controller/progress specs and diff check**

  Run:

  ```bash
  nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/picker_status_spec.lua" -c qa
  nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/float_picker_spec.lua" -c qa
  nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/progress_spec.lua" -c qa
  git diff --check
  ```

  Expected: all three specs report zero failures; diff check is silent.

- [x] **Step 10: Commit picker status**

  ```bash
  git add lua/parley/picker_status.lua lua/parley/float_picker.lua tests/unit/picker_status_spec.lua tests/unit/float_picker_spec.lua
  git commit -m "picker: #189 add animated lifecycle status"
  ```

### Task 4: Add shared producer orchestration and the exactly-once loader session

**Files:**
- Create: `lua/parley/finder_producer.lua`
- Create: `tests/unit/finder_producer_spec.lua`
- Create: `lua/parley/finder_loader.lua`
- Create: `tests/unit/finder_loader_spec.lua`

- [x] **Step 1: Write failing producer orchestration tests**

  Drive root events in different orders and cover skipped, failed, and
  successful roots; per-record failures; sliced adapters; deterministic
  finalization; optional record/root cache hooks; exactly-once settlement; and
  composite cancellation. Assert the runner waits for all scheduled batches
  before finalizing and never emits after cancellation.

- [x] **Step 2: Run the producer test and confirm RED**

  Run: `nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/finder_producer_spec.lua" -c qa`
  Expected: FAIL with `module 'parley.finder_producer' not found`.

- [x] **Step 3: Implement `finder_producer.run`**

  Implement the exact injected API above as the sole owner of acquisition event
  reduction, batch scheduling, outcome accumulation, cache hooks, finalization,
  cancellation, and settlement.

- [x] **Step 4: Write failing producer exception-isolation tests**

  Make acquisition, adapter, finalizer, `on_record`, and `on_root_success` throw
  arbitrary tables/userdata. Assert only registered static kinds reach the
  diagnostic/outcome boundaries, later hooks and records continue where the
  contract permits, and settlement/cancellation remain exactly once.

- [x] **Step 5: Implement producer exception containment and confirm GREEN**

  Add independent `pcall` boundaries and run the focused producer command;
  expected zero failures.

- [x] **Step 6: Write failing session settlement tests**

  Use a lazy producer factory fake that emits already-adapted raw finder metadata
  plus final counts. Cover the exact API/ownership table above: subscription
  cancel idempotence; picker last-subscriber producer cancellation; retained
  zero-subscriber continuation; delivery-turn replay; repeated settlement;
  explicit owner cancellation; ownerless `on_terminal`; `on_retire`; refusal
  after retirement; and defensive snapshot access. Assert the session has no
  adapter or batcher dependency.

- [x] **Step 7: Write failing lifecycle exception-isolation tests**

  Cover a throwing producer factory after the picker shell has opened; one
  throwing subscriber not blocking later subscribers; one throwing materializer
  affecting only that picker binding; a throwing `on_terminal` not blocking
  `on_retire`; a throwing `on_retire` still leaving the session retired; and
  arbitrary thrown values never being stringified. Assert diagnostics use only
  registered lifecycle failure kinds.

- [x] **Step 8: Run the focused loader test and confirm RED**

  Run: `nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/finder_loader_spec.lua" -c qa`
  Expected: FAIL with `module 'parley.finder_loader' not found`.

- [x] **Step 9: Implement `new_session`**

  Store the producer factory without invoking it. Implement the exact public
  methods and subscription handle above. Accept only a terminal callback carrying
  a complete `ScanOutcome` of already-adapted raw finder metadata; do not parse
  or mutate counts. Protect producer factory, each subscriber, terminal hook,
  and retire hook independently. Factory exceptions settle a bounded total
  failure; hook exceptions cannot prevent retirement, and retirement state is
  committed before invoking `on_retire`.

- [x] **Step 10: Run session tests and confirm GREEN**

  Run the focused loader command; expected settlement and exception groups PASS.

- [x] **Step 11: Write failing picker-bridge lifecycle tests**

  Cover synchronous loading, live query at total post-settlement materialization,
  partial warning, total error, successful empty, and settlement keeping
  `opened` true until actual picker close/select/cancel. Make the materializer
  deliberately total and assert `open_picker` never invokes an adapter/batcher.
  Assert the producer factory has not been invoked when the picker opener
  returns. Make one materializer throw and assert only its picker binding gets a
  bounded error while other subscribers still install their results.

- [x] **Step 12: Run picker-bridge tests and confirm RED**

  Run the focused loader command; expected failure because `open_picker` is nil.

- [x] **Step 13: Implement `open_picker`**

  Open status first and return a `{ picker, subscription }` binding after
  subscribing the generation; do not call `session:start()`. The finder entry
  point calls `session:start()` only after `open_picker` returns, proving the
  shell exists before the producer factory can start IO. On settlement apply
  only total deterministic recency/facet/render materialization and read
  `picker.current_query()` only at installation. All adapter batching belongs to
  the producer before it calls session settlement. Contain materializer throws
  per binding as `materializer_exception`.

- [x] **Step 14: Run shared regression checks**

  Run:

  ```bash
  nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/finder_scan_spec.lua" -c qa
  nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/finder_producer_spec.lua" -c qa
  nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/finder_loader_spec.lua" -c qa
  nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/float_picker_spec.lua" -c qa
  git diff --check
  ```

  Expected: all specs report zero failures; diff check is silent.

- [x] **Step 15: Commit producer and loader**

  ```bash
  git add lua/parley/finder_producer.lua tests/unit/finder_producer_spec.lua lua/parley/finder_loader.lua tests/unit/finder_loader_spec.lua
  git commit -m "finder: #189 add shared producer sessions"
  ```

### Task 5: Implement streaming Git-aware Markdown discovery

**Files:**
- Create: `lua/parley/git_markdown_source.lua`
- Create: `tests/fixtures/fake_git_file_list`
- Create: `tests/integration/git_markdown_source_spec.lua`
- Modify: `lua/parley/markdown_finder.lua`
- Modify: `tests/unit/markdown_finder_spec.lua`

- [x] **Step 1: Write the executable process fixture**

  Support delayed/chunked NUL stdout, stderr, newline paths, overlong fragments, and exit codes; tests will chmod it via uv.

- [x] **Step 2: Write failing process framing/cancellation tests**

  Launch the fixture through the exact `git_markdown_source.list(opts,
  on_complete)` contract and cover incremental NUL records, 4096 stderr cap,
  16384 pending-fragment failure, non-zero staged-output discard, exactly-once
  completion, and idempotent callback-suppressing cancellation.

- [x] **Step 3: Run process tests and confirm RED**

  Run the integration command below; expected module-not-found.

- [x] **Step 4: Implement process framing and staging**

  Incrementally split stdout, bound buffers, stage raw relative byte strings until exit 0, and return idempotent cancellation. Do not validate paths here and do not use `tasker.run`.

- [x] **Step 5: Run process framing tests and confirm GREEN**

  Run the integration command; expected fixture cases PASS.

- [x] **Step 6: Add hermetic real-Git protocol tests**

  Spawn `git -C ROOT ls-files -z --cached --others --exclude-standard -- '*.md'`. Real-repository tests set a temp `HOME`, `XDG_CONFIG_HOME`, `GIT_CONFIG_GLOBAL`, and `GIT_CONFIG_NOSYSTEM=1`, write an isolated global excludes file, and clean all temp state. Cover tracked-but-currently-ignored files, untracked global excludes, `.git` exclusion, nested repositories/submodules as opaque entries, newline filenames, and non-repo/missing-Git/non-zero root failures. Treat output as the set union Git provides and deduplicate defensively.

- [x] **Step 6a: Run real-Git protocol tests and confirm RED**

  Run: `nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/git_markdown_source_spec.lua" -c qa`
  Expected: FAIL because exact Git argv/root-outcome mapping and defensive dedup are not implemented.

- [x] **Step 7: Implement exact Git invocation/root outcomes**

  Add the exact argv, missing/non-repo/non-zero failure mapping, and defensive byte-string dedup; leave all path validation to `MarkdownPathPolicy`.

- [x] **Step 8: Run all Git-source tests and confirm GREEN**

  Run the integration command; expected zero failures.

- [x] **Step 9: Write failing pure Markdown path/materializer tests**

  Specify `M.path_candidate(root, relative, max_depth)` and `M.materialize_records(opts)` as the sole owners of absolute/escaping/non-Markdown rejection, component depth, facet identity, and mtime/path sorting.

- [x] **Step 10: Run pure Markdown tests and confirm RED**

  Run the `markdown_finder_spec.lua` command below; expected failures for missing pure seams.

- [x] **Step 11: Implement pure Markdown path/materializer policy**

  Keep it free of process/filesystem calls and consume only staged raw paths plus enriched stat/identity records.

- [x] **Step 12: Run pure Markdown tests and confirm GREEN**

  Run the unit command; expected pure policy groups PASS.

- [x] **Step 13: Write failing Markdown entry-point lifecycle tests**

  Replace synchronous `_scan_members` cases with delayed injected sources; cover sentinel/spinner, live query, empty/all-absent, stat failure, partial/total roots, and Esc/late completion/reopen.

- [x] **Step 14: Run entry-point tests and confirm RED**

  Run the unit command; expected failures because `open()` still scans synchronously.

- [x] **Step 15: Migrate `markdown_finder.open`**

  Snapshot ordinary or ordered super-repo member roots; open the picker before
  starting Git; treat Git exit 0 as that root's enumeration success; pass
  accepted Git paths to `AsyncFileSource.read_paths` for bounded asynchronous
  stats; count stat failures as record failures; inject that acquisition stream,
  the pure path/entry adapter, and finalizer into `finder_producer.run`; do not
  reimplement batching, accumulation, cancellation, or settlement. Subscribers
  apply existing `build_picker_data` and facet callbacks only after settlement.
  Cancelling the session cancels Git, path enrichment, and pending batches.
  Preserve repository facets in super-repo mode and directory facets in
  ordinary mode.

- [x] **Step 16: Run Markdown/shared tests and diff check**

  Run:

  ```bash
  nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/git_markdown_source_spec.lua" -c qa
  nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/markdown_finder_spec.lua" -c qa
  nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/finder_loader_spec.lua" -c qa
  nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/float_picker_spec.lua" -c qa
  git diff --check
  ```

  Expected: all specs report zero failures; diff check is silent.

- [x] **Step 17: Commit Markdown discovery**

  ```bash
  git add lua/parley/git_markdown_source.lua lua/parley/markdown_finder.lua tests/fixtures/fake_git_file_list tests/integration/git_markdown_source_spec.lua tests/unit/markdown_finder_spec.lua
  git commit -m "markdown: #189 stream Git-aware discovery"
  ```

- [x] **Step 18: Prepare and invoke the M1 boundary**

  Update `atlas/ui/pickers.md`, `atlas/infra/repo_mode.md`,
  `atlas/traceability.yaml`, and `atlas/index.md` if a new atlas page is
  introduced. Do not tick M1 or append its close log by hand; the gate owns
  those mutations. Run `make test-changed`, `make lint`, and `git diff --check`,
  then invoke:

  ```bash
  sdlc milestone-close --issue 189 --milestone M1 --agent codex --verified 'finder_scan, async_file_source unit/integration, picker_status, float_picker, finder_loader, git_markdown_source integration, and markdown_finder specs pass; make test-changed and make lint pass; git diff --check is clean.'
  ```

  Fix Critical/Important findings before committing, then commit the gate-owned
  issue/atlas mutations and fixes once, copying the emitted `Review-Verdict:`
  and `Review-Window:` lines verbatim into the commit trailers.

  After the M1 commit, run `sdlc actual --issue 189`. If cumulative actual is
  outside 5.6–10.4 hours, revise frontmatter and append an issue/plan Revision
  before starting M2; do not silently preserve or back-fit the original
  estimate.



### Task 6: Move Chat discovery and cache materialization behind the loader

**Files:**
- Create: `lua/parley/chat_finder_records.lua`
- Modify: `lua/parley/chat_finder.lua`
- Create: `tests/unit/chat_finder_records_spec.lua`
- Modify: `tests/unit/chat_finder_logic_spec.lua`
- Modify: `tests/perf_chat_finder.lua`

- [ ] **Step 1: Write failing pure materializer tests**

  Specify the input union explicitly:

  ```lua
  { kind = "cached", path, identity, stat, root, metadata }
  { kind = "lines", path, identity, stat, root, first_lines }
  ```

  Preserve #189's current timestamp semantics without resolving open issue #122:
  the legacy dashed filename fast-path still parses, real dotted chat filenames
  continue falling back to stat mtime, and content-derived activity ordering is
  out of scope. Also cover recency filtering, shared static parse failures,
  tags/topic parsing, deterministic timestamp/path ordering, and
  overlapping-root/symlink dedup. Cache lookup occurs in
  `AsyncFileSource.read_policy` after async stat and before async read:
  unchanged canonical path+mtime returns `ready(cached)` and causes zero
  opens/reads; only a miss/change returns `read({ head_lines = 10 })` and
  produces `lines`.

- [ ] **Step 2: Run Chat logic tests and confirm RED**

  Run: `nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/chat_finder_records_spec.lua" -c qa`
  Expected: FAIL with `module 'parley.chat_finder_records' not found`.

- [ ] **Step 3: Extract raw adapter and materializer**

  Keep `chat_finder_records.lua` under about 300 lines and free of Neovim IO.
  The entry point injects a synchronous, non-mutating cache lookup as
  `AsyncFileSource.read_policy`; it returns `ready` for canonical path+mtime
  hits and requests ten lines only on miss/change. The adapter consumes the
  resulting `precomputed` or `payload` union and mutates the cache only through
  the producer's post-adaptation `on_record` hook. Return complete raw metadata
  independent of recency/query/facets; apply opener recency and tag/root facets
  after settlement. Keep the benchmark pointed at the pure materializer with
  prebuilt records so it measures parsing rather than disk scheduling.

- [ ] **Step 4: Write failing entry-point and prewarm join tests**

  In `chat_finder_logic_spec.lua`, assert immediate picker return, a delayed producer permitting a scheduled sentinel and spinner tick, live sticky query, cancel/reopen, no post-cancel update, successful empty, all-absent optional roots, partial enumeration, total enumeration failure, and stat/read record failure. For fingerprint construction, vary finder kind; ordered normalized root path/label/primary; recursion/depth; filename pattern; and backend options one at a time and require a new producer, while recency/facets/query differences still join. Assert one producer for multiple matching subscribers and distinct recency materialization for two joined openers.

- [ ] **Step 5: Run entry-point tests and confirm RED**

  Run: `nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/chat_finder_logic_spec.lua" -c qa`
  Expected: FAIL at the immediate-open/prewarm assertions because current code waits for prewarm and scans synchronously.

- [ ] **Step 6: Implement joinable Chat prewarm**

  Replace `_prewarm_pending/_prewarm_callbacks` with one retained in-flight
  `FinderLoadSession`. Its producer factory calls `finder_producer.run` with the
  Chat acquisition/adapter/finalizer/cache hooks; it owns no local outcome,
  batching, or cancellation state. `prewarm()` uses `ownership = "retained"`; a matching
  `open()` uses the shared subscription handle without taking producer
  ownership. On ownerless settlement discard the outcome, retain only per-file
  mtime metadata, log bounded partial/failure through `on_terminal`, and clear
  `_prewarm_session` through `on_retire`. Prune cache entries only for
  successfully enumerated roots; retain failed-root entries until that root
  later enumerates successfully. Do not add finder-local subscriber arrays.

- [ ] **Step 7: Run Chat/shared tests and commit**

  Run:

  ```bash
  nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/chat_finder_records_spec.lua" -c qa
  nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/chat_finder_logic_spec.lua" -c qa
  nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/finder_scan_spec.lua" -c qa
  nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/finder_loader_spec.lua" -c qa
  git diff --check
  ```

  Expected: all four specs report zero failures; diff check is silent.

  ```bash
  git add lua/parley/chat_finder_records.lua lua/parley/chat_finder.lua tests/unit/chat_finder_records_spec.lua tests/unit/chat_finder_logic_spec.lua tests/perf_chat_finder.lua
  git commit -m "chat: #189 load finder records asynchronously"
  ```

### Task 7: Move Note discovery and prewarm behind the same contracts

**Files:**
- Create: `lua/parley/note_finder_records.lua`
- Modify: `lua/parley/note_finder.lua`
- Create: `tests/unit/note_finder_records_spec.lua`
- Modify: `tests/unit/note_finder_logic_spec.lua`

- [ ] **Step 1: Write failing Note adapter/materializer tests**

  Feed enumerated path/stat/root records. Cover recursive traversal, template skips (not failures), directory-date inference, special-folder recency exemption, cache reuse/pruning, non-primary labels, timestamp/mtime/path ordering, and adapter exceptions.

- [ ] **Step 2: Run record tests and confirm RED**

  Run: `nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/note_finder_records_spec.lua" -c qa`
  Expected: FAIL with `module 'parley.note_finder_records' not found`.

- [ ] **Step 3: Extract Note IO from materialization**

  Keep `note_finder_records.lua` under about 260 lines and keep classification/cutoff inference pure over record metadata. Use `AsyncFileSource` recursively for `*.md`; no file body read is needed. Apply recency only per opener after the raw prewarm result settles. Prune only roots that enumerated successfully; retain and retry cache entries for failed roots.

- [ ] **Step 4: Write failing Note lifecycle/prewarm tests**

  Mirror Chat's delayed-producer immediate return/sentinel/spinner, cancel, fingerprint-field join/mismatch, ownerless-settlement, distinct-recency, successful-empty/all-absent, stat failure, partial/total failure retry, successful-root-only cache pruning, and no-duplicate-scan cases. Preserve delete and recency-cycle reopen behavior after settlement.

- [ ] **Step 5: Run entry-point tests and confirm RED**

  Run: `nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/note_finder_logic_spec.lua" -c qa`
  Expected: FAIL at immediate-open/prewarm assertions because current code waits and scans synchronously.

- [ ] **Step 6: Implement Note loader and joinable prewarm wiring**

  Construct the exact discovery fingerprint in production and call
  `finder_producer.run` with Note acquisition/adapter/finalizer/cache hooks;
  keep no finder-local outcome, batching, or cancellation machinery. Subscribe matching
  opens through the shared subscription handle, preserve retained prewarm
  ownership on picker cancel, and route settled raw records through the total
  materializer and existing UI actions. Use shared `on_terminal`/`on_retire`
  hooks and do not add finder-local callback arrays.

- [ ] **Step 7: Run Note/shared tests and commit**

  Run:

  ```bash
  nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/note_finder_records_spec.lua" -c qa
  nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/note_finder_logic_spec.lua" -c qa
  nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/finder_loader_spec.lua" -c qa
  nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/float_picker_spec.lua" -c qa
  git diff --check
  ```

  Expected: all four specs report zero failures; diff check is silent.

  ```bash
  git add lua/parley/note_finder_records.lua lua/parley/note_finder.lua tests/unit/note_finder_records_spec.lua tests/unit/note_finder_logic_spec.lua
  git commit -m "note: #189 share asynchronous finder prewarm"
  ```

- [ ] **Step 5: Prepare and invoke the M2 boundary**

  Update atlas picker/note descriptions. Do not tick M2 or append its close log
  by hand; the gate owns those mutations. Run `make test-changed`, `make lint`,
  and `git diff --check`, then invoke:

  ```bash
  sdlc milestone-close --issue 189 --milestone M2 --agent codex --verified 'Chat and Note record/entry-point specs cover delayed immediate-open, exact prewarm join, cancellation, partial/total outcomes, and successful-root cache pruning; shared specs, make test-changed, and make lint pass; git diff --check is clean.'
  ```

  Fix Critical/Important findings before committing, then commit the gate-owned
  issue/atlas mutations and fixes once with the emitted review trailers.

  After the M2 commit, run `sdlc actual --issue 189`. If cumulative actual is
  outside 8.75–16.25 hours, revise the remaining estimate with an appended
  Revision before the final slice.

## Chunk 3: Issue/Vision migration and release verification

### Task 8: Make issue-file parsing reusable and migrate Issue Finder

**Files:**
- Create: `lua/parley/issue_finder_records.lua`
- Modify: `lua/parley/issue_finder.lua`
- Create: `tests/unit/issue_finder_records_spec.lua`
- Modify: `tests/unit/issue_finder_spec.lua`

- [ ] **Step 1: Write failing pure issue-record tests**

  Specify `issue_finder_records.adapt({ path, name, mtime, lines, archived, repo_name, identity })`. Cover valid IDs, shared `issues.parse_frontmatter`/`extract_title` interpretation, intentional filename nonmatch skip, malformed-but-displayable payload, static adapter exception containment at the batcher, no mutation, and deterministic materialization/sorting. Reading, canonicalization, and mutable cache behavior are excluded from this pure module.

- [ ] **Step 2: Run record tests and confirm RED**

  Run: `nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/issue_finder_records_spec.lua" -c qa`
  Expected: FAIL with `module 'parley.issue_finder_records' not found`.

- [ ] **Step 3: Implement the pure issue record module**

  Keep the new module under about 220 lines, call existing exported pure issue parsers, and return only `record`/`skip`/static `failure(kind)` values. Leave synchronous `issues.scan_issues` unchanged.

- [ ] **Step 4: Write failing Issue Finder lifecycle tests**

  Use a delayed injected producer and assert `open()` returns while `scanning…` is visible, then a scheduled sentinel and spinner tick run before settlement. Cover issue/history views, successful empty/all-absent optional directories, super-repo partial and total enumeration failure, stat/read record failure counts, intentional skip count zero, deterministic status/ID/mtime/path ties, repository facets after settlement, live verbatim query, Esc/reopen with ignored late completion, and existing delete/status/view-cycle mappings after load.

- [ ] **Step 5: Run entry-point tests and confirm RED**

  Run: `nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/issue_finder_spec.lua" -c qa`
  Expected: FAIL at immediate-loading/delayed-producer assertions because current `open()` scans synchronously.

- [ ] **Step 6: Migrate `issue_finder.open`**

  Snapshot issue/history roots for the chosen view, enumerate non-recursive
  `*.md`, asynchronously stat/read full payloads, and batch the pure adapter into
  raw issue metadata through `finder_producer.run`; do not duplicate root
  transactions, batching, accumulation, cancellation, or settlement. After settlement, apply only total
  view/facet/render materialization and preserve all current actions. Keep
  canonical path+mtime cache ownership in the producer integration layer.

- [ ] **Step 7: Run focused tests and commit**

  ```bash
  nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/issue_finder_records_spec.lua" -c qa
  nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/issue_finder_spec.lua" -c qa
  nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/finder_loader_spec.lua" -c qa
  git diff --check
  ```

  Expected: all three specs report zero failures; diff check is silent.

  ```bash
  git add lua/parley/issue_finder_records.lua lua/parley/issue_finder.lua tests/unit/issue_finder_records_spec.lua tests/unit/issue_finder_spec.lua
  git commit -m "issue: #189 load finder records asynchronously"
  ```

### Task 9: Migrate Vision Finder over reusable YAML materialization

**Files:**
- Create: `lua/parley/vision_finder_records.lua`
- Modify: `lua/parley/vision_finder.lua`
- Create: `tests/unit/vision_finder_records_spec.lua`
- Create: `tests/unit/vision_finder_spec.lua`

- [ ] **Step 1: Write failing vision-file materializer tests**

  Specify `vision_finder_records.adapt({ path, name, lines, repo_name, identity })`
  returning one `{ identity, source, initiatives = {...} }` file bundle. Assert
  reuse of `vision.parse_vision_yaml`, namespace/file/line/repo metadata,
  intentional non-YAML skip, project-only picker rendering, deterministic
  initiative keys from length-prefixed file identity plus parser ordinal,
  malformed adapter failure containment, and no mutation. Prove two or more
  initiatives from one file survive file-bundle deduplication and flatten in
  parser order before the existing primary sort. Keep IO and cache ownership
  outside the pure module.

- [ ] **Step 2: Run record tests and confirm RED**

  Run: `nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/vision_finder_records_spec.lua" -c qa`
  Expected: FAIL with `module 'parley.vision_finder_records' not found`.

- [ ] **Step 3: Implement the pure Vision record module**

  Keep it under about 180 lines and reuse
  `vision.parse_vision_yaml`/`parse_priority`; leave synchronous
  `vision.load_vision_dir` unchanged. `adapt` returns one file bundle;
  `materialize_records` first applies shared file-identity deduplication, then
  flattens initiatives with stable source identity/ordinal keys and applies the
  existing initiative ordering.

- [ ] **Step 4: Write failing Vision Finder lifecycle tests**

  In the dedicated `vision_finder_spec.lua`, use a delayed producer and assert `open()` returns with `scanning…`, then a scheduled sentinel and spinner tick run. Cover successful empty/all-absent roots, root aggregation, partial/total enumeration failure, read/parser record failures versus intentional skips, query changes during load, cancellation/reopen with ignored late completion, stable path ordering, and selection line jump after settlement.

- [ ] **Step 5: Run entry-point tests and confirm RED**

  Run: `nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/vision_finder_spec.lua" -c qa`
  Expected: FAIL at module/entry-point lifecycle assertions because current finder scans before opening.

- [ ] **Step 6: Migrate Vision Finder**

  Enumerate non-recursive `*.yaml`, async-read each payload, and batch the pure
  adapter into raw initiative metadata through `finder_producer.run`; do not
  duplicate root transactions, batching, accumulation, cancellation, or
  settlement. After settlement, apply
  only total project filtering/render materialization through the shared loader,
  without changing the synchronous Vision domain API.

- [ ] **Step 7: Run focused tests and commit**

  ```bash
  nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/vision_finder_records_spec.lua" -c qa
  nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/vision_finder_spec.lua" -c qa
  nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/vision_spec.lua" -c qa
  nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/finder_loader_spec.lua" -c qa
  git diff --check
  ```

  Expected: all four specs report zero failures; diff check is silent.

  ```bash
  git add lua/parley/vision_finder_records.lua lua/parley/vision_finder.lua tests/unit/vision_finder_records_spec.lua tests/unit/vision_finder_spec.lua
  git commit -m "vision: #189 load finder records asynchronously"
  ```

### Task 10: Reconcile docs, traceability, and complete verification

**Files:**
- Modify: `README.md`
- Modify: `atlas/ui/pickers.md`
- Modify: `atlas/infra/repo_mode.md`
- Modify: `atlas/notes/finder.md`
- Modify: `atlas/traceability.yaml`
- Modify: `atlas/index.md` only if a new atlas page is added
- Modify: `workshop/issues/000189-all-finders-should-have-a-spinner-in-case-of-large-input.md`

- [ ] **Step 1: Update operator-facing documentation**

  Document the five-finder disk-backed scope, immediate cancellable `scanning…`, complete-result replacement, partial/total failure presentation, and Markdown's tracked-union-untracked-nonignored Git boundary in ordinary and super-repo modes.

- [ ] **Step 2: Update atlas and traceability**

  Map `finder_scan`, `finder_batcher`, `async_file_source`, `git_markdown_source`,
  `finder_producer`, `finder_loader`, `picker_status`, all four focused
  finder-record modules, production finders, process fixture, and all new
  unit/integration specs. Record the 25-record/5ms, 16-in-flight, 512-byte
  diagnostic, 4096-byte stderr, 16384-byte pending-path, ten-diagnostic, and
  120ms spinner budgets as implementation constants rather than product
  promises.

- [ ] **Step 3: Run focused and mapped verification**

  Run:

  ```bash
  nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedDirectory tests/unit" -c qa
  nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/async_file_source_spec.lua" -c qa
  nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/git_markdown_source_spec.lua" -c qa
  make test-changed
  make lint
  git diff --check
  ```

  Expected: unit directory and both integration specs report zero failures, mapped tests pass, lint reports no warnings/errors, and diff check is silent.

- [ ] **Step 4: Run the full suite**

  Run: `make test`
  Expected: all unit and integration tests PASS with no leaked timers/handles at process exit.

- [ ] **Step 5: Perform manual smoke test**

  In `~/workspace/parley.nvim`, use the real repository/super-repo roots for all five finders. Build a reproducible large Markdown root:

  ```bash
  tmp=$(mktemp -d /tmp/parley-189-smoke.XXXXXX)
  git -C "$tmp" init
  mkdir -p "$tmp/docs" "$tmp/vendor"
  touch "$tmp/.parley"
  printf 'vendor/\n' > "$tmp/.gitignore"
  for i in $(seq -w 1 2000); do printf '# doc %s\n' "$i" > "$tmp/docs/$i.md"; done
  for i in $(seq -w 1 2000); do printf '# ignored %s\n' "$i" > "$tmp/vendor/$i.md"; done
  git -C "$tmp" add .parley .gitignore docs
  printf '%s\n' "$tmp"
  ```

  Launch Neovim with that printed directory as cwd and Parley's local plugin path. Confirm the shell/spinner appears immediately, typing remains live, Esc cancels, reopen succeeds, only tracked docs appear, and post-load mappings/facets work. Remove only the printed `/tmp/parley-189-smoke.*` fixture after recording the exact path and observations in the issue Log.

- [ ] **Step 6: Commit docs and verification log**

  ```bash
  git add README.md atlas workshop/issues/000189-all-finders-should-have-a-spinner-in-case-of-large-input.md
  git commit -m "docs: #189 map asynchronous finder discovery"
  ```

- [ ] **Step 7: Prepare and invoke the final close boundary**

  Before invoking the gate, tick this step and every other remaining durable
  plan checkbox plus the final plain issue-plan row; do not change issue status
  or append the close log by hand. Let the binary run the mandatory
  fresh-context boundary review; fix Critical/Important findings, add prevention
  rules to `workshop/lessons.md`, and rerun affected verification. Then use
  measured actuals:

  ```bash
  sdlc actual --issue 189
  sdlc close --issue 189 --agent codex --verified 'M1 and M2 boundary verdicts accepted; all new focused specs, make test-changed, make lint, and make test pass; git diff --check is clean; manual five-finder and 2,000 tracked/2,000 ignored Markdown smoke checks pass.'
  ```

  Fix any boundary findings before committing. Commit close-owned issue changes,
  fixes, lessons, and emitted review trailers in one final close commit.

## Revisions

### 2026-07-15 — mandatory change-code gate

- Reason: the first gate invocation returned `VERDICT: FAILURE` for invalid
  boundary commands/bookkeeping, a close-checkbox paradox, underestimated
  scope, undefined failure-kind ownership, and ambiguity with issue #122.
- Delta: use `milestone-close`, sequence gate-owned mutations before one trailer
  commit, make the final step tickable before close, expand the estimate to 9.2
  hours in the issue, define `finder_scan.FAILURE_KIND`, and preserve rather
  than redesign Chat timestamp behavior.

### 2026-07-15 — second mandatory change-code gate

- Reason: the second judge found that the picker bridge appeared to perform
  failure-producing adapter work after terminal settlement, the filesystem root
  transaction boundary was ambiguous, and the estimate still collapsed too
  many independent feature surfaces.
- Delta: made enumeration/enrichment/batched adaptation producer-owned before
  one settlement, made directory traversal or Git exit the root transaction
  boundary with later stat/read/parse failures per-record, and expanded the
  issue estimate to six Lua primitives plus two IO integrations and two
  migrations.

### 2026-07-15 — third mandatory change-code gate

- Reason: the third judge found the session interface could not yet express
  subscriber cancellation, producer ownership/start ordering, ownerless prewarm
  hooks/retirement, or enforceable snapshot immutability.
- Delta: specified an opaque snapshot proxy, lazy `producer_factory`, exact
  session/subscription methods, picker versus retained ownership, deterministic
  delivery-turn retirement hooks, picker-before-`start()` ordering, and an M1
  estimate calibration checkpoint.

### 2026-07-15 — fourth mandatory change-code gate

- Reason: the fourth judge found acquisition callback/cancellation schemas
  implicit, filesystem realpath inside the pure identity API, and no numeric
  estimate variance trigger by delivery slice.
- Delta: specified exact `scan`, `read_paths`, and Git `list` inputs, result
  events, sequencing, and cancellation handles; moved async realpath to the IO
  source; made identity string-pure; and allocated 8.0/4.5/4.1 hours with 30%
  cumulative revision thresholds after M1 and M2.

### 2026-07-15 — fifth mandatory change-code gate

- Reason: the fifth judge found five finder tasks could independently duplicate
  acquisition-to-settlement orchestration and that callback exceptions could
  interrupt later delivery or retirement.
- Delta: introduced one injected `finder_producer.run` contract and TDD task for
  root transactions, batching, outcome accumulation, cache hooks, cancellation,
  finalization, and exactly-once settlement; required every finder to use it;
  and specified independent static/bounded containment for producer,
  subscriber/materializer, terminal, and retirement callback exceptions.

### 2026-07-15 — sixth mandatory change-code gate

- Reason: the sixth judge found Chat's stat-to-cache-to-conditional-read
  pipeline was not expressible through a scan-wide read mode and Vision's
  one-file-to-many initiatives conflicted with the one-record adapter algebra.
- Delta: added an injected post-stat `read_policy` with ready/read/none results,
  zero-read cache hits, per-record failures, cancellation checks, and settlement
  tests; defined Vision's adapter result as one file bundle that is deduplicated
  before initiatives are flattened with stable source identity/ordinal keys.

### 2026-07-15 — Task 1 size-guard revision

- Reason: the first green implementation of `finder_scan.lua` reached 460
  lines, crossing the plan's mandatory 400-line split threshold.
- Delta: extracted the independently pure scheduling state machine to
  `finder_batcher.lua` while retaining `finder_scan.new_batcher` as the single
  public failure-vocabulary-aware seam and the existing focused test oracle.

### 2026-07-15 — Task 2 IO-boundary split

- Reason: sharing conditional enrichment between traversal and `read_paths`
  would have pushed the filesystem source past the plan's size guard and risked
  two subtly different concurrency/cancellation implementations.
- Delta: kept traversal/root transactions in `async_file_source.lua`, extracted
  the 16-operation queue to `async_operation_queue.lua`, and single-sourced
  stat/realpath/read-policy/open/read/close behavior in
  `async_file_enrichment.lua` for both public acquisition APIs (`ARCH-DRY`,
  `ARCH-PURE`).

### 2026-07-15 — Task 5 obsolete-seam cleanup

- Reason: migrating `markdown_finder.open` removed `_scan_members`, whose
  integration test in `tests/unit/super_repo_spec.lua` directly exercised the
  old synchronous glob implementation.
- Delta: removed that obsolete test and cover the same super-repo aggregation,
  repository prefixes, and facet identity through the injected production
  entry point plus `materialize_records`; Task 5 therefore also modifies
  `tests/unit/super_repo_spec.lua` (`ARCH-DRY`, `ARCH-PURE`).

### 2026-07-16 — M1 boundary-review rework

- Reason: the first M1 boundary review found two runtime correctness gaps
  (malformed record payloads and directory-valued symlink targets), duplicated
  total-failure policy, incomplete aggregate status text, missing real-submodule
  and production-spinner coverage, absent README guidance, and plan claims that
  described cancellation as a settlement and the scheduled batcher as PURE.
- Delta: validate adapter record payloads at `FinderProducer`, require enriched
  stat targets to be files, route all aggregate failures through
  `finder_scan.total_failure`, report finder/root/file totals, add real Git
  submodule and real float-picker delayed-scan coverage, document Markdown's
  loading/Git boundary, classify `SliceBatcher` as INTEGRATION, and define
  cancellation as non-settling retirement. `FinderLoadSession` now schedules
  terminal delivery through its injected main-loop scheduler so libuv callbacks
  cannot touch Neovim UI APIs in a fast-event context (`ARCH-DRY`, `ARCH-PURE`,
  `ARCH-PURPOSE`).
