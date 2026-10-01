---
id: 000294
status: working
deps: []
github_issue:
created: 2026-09-27
updated: 2026-10-01
estimate_hours:
card_mirror: '8eea3c81cb821f1fb147f1e7a42d0be192d7ce38' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-01T14:36:23-07:00
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

- [x] Instrument (per-spec wall time, named deadline kill, VM-state profile) — ba0a5ea0
- [ ] Capture failing full runs
- [ ] Classify and fix per spec
- [ ] 5 consecutive green `make test`

## Log

### 2026-09-27
- Filed from #293's close (operator request); failure list from #292/#293 full runs.

### 2026-10-01
- `make test` overrides `PlenaryBustedFile` → `spec_runner.run` → plenary
  `test_directory` with one path, so every spec runs in a child under a deadline:
  plenary's default 50s, or 180s for the four 50k-row corpora in `spec_runner.lua`.
- A deadline kill was silent: plenary SIGTERMs the child and prints nothing
  (`plenary/test_harness.lua:139`), which is the "failed with no assertion
  output" seen in #293. Fixed in ba0a5ea0: the runner prints `DEADLINE: …`.
- Alone, on this machine: `perf_document_spec` 17–31s against **50s** (it is not
  on the 180s list, though it runs all 28 scenarios up to 50,000 rows; its
  assertions are already work counters, not wall time); `document_fold_batches`
  46s/180s; `document_semantic` 20s/180s.
- Instrumentation (ba0a5ea0): PASS/FAIL lines carry wall time;
  `PARLEY_TEST_JITSTAT=1` adds `tests/helpers/jit_watch.lua` (VM-state samples
  via `jit.profile`, trace flushes via `jit.attach`), written from the profiler
  callback so a killed child still reports. `perf_document` alone: ~50% GC,
  ~10% compiler, 42 trace flushes in 17s.
- Full run 1 also fails two arch specs, deterministically and not from load:
  `buffer_mutation_spec` (#304's `spell_source.lua:61` writes with
  `nvim_buf_set_text` outside the #254 boundary — on origin/main) and
  `single_source_sweeps_spec` (local `main` ref is stale at c1b2173e, behind
  origin/main a0930763, so `git merge-base HEAD main` reads #309's entities as
  this issue's). Out of #294's class; they still block "5 green runs".
- Runs 1–3 (2026-10-01, JOBS=8): run 1 killed `perf_ownership_spec` at 50s
  (21s alone; it runs its work in 4 sequential grandchild nvims, so the child
  sits in C and its own JIT profile shows nothing). Run 2: no load failures,
  but `document_fold_retirement` took 87s vs 17s in run 1 — a 5x swing.
  Run 3 overlapped another session's sharded ariadne `sdlc` Go tests (load
  average 72 on this machine): `cliproxy_auth_login` (assert at :418, a 6s
  `vim.wait` on a fixture-process round trip), `cliproxy_lifecycle` and
  `cliproxy_update` (50s deadline kills, child idle in C, no JIT activity).
- Harness gaps found: the make parent's JIT line can be the last one printed and
  hide the child's; grandchild nvims' JIT lines land in output the spec captures.
- With grandchild JIT lines routed to make (PARLEY_TEST_JITSTAT_LOG), a lone
  `perf_ownership` run (27s, no other load from this suite) shows every
  grandchild thrashing: J (compiler) 47–87% of samples; flushes 88, 844, 2856
  (the 22s `chat_typing.start` probe) and 20,727 in a 1s `probe(100)`. That is
  #293's mcode-allocation loop, deterministic here, not ~10%. The chat_typing
  probe alone: 22.5s JIT on, 14.3s `jit.off()`, 22.3s with
  `maxmcode=65536,maxtrace=8000` (confirms the lessons.md note). LuaJIT
  2.1.1741730670, nvim 0.11.7, arm64 macOS.
