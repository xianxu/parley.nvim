---
id: 000220
status: working
deps: []
github_issue:
created: 2026-09-06
updated: 2026-09-19
estimate_hours: 5.98
started: 2026-09-19T17:59:42-07:00
flow: {kind: full, provenance: inferred}
---

# Lifecycle test fixtures leak: fake_cliproxy and headless nvim orphan to init

## Problem

The test suite leaks two kinds of process, both reparented to init (`ppid 1`),
and they accumulate across runs until the machine is unusable.

Measured on the operator's machine, 2026-09-06:

    load average: 584.95, 255.09, 117.45     (1-minute, and RISING)
    1563 total processes

    430 x Python  -> tests/fixtures/fake_cliproxy
    130 x nvim --headless -c set rtp+=... plenary.nvim | runtime plugin/plenary.vim

All dated 2026-09-01, five days before the measurement, so they survive
indefinitely once orphaned. The operator's symptom was visible keyboard lag while
typing and slow copy-paste — in a different repo's application entirely, because
the cost is machine-wide.

Killing them dropped the process count 1563 -> 1091.

**`fake_cliproxy` is a good fixture and that is the point.** Its own docstring
says why it exists — "a real subprocess speaking the `/v1/models` identity
protocol parley probes, so the lifecycle tests exercise spawn / health-probe /
reuse against an actual HTTP server rather than function mocks". That is the
right call. A fixture that models an external service by BEING a process just
has to be reaped like one, and the leak is in the reaping, not in the choice.

**`pgrep -f` cannot see them, which is why a cleanup looks complete when it is
not.** On this macOS:

    pgrep -fc fake_cliproxy        -> 0
    ps -Ao args= | grep -c '[f]ake_cliproxy'  -> 91

So the obvious cleanup command silently no-ops, and 89 orphans survived a
`pkill -f` sweep that appeared to succeed. Any documented remedy has to use `ps`
rather than `pgrep`.

## Spec

Two halves, and the second is what stops it recurring.

1. **Reap what the tests spawn.** Every fixture process needs an owner that
   outlives the assertion and kills it — a `finally`/teardown that terminates the
   child, and a suite-level sweep for the case where the harness itself dies. A
   test that fails or is interrupted mid-run is the common case, not the rare
   one: 430 orphans is what "the busted run was Ctrl-C'd" looks like accumulated
   over a few days.

2. **Fail loudly when it happens anyway.** The suite should count its own
   surviving children at exit and report a non-zero count as a failure. A leak
   nothing measures is a leak nobody sees until a machine is at load 585 —
   which is how this was found, five days late, by someone debugging unrelated
   keyboard lag.

Worth deciding while here: whether the headless-nvim harness leak has the same
cause or a different one. They appeared together and in similar proportion
(~3 Python per nvim), which suggests one harness leaking both, but that is an
inference from the counts rather than something measured.

## Done when

- A full test run leaves zero `fake_cliproxy` and zero harness `nvim --headless`
  processes behind, verified with `ps` rather than `pgrep`.
- An INTERRUPTED run (Ctrl-C, or a killed harness) also leaves none, since that
  is the case that produced these.
- The suite reports surviving children at exit, and a non-zero count fails.
- The cleanup command in `TOOLING.md` uses `ps`, with a note that `pgrep -f`
  does not match these on macOS.

## Plan

Durable design: `workshop/plans/000220-reap-test-fixture-processes-plan.md`
(three reaping layers, each at the chokepoint its class of process passes
through, plus one `ps`-based census that fails the suite).

- [ ] M1 — the shared orphan rule in both watchdogs: `ppid == 1` OR a changed
      parent, plus a Lua twin of `fixture_watchdog.py` installed from
      `tests/minimal_init.vim`, which every harness Neovim loads.
- [ ] M1 — move the watchdog into `LoopbackHTTPServer.__init__`, so every
      fixture that binds a port exits with its parent by construction; add the
      direct call to the two fixtures that block WITHOUT binding
      (`fake_cliproxy`'s `run_login`, `fake_sips` slow mode); drop the opt-in
      `PARLEY_FAKE_EXIT_WITH_PARENT` flag everywhere it is named.
- [ ] M1 — one registry in `tests.helpers.fixture_process` (register on spawn,
      prune on exit, `mark()`/`reap({since})` so a file-scope server survives a
      per-case reap, `VimLeavePre` backstop); collapse the eight spec-local
      copies onto it, the real-binary conformance spawn included (#237 BR-5).
- [ ] M2 — `scripts/reap-test-orphans.py`: a `ps`-based census of this
      checkout's surviving test processes, with a pure selector tested against
      a recorded process table.
- [ ] M2 — wire it into `Makefile.parley`: `--phase before` in `PREP_TEST_ENV`,
      `--phase after` folded into the exit code of every test target.
- [ ] M2 — document the `ps`-based cleanup and the `pgrep` caveat in
      TOOLING.md; the layers in `atlas/infra/test_harness.md`; three rules in
      `workshop/lessons.md`.
- [ ] M2 — `tests/arch/fixture_lifecycle_spec.lua`: guard the four invariants
      (seam, watchdog reach, the `ppid == 1` rule in both copies, and TOOLING's
      remedy) so a new fixture or spec inherits the reaping instead of
      remembering it.

**Closing needs a machine where `ps` is permitted** — an agent sandbox refuses
it with EPERM, and three of the four Done-when proofs need a real process table.
Every spec runs sandboxed (liveness is probed with `uv.kill(pid, 0)`).

## Estimate

Derived Method A (primitive decomposition) against
`estimate-logic-v3.1.md` / `baseline-v3.1.md`: v2.1 design hours kept as-is,
`impl=` written at **40%** of the v2 primitive-table implementation hours.

Per v2's own rule — "a primitive with a thorough plan doc has ~0 design cost,
decisions pre-resolved" — the design column is concentrated in the two design
primitives, which is where the decisions were actually resolved this window.
The remaining rows carry only the decisions their own step still holds.

**Multiplicity is declared** (`×n`), because five rows aggregate more than one
instance of their primitive and an undeclared aggregate cannot be audited
against the v2 table's per-primitive ceiling.

| primitive | what it covers | design | v2 impl | ×n | v2 impl total | impl ×0.4 |
|---|---|---|---|---|---|---|
| `issue-spec` | root-cause (two causes, chained) + the durable plan + 3 plan-review rounds | 1.0 | 0.3 | ×1 | 0.3 | 0.12 |
| `typed-data-prototype` | the two live prototypes — the `orphan.sh` fixture repro and its nvim twin — that found the load-bearing `ppid == 1` defect | 0.6 | 0.3 | ×1 | 0.3 | 0.12 |
| `lua-neovim` | `exit_with_parent.lua`, the `fixture_process` registry, and the 4-invariant arch guard with its counterfactuals | 0.4 | 1.5 | ×2 | 3.0 | 1.20 |
| `greenfield-go-module` | `reap-test-orphans.py` — greenfield, single concern, pure core + injected `ps` seam (shape, not language) | 0.2 | 0.6 | ×1 | 0.6 | 0.24 |
| `smaller-go-module` | the five fixture edits, the Makefile gate wiring, **and the real-machine verification loops** — full-suite runs, the interrupted-run proof, four counterfactual cycles | 0.0 | 0.5 | ×3 | 1.5 | 0.60 |
| `cross-cutting-refactor` | the eight-spec sweep onto the seam (#237 BR-5), one edit→run→commit cycle each | 0.2 | 0.5 | ×2 | 1.0 | 0.40 |
| `atlas-docs` | TOOLING.md, `atlas/infra/test_harness.md`, `lessons.md`, `traceability.yaml` | 0.05 | 0.2 | ×1 | 0.2 | 0.08 |
| `milestone-review` | two boundaries (M1, M2) and the fix rounds they generate | 0.0 | 0.5 | ×2 | 1.0 | 0.40 |

`design-buffer: 0.15` — the issue has a thorough plan doc (v3.1 step 4).
`familiarity: 1.0` — this repo's harness, and #237 built the pieces being reused.

Σdesign 2.45 × 1.15 = 2.8175; Σimpl 3.16 × 1.0 = 3.16; total 5.98.

**Sanity check against the closest analogue.** `#237` — same subsystem, same
harness, thorough plan, and the issue that *built* `fixture_watchdog.py` —
estimated design 2.40 / impl 3.00 and actualized 7.20 h (ratio 0.80). This work
is comparable or larger (7 tasks, ~50 steps, 8 spec migrations, a new Python
module, Makefile wiring, an arch guard, three docs), so an impl column below
#237's would have needed a reason and there isn't one. 3.16 sits just above it.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
design-buffer: 0.15
item: issue-spec             design=1.0  impl=0.12
item: typed-data-prototype   design=0.6  impl=0.12
item: lua-neovim             design=0.4  impl=1.20
item: greenfield-go-module   design=0.2  impl=0.24
item: smaller-go-module      design=0.0  impl=0.60
item: cross-cutting-refactor design=0.2  impl=0.40
item: atlas-docs             design=0.05 impl=0.08
item: milestone-review       design=0.0  impl=0.40
total: 5.98
```

*Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against `baseline-v3.1.md`. Method A only.*

### Revisions

**2026-09-19** — raised 4.90 → 5.98 after the estimate-quality judge (INFO, not
blocking) showed the impl column was light against this repo's own ledger. Four
changes, all in the judge's direction: the two live prototypes got their own
`typed-data-prototype` row instead of hiding inside `issue-spec`'s design
maximum; the eight-spec sweep went ×1 → ×2 (eight edit→run→commit cycles, not
one); the real-machine verification loops got named coverage instead of hiding
in the Makefile row; and every aggregate row now declares its `×n` so it can be
checked against the v2 ceiling. Banked as filed it would have read as a 20%
under-estimate in the calibration ledger.

## Log

### 2026-09-06

Found from outside the repo: the operator reported keyboard lag and slow
copy-paste in `pair`, and the cause was 560 orphaned processes from this suite
competing for the machine. Nothing in `pair` was at fault — `couch` measured
0.4% CPU throughout.

Reliable cleanup, since `pgrep -f` misses them:

    ps -Ao pid=,args= | grep '[f]ake_cliproxy' | awk '{print $1}' | xargs kill
    ps -Ao pid=,args= | grep '[n]vim --headless' | awk '{print $1}' | xargs kill

### 2026-09-11

RECURRED, five days later. Found the same way — from outside the repo, by an
operator who noticed the laptop fan, not by anything in the suite. Measured and
swept:

    897 x fake_cliproxy  (ppid 1)   9847 MB RSS   ~18-23h old
    145 x nvim --headless (ppid 1)  1192 MB RSS   up to 2 days old

**The cost is memory, not CPU**, which is why nobody sees it until the machine
swaps. Every one of those processes was idle: the nvim orphans had burned
0.05 s of CPU EACH, so they wedged at startup and never ran a spec. The machine
was 89% idle with 1042 orphans resident. After the sweep:

    PhysMem   84G used / 11G unused  ->  78G used / 17G unused
    compressor         15G           ->  11G
    load avg (1-min)   8.46          ->  3.95
    processes          2311          ->  1262

So state the symptom as ~11 GB held and the compressor working, not as load
average. 2026-09-06's load-585 reading was a machine already deep in swap.

On the Spec's open question (one harness leaking both, or two causes): still not
answered, and the ratio moved — 430:130 (3.3:1) then, 897:145 (6.2:1) now. Both
kinds appear together both times, so a common trigger remains the better guess,
but the proportion is not fixed and should not be leaned on.

New datum for the second half of the Spec: all 145 nvim orphans trace to
throwaway review worktrees — 107 from `/private/tmp/claude-501/rv224` alone, the
rest spread over ~10 more (`rev224`, `parley-rev`, `br227r3`, `p205-review`, …).
These are killed review agents, which makes the interrupted run the DOMINANT
case, not merely the common one. A teardown that only runs on the normal path
cannot fix this; the suite-level sweep is the load-bearing half.

The `pgrep` caveat still holds on this macOS, re-tested today:
`pgrep -fc plenary.busted` matched nothing while `ps` found 145.

### 2026-09-12 — datum from #237 (verification runs and four boundary reviews)

- **Red and failing runs orphan the plenary child.** A spec that errors at load
  (a fresh worktree has no `construct/vocabulary`), or a conformance run with
  failing cases, leaves its `plenary.busted` child nvim alive under init, and
  that child keeps its fixture alive: the fixture's watchdog cannot fire while
  its parent lives. 13 were stopped today, 11 in one sweep: at least five from
  #237's review agents' `git archive` copies
  (`/private/tmp/claude-501/parley-scratch-237*`), the rest from red and
  conformance runs.
- **`cliproxy_catalog_spec` orphans three `fake_cliproxy` on every run**: bare
  `uv.spawn(FAKE, { args = { "--port", … } })` at lines 19, 360 and 441, without
  `PARLEY_FAKE_EXIT_WITH_PARENT`. Seen after every full run today. The same bare
  spawn is in `cliproxy_lifecycle_spec` (21, 612, 707, 817),
  `cliproxy_dispatch_spec` (27), `cliproxy_caller_teardown_spec` (36) and
  `cliproxy_recovery_e2e_spec` (35).
- **Order dependence:** `cliproxy_recovery_e2e_spec` fails 4/5 in a fresh test
  env until `$XDG_CACHE_HOME/nvim/parley/query` exists; another spec creates it.
- Pieces #237 added that a fix can reuse: `tests/fixtures/fixture_watchdog.py`
  (parent-death exit), the spec-local `spawned`/`reap()` registry in
  `cliproxy_update_spec` (its consolidation was deferred here by #237's review,
  BR-5), and `tests/helpers/await.lua`.

### 2026-09-19 — measured, and the Spec's open question answered

Current state on this machine before any fix: 12 `fake_cliproxy` and 13
`nvim --headless`, all `ppid 1`, oldest two days. Two orphan shapes among the
Neovims — with and without `-u tests/minimal_init.vim` — the second predating
#261 M5, which is when spec children began loading the init.

**The Spec asked whether one harness leaks both, or two causes. Two, in a
chain.** Each half has its own sufficient cause:

- the fixtures, because parent-death exit was **opt-in**
  (`PARLEY_FAKE_EXIT_WITH_PARENT`) and only 2 of 8 `fake_cliproxy` spawn sites
  set it; `fake_sse_server` never called it at all;
- the Neovims, because **`nvim --headless` treats SIGINT as an interrupt, not as
  an exit**, so a Ctrl-C'd `make` leaves the parent and every plenary spec child
  running.

They appear together because a surviving spec-child Neovim is a *live parent*:
the fixture watchdog cannot fire while the Neovim that spawned it is alive. That
also explains why the ratio moved (3.3:1 → 6.2:1) without either cause changing
— it is just how many fixtures each wedged child was holding.

**A second, independent defect, found by prototype and load-bearing.**
`fixture_watchdog.py` exits when `os.getppid()` *differs from the value it
sampled at startup*. A process orphaned **while it is still booting** — which is
exactly what a killed harness produces — samples `1` as its own starting parent,
so the rule never fires. Reproduced directly:

    orphan.sh pidfile tests/fixtures/fake_cliproxy --port 45997   # with
    PARLEY_FAKE_EXIT_WITH_PARENT=1, parent exits immediately
    -> STILL ALIVE at t=4s

The same script under `ppid == 1 or ppid != parent` exits within 1s. An nvim
prototype behaved identically: survived indefinitely under the change-only rule,
gone in under a second under the corrected one. So the watchdog that has been in
the tree since #237 looked correct and could not fire for the dominant case.

Design: `workshop/plans/000220-reap-test-fixture-processes-plan.md`.
