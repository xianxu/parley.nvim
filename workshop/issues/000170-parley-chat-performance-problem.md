---
id: 000170
status: working
deps: []
github_issue:
created: 2026-07-08
updated: 2026-07-11
estimate_hours:
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
buffer line-read calls and total lines requested by each observed phase. The
adapter used to gather counters must preserve production behavior and be tested
against a known sequence. These counters are correctness evidence and may fail
tests when a documented work bound is violated; only elapsed time remains
report-only. Output emphasizes scaling ratios as well as median/p95 latency.

The JSON report has a versioned stable envelope:
`schema_version`, `generated_at`, `environment` (OS, Neovim version, commit),
and `scenarios[]` containing name, line count, iteration count, raw elapsed
samples, median, p95, and work counters. By default `make perf` overwrites
`.test-tmp/perf/parley-chat-typing.json`; `PERF_OUTPUT=<path>` overrides it.
Generated reports are not committed. Baseline and optimized summaries—command,
environment, medians/p95s, scaling ratios, and work counters—are appended to
this issue's `## Log`, which is the durable comparison record.

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

The structural work contract is observable and independent of machine speed:

- `TextChangedI` may inspect the current line/word for spell typeahead but must
  request no document-wide line range;
- a redraw may read the visible rows, the existing 20-line viewport margin, at
  most 200 preceding context lines, and at most the existing 500-line reasoning
  lookahead per reasoning opener encountered inside that bounded region;
- managed-footer discovery during redraw must not request `0..-1` or otherwise
  scan all document lines; and
- increasing a fixture from 1,000 to 5,000 lines with the same viewport shape
  must not increase the combined keystroke/redraw line-read counter beyond a
  small fixed allowance for setup noise, defined by the harness and asserted in
  correctness tests.

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
- `InsertLeave`, normal-mode `TextChanged`, and `BufWritePost` synchronously
  rebuild both diagnostic sources before their autocmd returns.
- `BufEnter` and `WinEnter` synchronously hydrate diagnostics for the entered
  buffer/window.
- Scrolling or opening a second window recomputes correct highlights for that
  window's bounded viewport without requiring a text edit.
- Streaming/programmatic edits that emit normal `TextChanged` converge through
  that event; stream completion must leave diagnostics current even if an
  intermediate edit did not emit it.
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
- [ ] Remove full-buffer diagnostic work from `TextChangedI` and test every
      specified convergence trigger.
- [ ] Bound decoration-provider structural work and test scroll, multi-window,
      generation, and teardown behavior.
- [ ] Verify the complete lifecycle matrix and capture the optimized report on
      the baseline environment.
- [ ] Update tooling and atlas documentation with the benchmark and landed
      performance architecture.

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
