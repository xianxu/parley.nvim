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

**Tech Stack:** Lua, Neovim `vim.uv`/`vim.loop`, `uv.spawn`, plenary/busted tests, Git `ls-files` NUL streams.

---

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `ScanSnapshot` | `lua/parley/finder_scan.lua` | new |
| `ScanOutcome` | `lua/parley/finder_scan.lua` | new |
| `PathIdentity` | `lua/parley/finder_scan.lua` | new |
| `SliceBatcher` | `lua/parley/finder_scan.lua` | new |
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
- **`ScanOutcome`** — the closed `success`/`partial`/`failure`/`cancelled` terminal algebra plus aggregate root/record failure counts.
  - **Relationships:** one session settles to at most one outcome; an outcome owns 0:N raw records and is replayed once to each live subscriber.
  - **DRY rationale:** all five finders need identical empty/partial/failure semantics.
  - **Future extensions:** new presentation detail belongs in bounded diagnostics, not additional terminal states.
- **`PathIdentity`** — canonical comparison key (`realpath` or normalized absolute path) plus deterministic unresolved source tuple.
  - **Relationships:** one raw file record has one identity; N colliding records reduce to one winner before sorting.
  - **DRY rationale:** deduplication and tie-breaking must not vary across asynchronous producers or finders.
  - **Future extensions:** platform-specific separator normalization remains isolated here.
- **`SliceBatcher`** — deterministic record reducer that yields after 25 completed records or 5ms of injected monotonic time.
  - **Relationships:** one producer-owned batcher consumes enriched candidates after root enumeration completes; it invokes one finder adapter per atomic record before session settlement.
  - **DRY rationale:** every parser needs the same event-loop fairness and `record`/`skip`/`failure(kind)` containment.
  - **Future extensions:** budgets may become configuration only if profiling shows a user-facing need; tests inject both budgets and clock.
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
- **`VisionFinderRecord`** — attaches namespace/file/root metadata to initiatives parsed from an already-read YAML payload.
  - **Relationships:** one YAML file produces 0:N initiatives.
  - **DRY rationale:** synchronous vision commands and the async picker retain one policy without growing the 2,000-line `vision.lua` domain module.
  - **Future extensions:** alternate vision formats would add adapters, not IO to the pure parser.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `AsyncFileSource` | `lua/parley/async_file_source.lua` | new | libuv directory/stat/open/read/realpath APIs |
| `GitMarkdownSource` | `lua/parley/git_markdown_source.lua` | new | streaming `git ls-files` subprocesses |
| `FinderLoadSession` | `lua/parley/finder_loader.lua` | new | producer ownership, subscribers, scheduling, warnings, and picker lifecycle |
| `PickerStatus` | `lua/parley/float_picker.lua` | modified | results-buffer status rendering and local spinner timer |
| `PickerStatusController` | `lua/parley/picker_status.lua` | new | status state and timer lifecycle |
| `FakeGitFileList` | `tests/fixtures/fake_git_file_list` | new | process-level Git stdout/stderr/chunk/exit behavior |

- **`AsyncFileSource`** — asynchronously traverses configured roots without following directory symlinks, with at most 16 filesystem operations in flight and idempotent cancellation.
  - **Injected into:** finder producers through `finder_loader`; tests use a deterministic callback fake while integration tests exercise real libuv temp directories.
  - **Future extensions:** alternate filename predicates and recursion depth are snapshot options.
  - **Path-list enrichment:** `read_paths(paths, { stat = true, read = false, concurrency = 16 }, on_record, on_done)` owns Markdown's asynchronous stat acquisition and any later Git-listed-file reads. Cancellation, record-level failure counts, and concurrency are identical to traversal.
- **`GitMarkdownSource`** — spawns one Git command per member, incrementally parses NUL records, caps stderr at 4096 bytes and the pending unterminated path fragment at 16384 bytes, and discards staged stdout on non-zero exit.
  - **Injected into:** Markdown producer; the executable/runtime is replaceable so tests run the process-level fixture.
  - **Future extensions:** cancellation and concurrency remain per-root even if Git gains another listing mode.
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
- Create: `tests/unit/finder_scan_spec.lua`

- [ ] **Step 1: Write failing snapshot/fingerprint tests**

  Cover immutable deep-copied ordered roots and every included/excluded
  fingerprint field. Mutate constructor input, an object returned by `copy()`,
  and the proxy itself; only proxy assignment errors and none changes the
  fingerprint or a later copy.

- [ ] **Step 2: Run the focused test and confirm RED**

  Run: `nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/finder_scan_spec.lua" -c qa`
  Expected: FAIL because `parley.finder_scan` does not exist.

- [ ] **Step 3: Implement `ScanSnapshot` and fingerprinting**

  Export the first two exact pure seams:

  ```lua
  M.snapshot(opts) -- -> immutable { kind, roots, recursion, max_depth, pattern, backend }
  M.fingerprint(snapshot) -- -> deterministic length-prefixed string
  ```

- [ ] **Step 4: Run snapshot tests and confirm GREEN**

  Run the focused command from Step 2; expected snapshot/fingerprint examples PASS while later path tests are not yet present.

- [ ] **Step 5: Write failing path identity/dedup/sort tests**

  Cover `/` normalization, `realpath` fallback, root ordinals, bytewise ties, overlapping roots, and arrival-order-independent canonical collision winners.

- [ ] **Step 6: Run path tests and confirm RED**

  Run the focused command; expected FAIL because `path_identity` is nil.

- [ ] **Step 7: Implement path identity, dedup, and stable sort**

  Export:

  ```lua
  M.path_identity(path, root_ordinal, deps) -- -> { key, source = { root_ordinal, unresolved } }
  M.deduplicate(records) -- -> one record per identity.key, minimum source tuple
  M.sort(records, primary_less) -- primary comparator, then identity.key bytewise
  ```

  Normalize absolute paths lexically before optional injected `realpath`; never use locale collation or async arrival order.

- [ ] **Step 8: Run path tests and confirm GREEN**

  Run the focused command; expected snapshot and path groups PASS.

- [ ] **Step 9: Write failing outcome-algebra tests**

  Exercise all-absent success, partial roots/records, all attempted roots failed, and intentional skips.

- [ ] **Step 9a: Run outcome tests and confirm RED**

  Run: `nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/finder_scan_spec.lua" -c qa`
  Expected: FAIL because `new_accumulator`/`outcome` are nil.

- [ ] **Step 10: Implement outcome reducers**

  Export:

  ```lua
  M.new_accumulator(root_count)
  M.root_skipped(acc, ordinal)
  M.root_succeeded(acc, ordinal, records)
  M.root_failed(acc, ordinal, kind, diagnostic)
  M.record_failed(acc, kind, diagnostic)
  M.outcome(acc) -- success|partial|failure
  ```

- [ ] **Step 11: Write failing diagnostic-policy tests**

  Cover the exact exported `FAILURE_KIND` table above, arbitrary thrown values,
  invalid adapter results, ten-diagnostic cap, control-character replacement,
  and 512-byte UTF-8-safe truncation.

- [ ] **Step 11a: Run diagnostic tests and confirm RED**

  Run the exact focused command from Step 9a; expected FAIL because `sanitize_diagnostic` is nil and exception containment is absent.

- [ ] **Step 12: Implement diagnostic policy**

  Export:

  ```lua
  M.sanitize_diagnostic(text, byte_cap)
  ```

- [ ] **Step 13: Write failing batch-budget tests**

  With an injected clock/scheduler, prove exact yielding after 25 records or 5ms, resume without loss/duplication, and adapter `pcall` containment.

- [ ] **Step 13a: Run batch tests and confirm RED**

  Run the exact focused command from Step 9a; expected FAIL because `new_batcher` is nil.

- [ ] **Step 14: Implement `SliceBatcher`**

  Export:

  ```lua
  M.new_batcher({ item_budget = 25, time_budget_ms = 5, now = now, schedule = schedule })
  ```

  The batcher wraps adapter calls with `pcall`, accepts only
  `{ kind = "record", value = ... }`, `{ kind = "skip" }`, or
  `{ kind = "failure", failure_kind = M.FAILURE_KIND.<member> }`, rejects any
  unregistered string as `invalid_adapter_result`, and schedules before the next
  record after either budget is exhausted.

- [ ] **Step 15: Run the complete pure spec and diff check**

  Run the focused test from Step 2 and `git diff --check`; expected all groups PASS and silent diff check.

- [ ] **Step 16: Commit pure scan policy**

  ```bash
  git add lua/parley/finder_scan.lua tests/unit/finder_scan_spec.lua
  git commit -m "finder: #189 add deterministic scan policy"
  ```

### Task 2: Add cancellable asynchronous filesystem acquisition

**Files:**
- Create: `lua/parley/async_file_source.lua`
- Create: `tests/unit/async_file_source_spec.lua`
- Create: `tests/integration/async_file_source_spec.lua`

- [ ] **Step 1: Write failing traversal tests against an injected uv fake**

  Specify `scan({ roots, recurse, max_depth, match, read, concurrency = 16 }, on_root, on_done)` for absent roots, transactional enumeration failure, symlink directories, and component depth. Root preflight `ENOENT` skips an optional root; other preflight errors, any required-directory `fs_scandir` open/drain error, or an unknown entry type needed for safe traversal fails the root and discards staged candidates.

- [ ] **Step 2: Run unit tests and confirm RED**

  Run: `nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/async_file_source_spec.lua" -c qa`
  Expected: FAIL with `module 'parley.async_file_source' not found`.

- [ ] **Step 3: Implement asynchronous traversal**

  Use async root preflight and `fs_scandir`; directory links are file candidates only and never traversal roots. Stage candidate paths/types until every directory in that root drains successfully. Only after this transactional enumeration boundary publish candidates into async per-record stat/read enrichment; candidate stat/open/read failures increment record failures and never roll back the root.

- [ ] **Step 4: Run traversal tests and confirm GREEN**

  Run the unit command; expected traversal group PASS.

- [ ] **Step 5: Write failing concurrency/cancellation tests**

  Assert at most 16 operations in flight, idempotent cancel, and no callbacks after cancellation.

- [ ] **Step 5a: Run concurrency/cancellation tests and confirm RED**

  Run: `nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/async_file_source_spec.lua" -c qa`
  Expected: FAIL because traversal is uncapped and cancellation cleanup is incomplete.

- [ ] **Step 6: Implement the shared operation queue and cancellation token**

  Route traversal stat work through the capped queue and close queued/active handles exactly once.

- [ ] **Step 7: Write failing `read_paths` tests**

  Specify `read_paths(paths, opts, on_record, on_done)` with async stat/read, record failures, the shared concurrency cap, and cancellation.

- [ ] **Step 7a: Run `read_paths` tests and confirm RED**

  Run the exact unit command from Step 5a; expected FAIL because `read_paths` is nil.

- [ ] **Step 8: Implement `read_paths` and descriptor cleanup**

  Use async `fs_open`, repeated `fs_read`, `fs_close`, and optional `fs_realpath`; close every descriptor exactly once.

- [ ] **Step 9: Run all unit groups and confirm GREEN**

  Run the unit command; expected zero failures.

- [ ] **Step 10: Write real-libuv integration coverage**

  Build temp roots with nested files, missing optional roots, a symlinked directory, and a denied/unreadable-or-injected-failing root. Verify a scheduled sentinel runs before completion and cancellation drains handles without a late terminal callback.

- [ ] **Step 11: Run the integration spec and confirm GREEN**

  Run the integration command below; expected zero failures.

- [ ] **Step 12: Run final checks**

  Run:

  ```bash
  nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/async_file_source_spec.lua" -c qa
  nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/async_file_source_spec.lua" -c qa
  git diff --check
  ```

  Expected: both specs report zero failures; diff check is silent.

- [ ] **Step 13: Commit the async file source**

  ```bash
  git add lua/parley/async_file_source.lua tests/unit/async_file_source_spec.lua tests/integration/async_file_source_spec.lua
  git commit -m "finder: #189 add asynchronous file source"
  ```

### Task 3: Teach the picker a nonselectable animated status

**Files:**
- Create: `lua/parley/picker_status.lua`
- Modify: `lua/parley/float_picker.lua`
- Create: `tests/unit/picker_status_spec.lua`
- Modify: `tests/unit/float_picker_spec.lua`

- [ ] **Step 1: Write failing controller timer tests**

  Assert 120ms injected ticks use `progress.frame` and stop is idempotent.

- [ ] **Step 2: Run controller tests and confirm RED**

  Run the `picker_status_spec.lua` command below; expected module-not-found.

- [ ] **Step 3: Implement the focused status controller**

  Keep it under 120 lines and expose start/set/stop/current-render state.

- [ ] **Step 4: Run controller tests and confirm GREEN**

  Run the controller command; expected zero failures.

- [ ] **Step 5: Write failing float-picker status-render tests**

  Assert empty loading opens, status survives live query filtering, update clears it atomically, and error remains visible.

- [ ] **Step 6: Write failing nonselection/teardown tests**

  Assert confirm, double-click, movement, and mappings cannot select status; Esc/window destruction stops once and calls cancel once.

- [ ] **Step 7: Run float-picker tests and confirm RED**

  Run the `float_picker_spec.lua` command below; expected failure because empty status pickers warn and return.

- [ ] **Step 8: Integrate the controller without synthetic items**

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

- [ ] **Step 9: Run picker/controller/progress specs and diff check**

  Run:

  ```bash
  nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/picker_status_spec.lua" -c qa
  nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/float_picker_spec.lua" -c qa
  nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/progress_spec.lua" -c qa
  git diff --check
  ```

  Expected: all three specs report zero failures; diff check is silent.

- [ ] **Step 10: Commit picker status**

  ```bash
  git add lua/parley/picker_status.lua lua/parley/float_picker.lua tests/unit/picker_status_spec.lua tests/unit/float_picker_spec.lua
  git commit -m "picker: #189 add animated lifecycle status"
  ```

### Task 4: Add the exactly-once loader session

**Files:**
- Create: `lua/parley/finder_loader.lua`
- Create: `tests/unit/finder_loader_spec.lua`

- [ ] **Step 1: Write failing session settlement tests**

  Use a lazy producer factory fake that emits already-adapted raw finder metadata
  plus final counts. Cover the exact API/ownership table above: subscription
  cancel idempotence; picker last-subscriber producer cancellation; retained
  zero-subscriber continuation; delivery-turn replay; repeated settlement;
  explicit owner cancellation; ownerless `on_terminal`; `on_retire`; refusal
  after retirement; and defensive snapshot access. Assert the session has no
  adapter or batcher dependency.

- [ ] **Step 2: Run the focused test and confirm RED**

  Run: `nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/finder_loader_spec.lua" -c qa`
  Expected: FAIL with `module 'parley.finder_loader' not found`.

- [ ] **Step 3: Implement `new_session`**

  Store the producer factory without invoking it. Implement the exact public
  methods and subscription handle above. Accept only a terminal callback carrying
  a complete `ScanOutcome` of already-adapted raw finder metadata; do not parse
  or mutate counts.

- [ ] **Step 4: Run session tests and confirm GREEN**

  Run the focused command; expected settlement group PASS.

- [ ] **Step 5: Write failing picker-bridge lifecycle tests**

  Cover synchronous loading, live query at total post-settlement materialization,
  partial warning, total error, successful empty, and settlement keeping
  `opened` true until actual picker close/select/cancel. Make the materializer
  deliberately total and assert `open_picker` never invokes an adapter/batcher.
  Assert the producer factory has not been invoked when the picker opener
  returns.

- [ ] **Step 6: Run picker-bridge tests and confirm RED**

  Run the focused command; expected failure because `open_picker` is nil.

- [ ] **Step 7: Implement `open_picker`**

  Open status first and return a `{ picker, subscription }` binding after
  subscribing the generation; do not call `session:start()`. The finder entry
  point calls `session:start()` only after `open_picker` returns, proving the
  shell exists before the producer factory can start IO. On settlement apply
  only total deterministic recency/facet/render materialization and read
  `picker.current_query()` only at installation. All adapter batching belongs to
  the producer before it calls session settlement.

- [ ] **Step 8: Run session/bridge tests and confirm GREEN**

  Run the focused command; expected zero failures.

- [ ] **Step 9: Run shared regression checks**

  Run:

  ```bash
  nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/finder_scan_spec.lua" -c qa
  nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/finder_loader_spec.lua" -c qa
  nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/float_picker_spec.lua" -c qa
  git diff --check
  ```

  Expected: all specs report zero failures; diff check is silent.

- [ ] **Step 10: Commit the loader**

  ```bash
  git add lua/parley/finder_loader.lua tests/unit/finder_loader_spec.lua
  git commit -m "finder: #189 add shared loading sessions"
  ```

### Task 5: Implement streaming Git-aware Markdown discovery

**Files:**
- Create: `lua/parley/git_markdown_source.lua`
- Create: `tests/fixtures/fake_git_file_list`
- Create: `tests/integration/git_markdown_source_spec.lua`
- Modify: `lua/parley/markdown_finder.lua`
- Modify: `tests/unit/markdown_finder_spec.lua`

- [ ] **Step 1: Write the executable process fixture**

  Support delayed/chunked NUL stdout, stderr, newline paths, overlong fragments, and exit codes; tests will chmod it via uv.

- [ ] **Step 2: Write failing process framing/cancellation tests**

  Launch the fixture as a real subprocess and cover incremental NUL records, 4096 stderr cap, 16384 pending-fragment failure, non-zero staged-output discard, and cancel-once.

- [ ] **Step 3: Run process tests and confirm RED**

  Run the integration command below; expected module-not-found.

- [ ] **Step 4: Implement process framing and staging**

  Incrementally split stdout, bound buffers, stage raw relative byte strings until exit 0, and return idempotent cancellation. Do not validate paths here and do not use `tasker.run`.

- [ ] **Step 5: Run process framing tests and confirm GREEN**

  Run the integration command; expected fixture cases PASS.

- [ ] **Step 6: Add hermetic real-Git protocol tests**

  Spawn `git -C ROOT ls-files -z --cached --others --exclude-standard -- '*.md'`. Real-repository tests set a temp `HOME`, `XDG_CONFIG_HOME`, `GIT_CONFIG_GLOBAL`, and `GIT_CONFIG_NOSYSTEM=1`, write an isolated global excludes file, and clean all temp state. Cover tracked-but-currently-ignored files, untracked global excludes, `.git` exclusion, nested repositories/submodules as opaque entries, newline filenames, and non-repo/missing-Git/non-zero root failures. Treat output as the set union Git provides and deduplicate defensively.

- [ ] **Step 6a: Run real-Git protocol tests and confirm RED**

  Run: `nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/git_markdown_source_spec.lua" -c qa`
  Expected: FAIL because exact Git argv/root-outcome mapping and defensive dedup are not implemented.

- [ ] **Step 7: Implement exact Git invocation/root outcomes**

  Add the exact argv, missing/non-repo/non-zero failure mapping, and defensive byte-string dedup; leave all path validation to `MarkdownPathPolicy`.

- [ ] **Step 8: Run all Git-source tests and confirm GREEN**

  Run the integration command; expected zero failures.

- [ ] **Step 9: Write failing pure Markdown path/materializer tests**

  Specify `M.path_candidate(root, relative, max_depth)` and `M.materialize_records(opts)` as the sole owners of absolute/escaping/non-Markdown rejection, component depth, facet identity, and mtime/path sorting.

- [ ] **Step 10: Run pure Markdown tests and confirm RED**

  Run the `markdown_finder_spec.lua` command below; expected failures for missing pure seams.

- [ ] **Step 11: Implement pure Markdown path/materializer policy**

  Keep it free of process/filesystem calls and consume only staged raw paths plus enriched stat/identity records.

- [ ] **Step 12: Run pure Markdown tests and confirm GREEN**

  Run the unit command; expected pure policy groups PASS.

- [ ] **Step 13: Write failing Markdown entry-point lifecycle tests**

  Replace synchronous `_scan_members` cases with delayed injected sources; cover sentinel/spinner, live query, empty/all-absent, stat failure, partial/total roots, and Esc/late completion/reopen.

- [ ] **Step 14: Run entry-point tests and confirm RED**

  Run the unit command; expected failures because `open()` still scans synchronously.

- [ ] **Step 15: Migrate `markdown_finder.open`**

  Snapshot ordinary or ordered super-repo member roots; open the picker before
  starting Git; treat Git exit 0 as that root's enumeration success; pass
  accepted Git paths to `AsyncFileSource.read_paths` for bounded asynchronous
  stats; count stat failures as record failures; run the pure path/entry adapter
  through `SliceBatcher`; then settle the session exactly once. Subscribers
  apply existing `build_picker_data` and facet callbacks only after settlement.
  Cancelling the session cancels Git, path enrichment, and pending batches.
  Preserve repository facets in super-repo mode and directory facets in
  ordinary mode.

- [ ] **Step 16: Run Markdown/shared tests and diff check**

  Run:

  ```bash
  nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/git_markdown_source_spec.lua" -c qa
  nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/markdown_finder_spec.lua" -c qa
  nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/finder_loader_spec.lua" -c qa
  nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/float_picker_spec.lua" -c qa
  git diff --check
  ```

  Expected: all specs report zero failures; diff check is silent.

- [ ] **Step 17: Commit Markdown discovery**

  ```bash
  git add lua/parley/git_markdown_source.lua lua/parley/markdown_finder.lua tests/fixtures/fake_git_file_list tests/integration/git_markdown_source_spec.lua tests/unit/markdown_finder_spec.lua
  git commit -m "markdown: #189 stream Git-aware discovery"
  ```

- [ ] **Step 18: Prepare and invoke the M1 boundary**

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

  After the M1 commit, run `sdlc actual --issue 189` and compare the measured M1
  window with the M1 share of the 16.6-hour derivation. If evidence materially
  changes the remaining estimate, revise frontmatter and append an issue/plan
  Revision before starting M2; do not silently preserve or back-fit the original
  estimate.

## Chunk 2: Chat and Note prewarm migration

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
  overlapping-root/symlink dedup. Cache lookup occurs after async stat and
  before async read: unchanged canonical path+mtime produces `cached`; only a
  miss/change requests ten lines and produces `lines`.

- [ ] **Step 2: Run Chat logic tests and confirm RED**

  Run: `nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/chat_finder_records_spec.lua" -c qa`
  Expected: FAIL with `module 'parley.chat_finder_records' not found`.

- [ ] **Step 3: Extract raw adapter and materializer**

  Keep `chat_finder_records.lua` under about 300 lines and free of Neovim IO. The entry point asks `AsyncFileSource` to stat, looks up canonical path+mtime in the cache, and reads only the first ten lines on miss/change. Return complete raw metadata independent of recency/query/facets; apply opener recency and tag/root facets after settlement. Keep the benchmark pointed at the pure materializer with prebuilt records so it measures parsing rather than disk scheduling.

- [ ] **Step 4: Write failing entry-point and prewarm join tests**

  In `chat_finder_logic_spec.lua`, assert immediate picker return, a delayed producer permitting a scheduled sentinel and spinner tick, live sticky query, cancel/reopen, no post-cancel update, successful empty, all-absent optional roots, partial enumeration, total enumeration failure, and stat/read record failure. For fingerprint construction, vary finder kind; ordered normalized root path/label/primary; recursion/depth; filename pattern; and backend options one at a time and require a new producer, while recency/facets/query differences still join. Assert one producer for multiple matching subscribers and distinct recency materialization for two joined openers.

- [ ] **Step 5: Run entry-point tests and confirm RED**

  Run: `nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/chat_finder_logic_spec.lua" -c qa`
  Expected: FAIL at the immediate-open/prewarm assertions because current code waits for prewarm and scans synchronously.

- [ ] **Step 6: Implement joinable Chat prewarm**

  Replace `_prewarm_pending/_prewarm_callbacks` with one retained in-flight
  `FinderLoadSession`. `prewarm()` uses `ownership = "retained"`; a matching
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

  Construct the exact discovery fingerprint in production, subscribe matching
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
  raw issue metadata before settling. After settlement, apply only total
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

  Specify `vision_finder_records.adapt({ path, name, lines, repo_name, identity })`. Assert reuse of `vision.parse_vision_yaml`, namespace/file/line/repo metadata, intentional non-YAML skip, project-only picker rendering, deterministic path ties, malformed adapter failure containment, and no mutation. Keep IO and cache ownership outside the pure module.

- [ ] **Step 2: Run record tests and confirm RED**

  Run: `nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/vision_finder_records_spec.lua" -c qa`
  Expected: FAIL with `module 'parley.vision_finder_records' not found`.

- [ ] **Step 3: Implement the pure Vision record module**

  Keep it under about 180 lines and reuse `vision.parse_vision_yaml`/`parse_priority`; leave synchronous `vision.load_vision_dir` unchanged.

- [ ] **Step 4: Write failing Vision Finder lifecycle tests**

  In the dedicated `vision_finder_spec.lua`, use a delayed producer and assert `open()` returns with `scanning…`, then a scheduled sentinel and spinner tick run. Cover successful empty/all-absent roots, root aggregation, partial/total enumeration failure, read/parser record failures versus intentional skips, query changes during load, cancellation/reopen with ignored late completion, stable path ordering, and selection line jump after settlement.

- [ ] **Step 5: Run entry-point tests and confirm RED**

  Run: `nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/vision_finder_spec.lua" -c qa`
  Expected: FAIL at module/entry-point lifecycle assertions because current finder scans before opening.

- [ ] **Step 6: Migrate Vision Finder**

  Enumerate non-recursive `*.yaml`, async-read each payload, and batch the pure
  adapter into raw initiative metadata before settling. After settlement, apply
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

  Map `finder_scan`, `async_file_source`, `git_markdown_source`, `finder_loader`, `picker_status`, all four focused finder-record modules, production finders, process fixture, and all new unit/integration specs. Record the 25-record/5ms, 16-in-flight, 512-byte diagnostic, 4096-byte stderr, 16384-byte pending-path, ten-diagnostic, and 120ms spinner budgets as implementation constants rather than product promises.

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
