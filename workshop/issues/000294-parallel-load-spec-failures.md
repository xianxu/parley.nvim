---
id: 000294
status: open
deps: []
github_issue:
created: 2026-09-27
updated: 2026-09-27
estimate_hours:
card_mirror: 'd38040370b8acf4b5380e28aecdd04bc523db90e' # card fields mirrored from issue-cards; edit via sdlc
---

# Heavy specs fail only under parallel make test (document_semantic, perf_document, document_fold_batches)

## Problem

`make test` runs each spec file in its own Neovim process, 8 in parallel (`JOBS=8`,
`Makefile.parley`). A rotating set of heavy specs fails in full runs and passes when run
alone, so a red `make test` can't be trusted and gets waved through:

- `tests/unit/document_semantic_spec.lua` — the Enter/join scaling corpus to 50,000 rows;
  already on the 180s deadline override (`tests/helpers/spec_runner.lua`). Failed in #293
  M2's full run with no assertion output, which suggests the deadline was hit.
- `tests/integration/perf_document_spec.lua` — failed in #293 M2's integration run.
- `tests/integration/document_fold_batches_spec.lua` — the 50,010-row fold document; also on
  the 180s override. Failed in #293 M3's integration run.
- Seen during #292/#293 on the same machine, and also passing alone:
  `document_dependencies_spec` (seeded oracle), `branch_child_spec`, `perf_ownership_spec`.

Each passes alone. Suspected causes, none verified:
- CPU contention: 8 heavy processes on one machine.
- LuaJIT `failed to allocate mcode memory` trace-flush thrash on arm64 macOS. #293 measured
  it as a random ~15x per-step slowdown in about 10% of processes, and it is most likely to
  hit exactly these long, JIT-heavy corpora.
- Perf specs asserting wall-clock bounds.

## Spec

- For each failing spec, capture a failing full-suite run with the cause: deadline kill
  (no assertion output) vs. assertion failure; wall time vs. its deadline; and the JIT
  profile (`jit.profile` VM states: J=compiler, N=compiled; see #293 Log for the probe).
- Classify each one: (a) needs a larger or budgeted deadline; (b) asserts wall time where
  it should assert work counters (#293's `Document.stats` budget pattern); (c) actually
  depends on how the specs are scheduled.
- Fix each at its class. Don't just raise `JOBS`-independent timeouts across the board.

## Done when

- Root cause per spec is in the Log, with evidence from a captured failing full run.
- `make test` passes 5 consecutive full runs on this machine with no reruns.

## Plan

- [ ] Instrument and capture failing full runs (per-spec wall time, kill vs assert, VM-state profile)
- [ ] Classify and fix per spec
- [ ] 5 consecutive green `make test`

## Log

### 2026-09-27
- Filed from #293's close (operator request); failure list from #292/#293 full runs.
