---
id: 000220
status: working
deps: []
github_issue:
created: 2026-09-06
updated: 2026-09-19
estimate_hours: 8.71
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

- [x] M1 — the shared orphan rule in both watchdogs: `ppid == 1` OR a changed
      parent, plus a Lua twin of `fixture_watchdog.py` installed from
      `tests/minimal_init.vim`, which every harness Neovim loads.
- [x] M1 — move the watchdog into `LoopbackHTTPServer.__init__`, so every
      fixture that binds a port exits with its parent by construction; add the
      direct call to the two fixtures that block WITHOUT binding
      (`fake_cliproxy`'s `run_login`, `fake_sips` slow mode); drop the opt-in
      `PARLEY_FAKE_EXIT_WITH_PARENT` flag everywhere it is named.
- [x] M1 — one registry in `tests.helpers.fixture_process` (register on spawn,
      prune on exit, `mark()`/`reap({since})` so a file-scope server survives a
      per-case reap, `VimLeavePre` backstop); collapse the eight spec-local
      copies onto it, the real-binary conformance spawn included (#237 BR-5).
- [x] M1 — `scripts/reap-test-orphans.py`: a `ps`-based census of this
      checkout's surviving test processes, with a pure selector tested against
      a recorded process table. In M1, not M2: `single_source_sweeps_spec`'s
      plan-entity guard reads the whole plan's Core-concepts table, so leaving
      `select_orphans`/`ancestry` for M2 makes that guard red at M1's boundary
      (measured).
- [ ] M2 — wire it into `Makefile.parley`: `--phase before` in `PREP_TEST_ENV`,
      `--phase after` folded into the exit code of every test target.
- [ ] M2 — document the `ps`-based cleanup and the `pgrep` caveat in
      TOOLING.md; the layers in `atlas/infra/test_harness.md`; three rules in
      `workshop/lessons.md`.
- [ ] M2 — `tests/arch/fixture_lifecycle_spec.lua`: guard the four invariants
      (seam, watchdog reach, the `ppid == 1` rule in both copies, and TOOLING's
      remedy) so a new fixture or spec inherits the reaping instead of
      remembering it.

- [ ] AT CLOSE — flip this issue's ledger row to `window_trusted=no`. `sdlc close`
      appends it as `yes` (`close.go:940` derives the flag from `started:` being
      set, which it is), but the window is wrong in the other direction. Operator
      decision 2026-09-19: exclude #220 from calibration. Recorded in
      `brain/data/life/42shots/velocity/calibration-findings.md` → "Excluded rows".

**Closing needs a machine where `ps` is permitted** — an agent sandbox refuses
it with EPERM, and three of the four Done-when proofs need a real process table.
Every spec runs sandboxed (liveness is probed with `uv.kill(pid, 0)`).

## Estimate

Derived Method A (primitive decomposition) against
`estimate-logic-v3.1.md` / `baseline-v3.1.md`: v2.1 design hours kept as-is,
`impl=` written at **40%** of the v2 primitive-table implementation hours.

Per v2's own rule — "a primitive with a thorough plan doc has ~0 design cost,
decisions pre-resolved" — the design column is concentrated in the two design
primitives, which is where the decisions were actually resolved. The remaining
rows carry only the decisions their own step still holds.

**Multiplicity is declared** (`×n`), because most rows aggregate more than one
instance of their primitive and an undeclared aggregate cannot be audited
against the v2 table's per-primitive ceiling. `×n` counts instances **of the
primitive** — a unit of the size the v2 table describes, not the smallest thing
the coverage sentence names — and any wall-clock gross-up is stated separately in
the row. (r2 said "the number of instances the row's own coverage names", which
read literally makes the eight-spec sweep eight *multi-file renames*; it is not.)

| primitive | what it covers | design | v2 impl | ×n | v2 impl total | impl ×0.4 |
|---|---|---|---|---|---|---|
| `issue-spec` | root-cause (two causes, chained) + the durable plan + its review rounds | 1.0 | 0.3 | ×1 | 0.3 | 0.12 |
| `typed-data-prototype` | two genuinely separate prototypes — the `orphan.sh` fixture repro and its nvim twin — that found the load-bearing `ppid == 1` defect | 0.6 | 0.3 | ×2 | 0.6 | 0.24 |
| `lua-neovim` | three artifacts: `exit_with_parent.lua`, the `fixture_process` registry, the 4-invariant arch guard with its counterfactuals | 0.4 | 1.5 | ×3 | 4.5 | 1.80 |
| `greenfield-go-module` | `reap-test-orphans.py` — greenfield, single concern, pure core + injected `ps` seam (shape, not language) | 0.2 | 0.6 | ×1 | 0.6 | 0.24 |
| `smaller-go-module` | three instances (five fixture edits, the Makefile gate, the traceability routing) **plus the real-machine verification loops grossed up ×2** — see the unit note below | 0.0 | 0.5 | ×5 | 2.5 | 1.00 |
| `cross-cutting-refactor` | the eight-spec sweep onto the seam (#237 BR-5) — ~2 specs per multi-file-rename instance, plus the eight edit→run→commit cycles grossed up inside it | 0.2 | 0.5 | ×4 | 2.0 | 0.80 |
| `atlas-docs` | four documents: TOOLING.md, `atlas/infra/test_harness.md`, `lessons.md`, `traceability.yaml` | 0.2 | 0.2 | ×4 | 0.8 | 0.32 |
| `milestone-review` | two boundaries (M1, M2) and the fix round each generates, grossed up ×1.5 — a fresh-context review is measured wall-clock too (see the unit note) | 0.0 | 0.5 | ×6 | 3.0 | 1.20 |

`design-buffer: 0.15` — the issue has a thorough plan doc (v3.1 step 4).
`familiarity: 1.0` — this repo's harness, and #237 built the pieces being reused.

Σdesign 2.60 × 1.15 = 2.99; Σimpl 5.72 × 1.0 = 5.72; total 8.71.

**Unit note on the verification rows.** v3.1's ×0.40 is calibrated on
AI-autonomous implementation, which compresses. Three items here do not: a full
`make test` run, the interrupted-run proof, and four counterfactual cycles are
wall-clock-bound on a suite whose defining property is that its runs are long —
and this issue exists because they also get interrupted. They are grossed up
inside `smaller-go-module` (the `×2` above the three primitive instances) so
that the ×0.4 that follows returns them to roughly their real wall-clock. The same
argument applies to `milestone-review`: post-#118 `sdlc actual` counts subagent
execution spans as elapsed, so a fresh-context boundary review over this diff is
measured wall-clock by exactly the same logic — #237's log records four such
reviews, long enough that their own agents were leaking orphans. Withholding the
gross-up there while applying it to `make test` was inconsistent.

**Sanity check, against the analogue's ACTUAL.** `#237` — same subsystem, same
harness, thorough plan, and the issue that *built* `fixture_watchdog.py` —
estimated 5.76 and **actualized 7.20 h** (ratio 0.80). This work is comparable or
larger (7 tasks, ~50 steps, 8 spec migrations, a new Python module, Makefile
wiring, an arch guard, four docs), so #237's 7.20 is the floor rather than the
ceiling. 8.71 sits above it, which is where a larger scope should sit. The first two derivations compared against
#237's *estimate*, which is the wrong side of that row.

**What this estimate deliberately does NOT do.** Recent v3.1 rows in this repo
cluster at ratio 0.5–0.7 (#247 0.35, #263 0.47, #262 0.53, #240 0.66, #266 0.67),
and `baseline-v3.1.md`'s own open question 3 names that low-side bias. Correcting
for it *per issue* would be back-fitting: it would make each row look calibrated
while destroying the signal the ledger exists to carry. The bias belongs to the
model, and recalibration is tracked in ariadne#127.

**Caveat on the actual this will be compared against.** `sdlc actual --issue 220`
already reads 5.95 h with no implementation written, because the window anchors at
`7353d798` — the **issue-creation** commit of 2026-09-06, not the 2026-09-19
claim. It therefore spans 13 days and 87 attributed issues, with mention-fallback
warnings throughout. AGENTS.md §2 says claiming early "anchors the active-time
window at the claim commit"; this window did not. Read this row's ratio with that
mind — and by operator decision on 2026-09-19 it **is** excluded: this row's
`window_trusted` is to be set to `no` after close. `sdlc close` cannot be told
that (it derives the flag from `started:` alone, `close.go:940`), so it is a
manual step, listed in `## Plan` and recorded in
`brain/data/life/42shots/velocity/calibration-findings.md` → "Excluded rows".

The flag is being used slightly off-label: its documented meaning is a legacy
window that **truncates** design time, so the actual reads low. Here the actual
reads high. Same conclusion, opposite cause.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
design-buffer: 0.15
item: issue-spec             design=1.0  impl=0.12
item: typed-data-prototype   design=0.6  impl=0.24
item: lua-neovim             design=0.4  impl=1.80
item: greenfield-go-module   design=0.2  impl=0.24
item: smaller-go-module      design=0.0  impl=1.00
item: cross-cutting-refactor design=0.2  impl=0.80
item: atlas-docs             design=0.2  impl=0.32
item: milestone-review       design=0.0  impl=1.20
total: 8.71
```

*Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against `baseline-v3.1.md`. Method A only.*

### Revisions

**2026-09-19 (r1)** — 4.90 → 5.98. The estimate-quality judge (INFO) showed the
impl column was light. Gave the two live prototypes their own
`typed-data-prototype` row; took the eight-spec sweep ×1 → ×2; named the
verification loops; declared `×n` on aggregate rows.

**2026-09-19 (r2)** — 5.98 → 7.79. Second judge pass found the r1 arithmetic
still understated: `lua-neovim ×2` named *three* artifacts (→ ×3) and
`atlas-docs ×1` named *four* documents (→ ×4); the verification loops were still
being scaled by 0.4 though they are wall-clock-bound and do not compress
(→ grossed up); and the #237 sanity check compared estimate-to-estimate rather
than to #237's 7.20 h actual. Not applied: the repo-wide 0.5–0.7 ratio drift,
which is the model's to fix, not an individual estimate's.

**2026-09-19 (r3)** — 7.79 → 8.71. Third judge pass found the r2 rules applied
unevenly to two more rows: `typed-data-prototype` named two prototypes at ×1 and
`cross-cutting-refactor` named eight spec cycles at ×2, and the wall-clock
gross-up was given to `make test` but withheld from the boundary reviews, which
post-#118 `sdlc actual` measures the same way. Also tightened what `×n` means, so
"instances the coverage names" can no longer be read as eight multi-file renames.

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

### 2026-09-19 — M1 in progress: two of four plan items landed

Branch `000220-…`. Both delivered items are green and verified against real
processes, not mocks; liveness is probed with `uv.kill(pid, 0)` (ESRCH), never
`ps`, so every spec passes inside an agent sandbox.

**Landed — `e130ed9d` the shared orphan rule.** The rule both watchdogs used was
"ppid differs from the value sampled at startup". A process orphaned *while it is
still booting* samples `1` as its own starting parent, so the rule never fired for
the case that produces these. Measured on `fake_cliproxy` with the flag that was
supposed to enable it:

    PARLEY_FAKE_EXIT_WITH_PARENT=1, parent exits at once
      ppid != parent            → STILL ALIVE at t=4s
      ppid == 1 or ppid != parent → GONE by t=3s

`tests/helpers/exit_with_parent.lua` is the Neovim twin, installed from
`tests/minimal_init.vim` — the one file the `make` parent and every plenary spec
child both load. It exits with `os.exit` (the loop may be wedged: the measured
orphans had each burned 0.05 s of CPU and never run a spec), which skips
`VimLeavePre`, so the per-process `$PARLEY_QUERY_DIR` cleanup is handed to it as a
`before_exit` hook rather than being stranded.

**Landed — `32da1528` the chokepoint.** `LoopbackHTTPServer.__init__` installs the
watchdog, so every fixture server inherits it by construction and
`PARLEY_FAKE_EXIT_WITH_PARENT` is gone from the tree. The constructor is *not* the
whole rule: `run_login` (`hangs`, 300 s) and `fake_sips` (`slow`, 30 s) block
without ever binding, and each calls the watchdog itself. Regression list derived
by grep over the changed fixtures rather than typed — 17 specs, all pass, and
`image_shrink_spec`'s "kills a real slow child" case (which asserts a `[4.5, 8)` s
window against `fake_sips slow`) genuinely ran rather than pending.

**Side-quest, in `e130ed9d`.** `single_source_sweeps_spec`'s `definition_pattern`
was Lua-only, so a Core-concepts row naming `LoopbackHTTPServer` read as "exists
nowhere in the tree" though it has been a Python class since #202. `tests/fixtures`
is real code here; the matcher now covers `def`/`class` too.

**Milestone boundary moved, and a test is why.** That same guard reads the *whole*
plan's Core-concepts table on any issue branch. With the census in M2,
`select_orphans` and `ancestry` do not exist at M1's boundary and the guard is red
— measured, not predicted. A boundary a guard cannot be green at is not a boundary,
so the census moved into M1: M1 is now everything that exists as a *thing*
(Tasks 1–4), M2 is wiring, docs and the guard (Tasks 5–7).

**Estimate took three judge rounds** (4.90 → 5.98 → 7.79 → 8.71). Each round found
my own declared `×n` rule applied unevenly — prototypes counted ×1 while naming
two, docs ×1 while naming four, and the wall-clock gross-up given to `make test`
but withheld from boundary reviews that post-#118 `sdlc actual` measures the same
way. See `## Estimate` → Revisions.

**Measurement caveat worth carrying to close.** `sdlc actual --issue 220` anchors
its window at `7353d798` — the **issue-creation** commit of 2026-09-06, not the
2026-09-19 claim — so it already read 5.95 h before a line of implementation
existed, across 13 days and 87 attributed issues with mention-fallback warnings
throughout. AGENTS.md §2 says claiming early "anchors the active-time window at the
claim commit"; this window did not. This row's ratio should be read with that in
mind, or excluded from the calibration fit.

**Next:** Task 3 (the `fixture_process` registry + the eight-spec sweep), then
Task 4 (the census), then M1 close.

### 2026-09-19 — M1 item 3: one registry, eight specs collapsed onto it

`tests.helpers.fixture_process` now registers every process it starts, prunes it
on exit, reaps at `VimLeavePre`, and exposes `mark()` / `reap({since, signal})`.
`grep -rn 'uv\.spawn(' tests/` outside the seam returns **nothing**; the seam
holds exactly one, which is the floor the arch guard will assert against.

**`mark()` earned its place immediately.** `cliproxy_update_spec:14` and
`cliproxy_download_spec:11` each start a release server at FILE scope and point
every case at its url — a blanket `reap()` in `after_each` kills it and breaks
every case after the first, which is exactly why update_spec's hand-rolled reap
deliberately spared it. Sequence numbers rather than indices, because a process
that exits on its own is pruned and would shift them.

Converted: `cliproxy_lifecycle` (4 sites), `cliproxy_catalog` (6),
`cliproxy_dispatch`, `cliproxy_caller_teardown`, `cliproxy_recovery_e2e`,
`cliproxy_auth_login`, `openai_tool_loop`, `cliproxy_conformance` (1 each), plus
`cliproxy_update`'s three private lists collapsed to one marked reap.

Three things fell out that were not in the plan:

- **The seam MERGES env; three specs were replacing it.** `openai_tool_loop` and
  `cliproxy_recovery_e2e` were re-adding `PATH` (and `HOME`) by hand to survive
  `uv.spawn`'s replace semantics. Through the seam those lines are gone — the
  bug the seam's keyed-map fold exists to prevent.
- **`cliproxy_conformance_spec` spawns the REAL cliproxyapi**, which can carry no
  watchdog, so the registry is the only layer that can ever collect it. It had a
  normal `after_each` and nothing for the killed-run case; now it has the
  `VimLeavePre` backstop, with SIGTERM preserved for the graceful shutdown.
- **`fake_releases.start`'s per-server `VimLeavePre` autocmd is gone** — the
  registry owns that now, and one autocmd per started server was its own small
  accumulation.

Verified: 17 specs (derived by grep over the changed fixtures, not typed) all
pass; `make lint` 0 warnings. The only red is
`fixture_reaping_spec`'s live-`ps` conformance case, whose script is M1's last
item.

### 2026-09-19 — RESUME HERE (session paused on token budget)

State: branch `000220-…`, working tree clean, nothing pushed. M1 is 3/4 done.
Plan: `workshop/plans/000220-reap-test-fixture-processes-plan.md`.

Commits on the branch: `e130ed9d` (orphan rule, both watchdogs), `32da1528`
(LoopbackHTTPServer chokepoint), `4c7e68c7` (the registry + eight-spec sweep).

**The one red, and it is expected:** `tests/integration/fixture_reaping_spec.lua`
→ "census conformance, against the real ps". Its script does not exist yet. Every
other spec touched is green and `make lint` is clean.

**Next, in order:**

1. **Write `scripts/reap-test-orphans.py`** — M1's last item, fully specified in
   the plan's Task 4 (the whole script is in the plan verbatim, along with
   `tests/fixtures/ps_test_orphans.txt`'s six rows and the eight-case unit spec).
   Do not re-derive it; three plan-review rounds and three plan-gate rounds went
   into that text. Watch the two non-obvious parts: `after` re-samples for
   `--grace` seconds before accusing anything (a fake under
   `PARLEY_FAKE_EXIT_DELAY_MS=4000` is alive on purpose), and a `ps` that RAN but
   cannot be parsed must fail loudly rather than report zero leaks.
2. Route it in `atlas/traceability.yaml` under `infra/test_harness`, then
   `sdlc milestone-close --issue 220 --milestone M1`.
3. M2 is Tasks 5–7: the Makefile gate, the docs, the four-invariant arch guard.

**Do not forget at close:** flip this issue's ledger row to `window_trusted=no`
(the `AT CLOSE` item in `## Plan`), and remember three of the four Done-when
proofs need a machine where `ps` is permitted — an agent sandbox refuses it.

**Still outstanding on the operator's machine:** ~25 orphans from before this work
(12 `fake_cliproxy`, 13 `nvim --headless`, oldest two days). Deliberately left in
place — they are a live target for the census once it exists. Sweep with
`ps -Ao pid=,ppid=,args= | grep "$(pwd -P)/tests/" | grep -v grep`.

### 2026-09-22 — M1 census landed

Implemented the `ps`-based census in `scripts/reap-test-orphans.py` with pure
`parse_ps`, `select_orphans`, and `ancestry` logic, a recorded-table
`--ps-from` seam, ancestry exclusion, bounded `--grace` re-sampling, and
visible skipped/broken outcomes. Added the six-row process-table fixture and
eight unit cases covering selection, near-misses, before/after behavior,
malformed output, and unavailable `ps`; routed both artifacts in
`atlas/traceability.yaml`. The RED test first failed because the script was
absent, then passed after implementation. The 11-case fixture-reaping
integration spec, 25-case architecture sweep, `make lint` (0 warnings/errors),
Python compilation, real-`ps` smoke path, and `git diff --check` all pass.

ARCH-DRY: one selector defines the checkout-owned process class for both phases;
ARCH-ORDER: only pids persistent across the grace samples are reported.

Boundary review BR-2 returned REWORK: the plan called the census and watchdog
predicates PURE, but the first tests reached them only through subprocesses.
Added `tests/unit/reap_test_orphans_pure.py` with direct no-IO calls for
`parse_ps`, `select_orphans`, `ancestry`, and `orphaned`; the plan now records
the revision and the test is routed in `atlas/traceability.yaml`.

Boundary review BR-3 returned FIX-THEN-SHIP: grace resampling hard-coded `ps`
instead of preserving the configured `--ps-command` seam. Threaded the command
through `persistent_candidates` and added a direct regression test; the review
also confirmed BR-2 was addressed.

Boundary review BR-4 returned REWORK because the new lifecycle/reaping surface
was not mapped in `atlas/infra/test_harness.md`. Added the process-lifecycle
map covering registry teardown, both watchdog chokepoints, the intentionally
detached real proxy, and the final `ps` census.
