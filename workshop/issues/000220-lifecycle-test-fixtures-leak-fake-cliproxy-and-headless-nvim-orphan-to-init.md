---
id: 000220
status: working
deps: []
github_issue:
created: 2026-09-06
updated: 2026-09-19
estimate_hours:
started: 2026-09-19T17:59:42-07:00
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
      fixture that binds a port exits with its parent by construction; drop the
      opt-in `PARLEY_FAKE_EXIT_WITH_PARENT` flag everywhere it is named.
- [ ] M1 — one registry in `tests.helpers.fixture_process` (register on spawn,
      prune on exit, reap at `VimLeavePre`); collapse the eight spec-local
      copies onto it, the real-binary conformance spawn included (#237 BR-5).
- [ ] M2 — `scripts/reap-test-orphans.py`: a `ps`-based census of this
      checkout's surviving test processes, with a pure selector tested against
      a recorded process table.
- [ ] M2 — wire it into `Makefile.parley`: `--phase before` in `PREP_TEST_ENV`,
      `--phase after` folded into the exit code of every test target.
- [ ] M2 — `tests/arch/fixture_lifecycle_spec.lua`: guard the three invariants
      so a new fixture or spec inherits the reaping instead of remembering it.
- [ ] M2 — document the `ps`-based cleanup and the `pgrep` caveat in
      TOOLING.md; the layers in `atlas/infra/test_harness.md`; three rules in
      `workshop/lessons.md`.

**Closing needs a machine where `ps` is permitted** — an agent sandbox refuses
it with EPERM, and three of the four Done-when proofs need a real process table.
Every spec runs sandboxed (liveness is probed with `uv.kill(pid, 0)`).

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
