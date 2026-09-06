---
id: 000220
status: open
deps: []
github_issue:
created: 2026-09-06
updated: 2026-09-06
estimate_hours:
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

- [ ] Reproduce: run the lifecycle tests, count survivors with `ps`, then
      interrupt a run mid-way and count again.
- [ ] Reap in teardown; add the suite-level sweep for the interrupted case.
- [ ] Add the exit-time survivor count as a test failure.
- [ ] Document the `ps`-based cleanup and the `pgrep` caveat.

## Log

### 2026-09-06

Found from outside the repo: the operator reported keyboard lag and slow
copy-paste in `pair`, and the cause was 560 orphaned processes from this suite
competing for the machine. Nothing in `pair` was at fault — `couch` measured
0.4% CPU throughout.

Reliable cleanup, since `pgrep -f` misses them:

    ps -Ao pid=,args= | grep '[f]ake_cliproxy' | awk '{print $1}' | xargs kill
    ps -Ao pid=,args= | grep '[n]vim --headless' | awk '{print $1}' | xargs kill
