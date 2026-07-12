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

The first scenario creates normally attached Parley chat buffers at 100, 1,000,
and 5,000 lines, positions a real window deep in the document, performs a
representative insert edit, and drives the same Neovim event/redraw seams used
interactively. It reports the combined edit path and separately attributable
phases: `TextChangedI`, timezone refresh, managed-footnote refresh, chat
decoration/redraw computation, and spell typeahead. Output emphasizes scaling
ratios as well as median/p95 latency.

The existing `tests/perf_chat_finder.lua` remains supported. It may migrate to
the shared timing/reporting core only if that is a small behavior-preserving
change; migration is not required to complete #170.

### Optimization boundary

Use the baseline to confirm which Parley phases scale with document size before
changing production behavior. Then:

- remove complete timezone and managed-footnote diagnostic rebuilding from the
  synchronous `TextChangedI` path; these diagnostics may converge on a deferred
  or structural event, but ordinary typing must do only bounded bookkeeping;
- make chat and Markdown decoration computation genuinely viewport-bounded,
  including managed-footer discovery;
- replace the highlighter's potentially unbounded backward bootstrap with a
  bounded or conservatively invalidated structural-state lookup; and
- keep submission-time chat parsing and the live streaming exchange model as
  the authoritative semantic structures rather than introducing a new
  continuously maintained exchange model.

Prefer one shared invalidation/deferred-refresh mechanism for Parley diagnostics
and highlight state (`ARCH-DRY`). Keep structural scanning/state transitions as
pure functions and Neovim events, timers, buffers, and redraw callbacks as thin
adapters (`ARCH-PURE`). If cached state cannot be proven valid, schedule a
conservative recomputation outside the immediate keystroke callback rather than
display silently stale semantics. Optimize the measured typing path, not a
speculative parser architecture (`ARCH-PURPOSE`).

### Behavior and lifecycle requirements

Optimization must preserve:

- timezone and managed-footnote diagnostics after their documented convergence
  event;
- managed-footnote, reasoning, code, tool, question, and answer highlighting;
- correct highlighting after scrolling, multiple windows, streaming, undo/redo,
  external buffer edits, buffer enter/leave, write, unload, and deletion;
- bounded cleanup of timers/caches on buffer teardown; and
- unchanged chat submission, recursion, and exchange-model semantics.

No performance cache may be keyed only by buffer number without lifecycle
cleanup. No delayed callback may mutate an invalid buffer or apply an obsolete
generation.

### Verification

Add pure tests for timing statistics/report shaping and any extracted
structural-state/invalidation logic. Add integration tests through real Neovim
buffers for event wiring, deferred convergence, viewport/scroll correctness,
multiple windows, streaming, undo/redo, external edits, and teardown.

Run the report-only benchmark before and after implementation at all three
document sizes. The optimized report must show that the synchronous
Parley-owned keystroke path no longer performs document-wide diagnostic scans
and that redraw work is bounded by viewport/context rather than total document
length. Record results and environment metadata in `## Log`; do not convert the
observed numbers into a CI threshold in this issue.

## Done when

- `make perf` runs reusable headless-Neovim scenarios and emits terminal plus
  JSON reports without timing-based pass/fail gates.
- A committed/logged baseline identifies the Parley-owned costs at
  100/1,000/5,000 lines before production optimization.
- Ordinary insert-mode changes do not synchronously rebuild full-buffer timezone
  or managed-footnote diagnostics.
- Chat/Markdown redraw computation does not read or scan the entire document
  merely to render a bounded viewport.
- Highlight and diagnostic behavior converges correctly across scrolling,
  multiple windows, streaming, undo/redo, external edits, writes, and teardown.
- Before/after reports show the intended scaling improvement, and the complete
  correctness/lint suite passes.

## Plan

- [ ] Build the reusable report-only headless performance framework and capture
      the baseline.
- [ ] Remove full-buffer diagnostic work from the synchronous keystroke path.
- [ ] Bound decoration-provider structural work and cache/invalidate safely.
- [ ] Verify lifecycle/correctness behavior and capture the optimized report.
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
