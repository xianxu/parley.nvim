---
id: 000170
status: working
deps: []
github_issue:
created: 2026-07-08
updated: 2026-07-11
estimate_hours: 14.15
started: 2026-07-11T21:57:07-07:00
---

# parley chat performance problem

## Problem

Long Parley chats become noticeably less responsive to ordinary editing around
1,000 lines. `:MarkdownPreview` amplifies the symptom and is likely the dominant
cost when enabled, but it is external to Parley and therefore outside this
issue's optimization scope.

Parley's viewport decoration provider renders only the visible region plus a
small margin, but its redraw path still reads the complete buffer to locate the
managed footnote footer and may scan backward line-by-line for structural
highlight state. Separately, every `TextChangedI` event rebuilds timezone and
managed-footnote diagnostics from the full buffer. These costs scale with total
document length even when the edit and viewport are local.

The exchange model is not rebuilt per keystroke: the authoritative chat parse
happens when submitting/resubmitting, and a live model is maintained during
streaming/tool recursion. A continuously maintained incremental exchange parser
would therefore add complexity without addressing the current typing path.

## Spec

### Scope

Optimize only Parley-owned per-keystroke and redraw work in chat/Markdown
buffers. Automated measurements run without `:MarkdownPreview` so attribution
stays inside Parley. Documentation may describe MarkdownPreview as an optional
manual comparison, but this issue will not configure, throttle, or patch that
plugin.

Benchmark before optimizing. Preserve the baseline results so each subsequent
change can be compared against the same scenarios. The performance suite is
initially report-only: timing variation must never fail CI until stable,
portable budgets are deliberately established in a separate decision.

### Reusable performance framework

Add a headless-Neovim performance framework under `tests/perf/` and expose it
through `make perf`.

The framework owns:

- deterministic fixture/scenario construction;
- warmup and repeated sampling using `vim.uv.hrtime()`;
- raw samples plus median and p95 summaries;
- terminal-table and machine-readable JSON reporters;
- environment metadata sufficient to compare runs; and
- validity assertions that fail only when a scenario did not exercise what it
  claims, never because a timing crossed a threshold.

Timing records distinguish **inclusive** scenarios from **isolated** phases.
`edit_total` measures the complete edit/event/redraw interval and may contain
nested work; `timezone_refresh`, `footnote_refresh`, `decoration_redraw`, and
`spell_typeahead` are separate runs that call only that phase's public or test
seam. Reports must not add or subtract overlapping timings or present isolated
phase totals as a decomposition of `edit_total`.

The first scenario creates normally attached Parley chat buffers at 100, 1,000,
and 5,000 lines by calling normal `parley.setup`, opening a named chat file in a
real window, and allowing the production buffer handlers to attach. It positions
the cursor in the middle of a long answer near 80% of the document, enters
insert mode through Neovim input, inserts one ASCII character, and waits for
both `changedtick` and a harness observer on the real `TextChangedI` autocmd.
The harness must not invoke Parley's production callbacks directly for
`edit_total`. A forced `redraw` after the edit exercises the installed
decoration provider; observer counts prove that the autocmd and provider ran.
Isolated phase scenarios may call their named seam directly and are labeled as
such.

In addition to wall-clock samples, the harness records structural work counters:
buffer line-read calls, total lines requested, and full-buffer-read attempts by
each observed phase. All production paths in scope—diagnostic refresh,
managed-footer/highlight structural lookup, and decoration computation—must read
buffer text through one injected `LineReader` adapter. It accounts for
`nvim_buf_get_lines`, `nvim_buf_get_text`, `vim.fn.getline`, and any future
equivalent; cached snapshots record the source reads when populated. Direct
buffer reads outside the adapter in those paths are rejected by an architecture
test. The adapter must preserve production behavior and be tested against known
read sequences. These counters are correctness evidence and may fail tests when
a documented work bound is violated; only elapsed time remains report-only.
Output emphasizes scaling ratios as well as median/p95 latency.

The JSON report has a versioned stable envelope: `schema_version`,
`generated_at`, `timing_unit: "milliseconds"`, `environment` (OS, Neovim
version, commit), and `scenarios[]`. Each scenario contains `name`, `phase`,
`attribution` (`inclusive` or `isolated`), `line_count`, `iteration_count`,
`elapsed_ms` (`samples`, `median`, `p95`), and `work` (`line_read_calls`,
`lines_requested`, `full_buffer_reads`, `structure_rows_processed`). By default `make perf` overwrites
`.test-tmp/perf/parley-chat-typing.json`; `PERF_OUTPUT=<path>` overrides it.
Generated JSON reports are never committed. Only baseline and optimized
summaries—command, environment, medians/p95s, scaling ratios, and work
counters—are appended to this issue's `## Log`, which is the durable comparison
record.

The existing `tests/perf_chat_finder.lua` remains supported. It may migrate to
the shared timing/reporting core only if that is a small behavior-preserving
change; migration is not required to complete #170.

### Optimization boundary

Use the baseline to confirm which Parley phases scale with document size before
changing production behavior. Then:

- remove complete timezone and managed-footnote diagnostic rebuilding from the
  synchronous `TextChangedI` path. Neither diagnostic source attaches a
  `TextChangedI` handler. Both refresh synchronously on `InsertLeave`,
  normal-mode `TextChanged`, `BufWritePost`, `BufEnter`, and `WinEnter`; thus
  insert-mode staleness lasts only until insert mode ends, with no timer delay;
- make chat and Markdown decoration computation genuinely viewport-bounded,
  including managed-footer discovery;
- replace the highlighter's potentially unbounded backward bootstrap with a
  bounded or conservatively invalidated structural-state lookup; and
- keep submission-time chat parsing and the live streaming exchange model as
  the authoritative semantic structures rather than introducing a new
  continuously maintained exchange model.

Share timing/statistics/reporting and any identical buffer-lifecycle primitive,
but do not force diagnostics and highlight state behind one invalidation API:
their freshness contracts differ (`ARCH-DRY`). Keep structural scanning/state
transitions as pure functions and Neovim events, buffers, and redraw callbacks
as thin adapters (`ARCH-PURE`). Each cache owns its buffer-keyed state,
generation, invalidation triggers, and teardown. If cached highlight state
cannot be proven valid for a redraw, recompute it within the explicit bounded
context rather than display silently stale semantics. Optimize the measured
typing path, not a speculative parser architecture (`ARCH-PURPOSE`).

One neutral `BufferLifecycle` adapter owns shared event registration and
teardown. At each convergence event it independently invokes diagnostic refresh
and structure rebuild; neither consumer owns or calls the other. Stream
finalization invokes the same coordinator entry point.

The structural work contract is observable and independent of machine speed:

- `TextChangedI` may inspect the current line/word for spell typeahead but must
  request no document-wide line range;
- a redraw may read the visible rows, the existing 20-line viewport margin, at
  most 200 preceding context lines, and at most the existing 500-line reasoning
  lookahead per reasoning opener encountered inside that bounded region;
- managed-footer discovery during redraw must not request `0..-1` or otherwise
  scan all document lines; and
- increasing a fixture from 1,000 to 5,000 lines with the same viewport shape
  must not increase the measured `edit_total` or `decoration_redraw`
  `lines_requested` counters at all. Counters reset after fixture setup and
  warmup, so setup reads are excluded and the fixed allowance is exactly zero.

For ordinary prose edits, structure maintenance may fingerprint/process only
the changed rows; the 1,000- and 5,000-line scenarios must therefore report the
same `structure_rows_processed`. A structural-marker edit during insert mode
marks decoration state dirty in bounded changed-range work and may temporarily
suppress Parley decorations. A synchronous full structure rebuild occurs on
`InsertLeave`, normal `TextChanged`, `BufWritePost`, buffer entry, and
stream-leg finalization—never inside `TextChangedI` or redraw.

### Behavior and lifecycle requirements

Optimization must preserve:

- timezone and managed-footnote diagnostics after their documented convergence
  event;
- managed-footnote, reasoning, code, tool, question, and answer highlighting;
- correct highlighting after scrolling, multiple windows, streaming, undo/redo,
  external buffer edits, buffer enter/leave, write, unload, and deletion;
- bounded cleanup of timers/caches on buffer teardown; and
- unchanged chat submission, recursion, and exchange-model semantics.

Freshness oracles by event:

- During insert mode, existing timezone/footnote diagnostics may remain at
  their pre-insert state.
- During insert mode, a structural-marker edit may suppress Parley decorations
  until `InsertLeave`; ordinary prose edits retain valid structure/decorations.
  The convergence event rebuilds before its autocmd returns.
- `InsertLeave`, normal-mode `TextChanged`, and `BufWritePost` synchronously
  rebuild both diagnostic sources before their autocmd returns.
- `BufEnter` and `WinEnter` synchronously hydrate diagnostics for the entered
  buffer/window.
- Scrolling or opening a second window recomputes correct highlights for that
  window's bounded viewport without requiring a text edit.
- Streaming/programmatic edits that emit normal `TextChanged` converge through
  that event. The chat-response stream-finalization callback explicitly invokes
  the same `refresh_diagnostics(buf)` entry point once after the final buffer
  mutation, so completion leaves diagnostics current even if intermediate edits
  emitted no `TextChanged`.
- Undo/redo and external buffer mutations converge on their normal
  `TextChanged`/`BufWritePost` event.
- `BufUnload`/`BufDelete` cancels pending generations and removes buffer-owned
  cache state; a later callback is a no-op.

No performance cache may be keyed only by buffer number without lifecycle
cleanup. No delayed callback may mutate an invalid buffer or apply an obsolete
generation.

### Verification

Add pure tests for timing statistics/report shaping and any extracted
structural-state/invalidation logic. Add integration tests through real Neovim
buffers for the exact freshness oracles above: insert-mode staleness followed by
`InsertLeave`, normal `TextChanged`, `BufWritePost`, `BufEnter`/`WinEnter`,
viewport scrolling, multiple windows, streaming completion, undo/redo, external
edits, and `BufUnload`/`BufDelete` teardown.

Run the report-only benchmark before and after implementation at all three
document sizes on the same environment. Completion is determined by the
structural work-counter assertions, not favorable timing noise: the optimized
report must show no document-wide diagnostic scans in `TextChangedI` and no
total-document redraw scan, with the 1,000→5,000 combined line-read count within
the harness's fixed setup allowance. Record the elapsed results even if they are
flat or noisy; they are evidence, not a gate. Append both summaries and
environment metadata to `## Log`; do not convert elapsed numbers into a CI
threshold in this issue.

## Done when

- `make perf` runs reusable headless-Neovim scenarios and emits terminal plus
  versioned JSON reports at the documented location without timing-based
  pass/fail gates.
- A committed/logged baseline identifies the Parley-owned costs at
  100/1,000/5,000 lines before production optimization.
- Ordinary insert-mode changes do not synchronously rebuild full-buffer timezone
  or managed-footnote diagnostics.
- Chat/Markdown redraw computation does not read or scan the entire document
  merely to render a bounded viewport.
- Highlight and diagnostic behavior converges correctly across scrolling,
  multiple windows, streaming, undo/redo, external edits, writes, and teardown.
- Before/after reports show the intended scaling improvement, and the complete
  structural counters prove the defined work bounds; elapsed scaling is
  recorded without becoming a gate; and the complete correctness/lint suite
  passes.

## Plan

- [ ] Build the reusable report-only headless performance framework and capture
      the baseline, including observer and work-counter validity tests.
- [x] Remove full-buffer diagnostic work from `TextChangedI` and test every
      specified convergence trigger.
- [x] Bound decoration-provider structural work and test scroll, multi-window,
      generation, and teardown behavior.
- [x] Verify the complete lifecycle matrix and capture the optimized report on
      the baseline environment.
- [ ] Update tooling and atlas documentation with the benchmark and landed
      performance architecture.

## Estimate

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec             design=0.30 impl=0.10
item: lua-neovim             design=0.60 impl=0.60
item: lua-neovim             design=0.60 impl=0.60
item: lua-neovim             design=0.60 impl=0.60
item: lua-neovim             design=0.60 impl=0.60
item: lua-neovim             design=0.60 impl=0.60
item: lua-neovim             design=0.60 impl=0.60
item: lua-neovim             design=0.60 impl=0.60
item: lua-neovim             design=0.60 impl=0.60
item: lua-neovim             design=0.60 impl=0.60
item: lua-neovim             design=0.60 impl=0.60
item: cross-cutting-refactor design=0.20 impl=0.20
item: atlas-docs             design=0.04 impl=0.08
item: milestone-review       design=0.04 impl=0.20
design-buffer: 0.15
total: 14.15
```

Ten focused Lua/Neovim primitives cover statistics, reporting, fixtures/input,
instrumented reads, diagnostic aggregation, lifecycle coordination, canonical
classification, pure structure, cache maintenance, and provider integration.
One cross-cutting primitive covers canonical seams through existing consumers.
Values apply the thorough-spec discount and v3.1 implementation scale.

*Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against
`baseline-v3.1.md`. Method A only. The calibration source was stale at
derivation time, so this value is provisional until recalibration.*

## Log

### 2026-07-08

### 2026-07-12 — audited and designed

Static audit found viewport-bounded output masking three document-proportional
inputs: full-buffer managed-footer discovery during redraw, potentially
unbounded backward highlight bootstrap, and full-buffer timezone/footnote
refreshes on every `TextChangedI`. The operator selected a reusable real-Neovim
benchmark harness, report-only enforcement, and Parley-owned hot paths as the
scope; MarkdownPreview remains an optional manual comparison.

### 2026-07-12 — spec-review precision pass

Fresh-context review found the initial benchmark attribution, diagnostic
freshness, structural bounds, JSON persistence, and lifecycle test oracles too
ambiguous for implementation planning. The spec now distinguishes inclusive
from isolated timings, defines the real insert-mode scenario and observer
proofs, adds structural line-read counters, fixes diagnostic convergence to
named synchronous events, gives redraw work explicit bounds, versions the JSON
envelope/location, and enumerates the lifecycle matrix. Diagnostics and
highlight caches are no longer forced into one invalidation abstraction merely
for `ARCH-DRY`.

### 2026-07-12 — spec-review observability pass

The second fresh review found four remaining loopholes. The fixed structural
allowance is now zero after counter reset; stream finalization names an explicit
diagnostic refresh hook; all in-scope text access derives from an instrumented
`LineReader` enforced by an architecture test; and the report schema now states
timing units, attribution, phase identity, and exact work-counter fields. The
durable baseline is explicitly the issue-log summary, never generated JSON.

### 2026-07-12 — plan-quality gate correction

The code-entry judge caught that buffer-read counters alone could hide
document-proportional Lua recomputation after structural edits. The contract now
counts processed structure rows: prose edits update locally, while structural
edits mark decoration state dirty and rebuild only at named non-keystroke
convergence events. The estimate was re-derived for six focused Lua features
plus their cross-cutting seam (7.94h), and cleanup no longer freezes unrelated
draft state.

### 2026-07-12 — lifecycle ownership and estimate correction

The second code-entry judge found diagnostic ownership of structure rebuilds
contradicted separate freshness contracts. A neutral `BufferLifecycle` now owns
events and independently calls both consumers. Pure replacement is
transactional/non-mutating, and rebuild failure leaves the cache dirty without
partial state. The estimate now itemizes ten Lua/Neovim concerns plus their
integration surface (14.15h).

### 2026-07-12 — real chat-typing baseline

Command: `make -f Makefile.parley perf` at commit
`5d21d1663ebe8d18021f45075445c5cb03c24a9b`. Environment: macOS 26.5.1
(25F80), Neovim 0.11.7. The scenario used 5 warmups and 20 independent
measured edits per size; elapsed values remain report-only.

| phase | lines | median ms | p95 ms | ratio vs 100 | work: calls / lines / full / structure |
| --- | ---: | ---: | ---: | ---: | ---: |
| edit_total | 100 | 3.58 | 3.97 | 1.00x | 12 / 801 / 6 / 0 |
| edit_total | 1,000 | 6.06 | 8.51 | 1.69x | 1,175 / 6,817 / 4 / 0 |
| edit_total | 5,000 | 23.79 | 25.73 | 6.64x | 7,575 / 35,617 / 4 / 0 |
| timezone_refresh | 100 | 0.03 | 0.12 | 1.00x | 1 / 100 / 1 / 0 |
| timezone_refresh | 1,000 | 0.30 | 0.33 | 9.20x | 1 / 1,000 / 1 / 0 |
| timezone_refresh | 5,000 | 1.64 | 1.89 | 50.00x | 1 / 5,000 / 1 / 0 |
| footnote_refresh | 100 | 0.12 | 0.19 | 1.00x | 1 / 100 / 1 / 0 |
| footnote_refresh | 1,000 | 0.81 | 0.84 | 6.90x | 1 / 1,000 / 1 / 0 |
| footnote_refresh | 5,000 | 3.89 | 3.95 | 33.31x | 1 / 5,000 / 1 / 0 |
| decoration_redraw | 100 | 0.23 | 0.26 | 1.00x | 3 / 200 / 1 / 0 |
| decoration_redraw | 1,000 | 1.45 | 2.44 | 6.29x | 577 / 2,408 / 1 / 0 |
| decoration_redraw | 5,000 | 8.08 | 8.23 | 35.17x | 3,777 / 12,808 / 1 / 0 |
| spell_typeahead | 100 | <0.01 | 0.04 | 1.00x | 1 / 1 / 0 / 0 |
| spell_typeahead | 1,000 | <0.01 | 0.03 | 2.17x | 1 / 1 / 0 / 0 |
| spell_typeahead | 5,000 | <0.01 | 0.02 | 1.17x | 1 / 1 / 0 / 0 |

The baseline exposes the intended current behavior before optimization:
timezone and footnote refreshes perform full-buffer reads, and decoration work
and latency grow sharply with document size. `ARCH-PURPOSE`: these observed
proportional/full reads are the costs subsequent tasks must remove.

### 2026-07-12 — diagnostics removed from the keystroke path

`DiagnosticRefresh` now synchronously orders timezone then managed-footnote
refresh, while neutral `BufferLifecycle` owns `InsertLeave`, `TextChanged`,
`BufWritePost`, `BufEnter`, `WinEnter`, stream-leg finalization, and teardown.
There is no `TextChangedI` diagnostic consumer. Real-buffer tests prove
diagnostics remain stale through that insert event and are current before each
named convergence autocmd returns; footnote teardown preserves unrelated
diagnostics in the shared skill namespace. Normal, recursive-tool, and abort
API legs each converge once after mutation, while the no-mutation coordinator
path converges zero times (`ARCH-PURE`, `ARCH-DRY`).

Focused evidence: diagnostic refresh 3/3, lifecycle 4/4, real-buffer diagnostic
integration 7/7, and chat-response integration 31/31. `make -f
Makefile.parley perf` completed with 5 warmups/20 samples: inclusive
`edit_total.full_buffer_reads` fell from the baseline 6/4/4 at 100/1,000/5,000
lines to 2/2/2; the two remaining reads are decoration work assigned to Tasks
5–6, so diagnostic full-buffer reads during the measured edit are zero. Lint
passed with 0 warnings/errors across 256 files and `git diff --check` passed.

Task 4's spec-review follow-up audited every post-mutation terminal return and
closed the remaining convergence exits, including delayed recursive lease
failure and topic generation. The recursive integration now completes both API
legs, proves one finalization per leg, and observes a real final UTC diagnostic;
pre-dispatch busy/no-mutation exits prove zero finalizations. Each named event
now mutates and asserts both timezone and managed-footnote freshness, while
separate `BufUnload` and `BufDelete` cases prove both sources clear and unrelated
shared diagnostics survive. Focused suites pass 3/3, 4/4, 9/9, and 31/31;
`make perf`, 256-file lint, and diff-check remain green.

### 2026-07-12 — pure bounded highlight structure

`highlight_structure` now owns the canonical prefix, fence, tool, reasoning,
draft, blank-line, and managed-footer classifications used by both the parser
and highlighter (`ARCH-DRY`). Its pure 0-based model records state before each
row plus half-open footer/draft ranges. Same-cardinality prose replacement
fingerprints only changed rows and returns a fresh structure; any grammar or
line-count change rejects after exactly the supplied rows without suffix work.
`define.is_footnote_line` remains the sole managed-footer predicate.

TDD evidence: the new spec first failed because the module was absent, then
passed 7/7; the complete unit suite passed 103 files, parser regression passed
54/54, legacy draft regression passed 9/9, and the pure architecture boundary
passed 6/6. The 25 highlighting cases relevant to structural rendering passed;
two legacy diagnostic-autocmd assertions in that combined file still encode
the eager lifecycle intentionally removed by Task 4 and are reserved for Task
7's lifecycle shadow sweep. Lint passed with 0 warnings/errors across 258 files
and `git diff --check` passed.

Task 5 review found that the public one-row counter concealed a full structure
copy and that each reasoning opener scanned toward EOF. The follow-up now
returns a fresh persistent root sharing immutable derived arrays, with tests
pinning one visited row and zero copied entries at 100/1,000/5,000 lines.
Reasoning end modes are indexed in one backward pass; 2,000 openers plus a
distant terminator prove exactly two linear visits per document row. The final
private footnote regex in `chat_respond` was replaced by
`define.is_footnote_line`; leading-whitespace parity and an architecture shadow
search defend canonical ownership (`ARCH-DRY`).

The exact-accounting follow-up distinguishes the API's contractual
`rows_processed` from measured implementation work: full builds now count all
three linear passes, while a cardinality mismatch still returns
`rows_processed = #new_lines` but records zero classifier visits.

### 2026-07-12 — buffer-owned bounded decoration structure

The decoration provider now shares one buffer-owned `HighlightStructure`
across windows. Initial setup builds before attachment/renderability; real
`on_lines` callbacks read only the changed half-open range and process exactly
one row for ordinary prose. Grammar or cardinality changes mark the cache dirty
without suffix work, and the provider declines to render until neutral
`BufferLifecycle` independently rebuilds after diagnostics. Candidate builds
swap transactionally; initial and convergence failures remain unrenderable,
notify/propagate synchronously, and retry cleanly. Teardown clears both cache
and reader state, with obsolete callbacks becoming no-ops (`ARCH-PURPOSE`).

Matched 1,000/5,000-line tests pin the redraw to exactly one
`lines(T,min(B+21,N),false)` call, identical requested rows, zero full reads,
and one structure row for the edit. Footer, draft, viewport bootstrap, and
reasoning lookahead perform no reads; busy reasoning is a redraw-only overlay.
Focused evidence: highlighting 34/34, perf scenario 11/11, lifecycle 5/5, and
performance architecture 4/4. `make -f Makefile.parley perf` passed its hard
gates: `edit_total` full reads 0/0/0 and structure rows 1/1/1 at
100/1,000/5,000; 1,000 and 5,000 requested rows matched at 88 for inclusive
edit and 61 for isolated redraw. Redraw medians were 0.22/0.33/0.30 ms and
inclusive edit medians 2.52/2.50/2.36 ms (report-only). Lint and diff-check
passed.

Task 6's spec review found lifecycle ownership and integrated-event coverage
gaps. Initial setup now rolls back both consumers and active ownership when
convergence fails, so a later setup genuinely retries. Real-buffer tests drive
stream growth, undo, redo, external `BufWritePost`, separate unload/delete
teardown and reentry, shared two-window identity, and obsolete callbacks.
Attachment/build counters prove idempotent setup and exactly one new pair after
each legitimate reentry. An integrated candidate-failure case proves the prior
cache stays dirty/unrenderable, notification and synchronous propagation occur,
and lifecycle retry swaps a complete new candidate.
Repeated real registered `BufEnter` callbacks also retain exactly one effective
build and attachment while the cache is clean; structural dirty state remains
the sole trigger for convergence rebuilding.

### 2026-07-12 — lifecycle shadow sweep and optimized report

Command: `make -f Makefile.parley perf` at production commit
`e2f6b88977f44f26c9afbbd5df564958c3f13c49` (the Task 7 evidence tests were
uncommitted and did not alter the default timed observer path). Environment:
macOS 26.5.1 (25F80), Neovim 0.11.7. The identical baseline protocol ran 5
warmups and 20 independent measured edits per size; elapsed values remain
report-only.

| phase | lines | median ms | p95 ms | ratio vs 100 | work: calls / lines / full / structure |
| --- | ---: | ---: | ---: | ---: | ---: |
| edit_total | 100 | 2.775437 | 3.796500 | 1.00x | 5 / 64 / 0 / 1 |
| edit_total | 1,000 | 2.642251 | 3.544458 | 0.95x | 5 / 88 / 0 / 1 |
| edit_total | 5,000 | 2.412917 | 3.763750 | 0.87x | 5 / 88 / 0 / 1 |
| timezone_refresh | 100 | 0.055542 | 0.142125 | 1.00x | 1 / 100 / 1 / 0 |
| timezone_refresh | 1,000 | 0.308146 | 0.341334 | 5.55x | 1 / 1,000 / 1 / 0 |
| timezone_refresh | 5,000 | 1.557896 | 1.768250 | 28.05x | 1 / 5,000 / 1 / 0 |
| footnote_refresh | 100 | 0.127021 | 0.201334 | 1.00x | 1 / 100 / 1 / 0 |
| footnote_refresh | 1,000 | 0.806667 | 0.888416 | 6.35x | 1 / 1,000 / 1 / 0 |
| footnote_refresh | 5,000 | 3.869667 | 4.147208 | 30.46x | 1 / 5,000 / 1 / 0 |
| decoration_redraw | 100 | 0.270729 | 0.364583 | 1.00x | 1 / 40 / 0 / 0 |
| decoration_redraw | 1,000 | 0.317126 | 0.365500 | 1.17x | 1 / 61 / 0 / 0 |
| decoration_redraw | 5,000 | 0.302271 | 0.344667 | 1.12x | 1 / 61 / 0 / 0 |
| spell_typeahead | 100 | 0.002062 | 0.011083 | 1.00x | 1 / 1 / 0 / 0 |
| spell_typeahead | 1,000 | 0.001146 | 0.017750 | 0.56x | 1 / 1 / 0 / 0 |
| spell_typeahead | 5,000 | 0.001188 | 0.022417 | 0.58x | 1 / 1 / 0 / 0 |

Exact baseline-versus-optimized elapsed comparison (milliseconds; baseline →
optimized) is: `edit_total` median/p95 100 `3.58/3.97 →
2.775437/3.796500`, 1,000 `6.06/8.51 → 2.642251/3.544458`, 5,000
`23.79/25.73 → 2.412917/3.763750`; `decoration_redraw` 100 `0.23/0.26
→ 0.270729/0.364583`, 1,000 `1.45/2.44 → 0.317126/0.365500`, 5,000
`8.08/8.23 → 0.302271/0.344667`; `timezone_refresh` 100 `0.03/0.12 →
0.055542/0.142125`, 1,000 `0.30/0.33 → 0.308146/0.341334`, 5,000
`1.64/1.89 → 1.557896/1.768250`; `footnote_refresh` 100 `0.12/0.19 →
0.127021/0.201334`, 1,000 `0.81/0.84 → 0.806667/0.888416`, 5,000
`3.89/3.95 → 3.869667/4.147208`; and `spell_typeahead` median/p95 100
`<0.01/0.04 → 0.002062/0.011083`, 1,000 `<0.01/0.03 →
0.001146/0.017750`, 5,000 `<0.01/0.02 → 0.001188/0.022417`.
The intended costs changed from baseline 5,000/100 median scaling of 6.64x to
0.87x for inclusive edits and 35.17x to 1.12x for redraws. Isolated diagnostic
refresh remains deliberately document-proportional off the keystroke path.

Immutable structural gates passed verbatim: diagnostic
`edit_total.full_buffer_reads == 0`; redraw
`decoration_redraw.full_buffer_reads == 0`; and 1,000-line
`lines_requested ==` 5,000-line `lines_requested` separately for `edit_total`
(`88 == 88`) and `decoration_redraw` (`61 == 61`). Structure work was exactly
one row at all sizes. Direct range assertions prove the `TextChangedI` structure
read is `[79,80)` plus the same-row spell read; a provider invocation performs
the exact sole call `[T,min(B+1+20,N))`. Therefore preceding-context reads are
zero (≤200), reasoning lookahead is zero (≤500/opener), and footer discovery
issues neither `0,-1` nor an equivalent full-span call (`ARCH-PURPOSE`).

Every lifecycle oracle now has its own exact named test. Named convergence
autocmd cases assert diagnostics before `nvim_exec_autocmds` returns; undo,
redo, external edit, stream/API-leg, scrolling, and second-window cases assert
the structure synchronously; separate `BufUnload`/`BufDelete` tests assert
cleared state plus invalid-buffer and obsolete-callback no-ops. The ten required
commands were executed individually and passed: `perf_harness_spec.lua` 8/8,
`line_reader_spec.lua` 8/8, `diagnostic_refresh_spec.lua` 3/3,
`buffer_lifecycle_spec.lua` 6/6, `highlight_structure_spec.lua` 9/9,
`perf_chat_typing_spec.lua` 12/12, integration
`diagnostic_refresh_spec.lua` 9/9, `highlighting_spec.lua` 44/44,
`chat_respond_spec.lua` 33/33, and `performance_line_reader_spec.lua` 4/4.
