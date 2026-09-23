---
type: continuation
slug: reap-test-fixture-orphans
agent: claude
created: 2026-09-19T23:33:49
branch: 000220-lifecycle-test-fixtures-leak-fake-cliproxy-and-headless-nvim-orphan-to-init
worktree: /Users/xianxu/workspace/parley.nvim
issues: [000220]
---

# Continuation: reap-test-fixture-orphans

## NEXT ACTION

Write `scripts/reap-test-orphans.py` — the last item in #220's M1. **Transcribe it
from the plan, do not re-derive it:** `workshop/plans/000220-reap-test-fixture-processes-plan.md`
Task 4 carries the whole script verbatim, plus `tests/fixtures/ps_test_orphans.txt`'s
six rows and the eight-case unit spec. Three plan-review rounds and three
plan-gate rounds are compressed into that text; rewriting it from the summary
will lose the parts that took the longest to get right.

Two of those are non-obvious and were each a blocking gate finding:

- `--phase after` must **re-sample for `--grace` seconds** before accusing
  anything. `cliproxy_update_spec:486` sets `PARLEY_FAKE_EXIT_DELAY_MS = "4000"`,
  so that fake is alive-on-purpose for 4s after its SIGTERM; a zero-grace census
  fails a run that leaked nothing.
- A `ps` that **ran but cannot be parsed** must fail loudly, not report zero
  leaks. That is the same shape as the `pgrep` remedy this whole issue exists
  because of — a cleanup that silently no-ops and reads as success.

Then route it in `atlas/traceability.yaml` under `infra/test_harness`, confirm
`tests/integration/fixture_reaping_spec.lua` goes fully green (its live-`ps`
conformance case is the only red on the branch today), and run
`sdlc milestone-close --issue 220 --milestone M1`.

## State of play

**#220** — in flight, branch `000220-lifecycle-test-fixtures-leak-fake-cliproxy-and-headless-nvim-orphan-to-init`,
clean tree, **nothing pushed**. M1 is 3/4; M2 (Tasks 5–7) untouched. Run
`sdlc state` and read the issue's `## Plan` ticks and the `RESUME HERE` block at
the end of `## Log` — that block is the operational detail this section
deliberately does not duplicate.

Branch commits: `e130ed9d` (the orphan rule in both watchdogs), `32da1528`
(the `LoopbackHTTPServer` chokepoint), `4c7e68c7` (the registry + eight-spec
sweep), plus issue-sync commits.

Two untracked issue files (`000272`, `000273`) appeared during the session from
another session; they are **not** part of this work and were left alone.

## Thread arc & user model

Opened with four words — "next up, #220, don't leak resource in test" — and the
operator then went quiet through design, returning only to ask twice **"where are
we now?"** and once **"what do you mean by task 3?"**. That is the arc, and it is
the model: this operator delegates execution completely and monitors through
**durable artifacts**, not through conversation. Both status questions came after
stretches where I had committed code but left the issue's `## Plan` unticked and
`## Log` silent — the second one immediately after a turn where the only work was
the ledger exclusion they had just asked for. The issue file being stale *was* the
complaint; "where are we" was the symptom.

"What do you mean by task 3?" is the same failure one level down: I had been
narrating progress in plan-internal task numbers, which are meaningless without
opening the plan file. The correction is to describe work by what it does.

The ledger instruction — "for now just exclude 220 from calibration ledger" —
shows the same disposition from the other side: told about a measurement defect,
they issued a one-line containment decision and declined the investigation.
"For now" is doing real work in that sentence; the deeper fix is deferred, not
dismissed. Do not re-litigate it on resume.

Working model: **tick and log as each unit lands, not in batches** — the issue
file is this operator's dashboard, and a correct-but-silent agent reads as a
stalled one.

## Open questions

On resume, resolve these open questions with the user before continuing with the
NEXT ACTION.

1. **The `sdlc actual` window anchoring looks like a class bug, and nobody has
   decided whether to file it.** #220's window anchors at `7353d798` — the
   *issue-creation* commit of 2026-09-06 — not at the 2026-09-19 claim, so it read
   5.95h before a line of implementation existed, spanning 13 days and 87
   attributed issues. AGENTS.md §2 says claiming early anchors at the claim
   commit. Any issue that sits open before being claimed is exposed. The operator
   said "for now just exclude 220"; they have **not** been asked whether to open
   an ariadne issue against the window derivation. Ask once, then respect the
   answer.
2. **~25 pre-existing orphans are still live on the operator's machine** (12
   `fake_cliproxy`, 13 `nvim --headless`, oldest two days). I proposed keeping
   them as a live target for the census and got no answer. They cost ~250MB and
   nothing else. Confirm: sweep now, or leave until the census can prove itself
   against them?

## Artifact map

Read in this order; issues are not auto-loaded.

- **`workshop/issues/000220-…md`** — the contract. `## Spec` and `## Done when`
  predate this session; `## Plan` (milestone-tagged), `## Estimate` (three
  revisions, see below) and a long `## Log` are this session's. The Log's last
  entry is `RESUME HERE`.
- **`workshop/plans/000220-reap-test-fixture-processes-plan.md`** (~1975 lines) —
  the durable design, and the **source of truth for the remaining work**. Task 4
  is the NEXT ACTION verbatim; Tasks 5–7 are M2. It exists at this length because
  three fresh-eyes review rounds and three plan-gate rounds each found real
  defects in it; the gate ledger sits beside it at
  `…-plan-gate.md` with one advisory finding carried to the close review (the
  plan restates code verbatim — accepted deliberately, since transcription is the
  intended use).
- **`tests/integration/fixture_reaping_spec.lua`** — the proof surface. Every
  case orphans a *real* process and waits for it to die; liveness is probed with
  `uv.kill(pid, 0)` → ESRCH, never `ps`, so it passes inside an agent sandbox.
- **`tests/helpers/exit_with_parent.lua`** + **`tests/fixtures/fixture_watchdog.py`**
  — the two halves of one rule that cannot be single-sourced across a language
  boundary. M2's arch guard exists to keep them from drifting apart.
- **`tests/helpers/fixture_process.lua`** — the seam that now owns the registry.
- **`brain/data/life/42shots/velocity/calibration-findings.md`** → "Excluded rows"
  — why #220 is excluded from calibration. Peer repo at
  `/Users/xianxu/workspace/brain`; already committed by its autosave rhythm.
- **Lessons for M2** are already drafted verbatim in the plan's Task 6 Step 3 —
  do not re-derive them when writing `workshop/lessons.md`.

## Decisions & dead ends

- **Milestone split moved mid-flight, because a test said so.**
  `single_source_sweeps_spec` reads the *whole* plan's Core-concepts table on any
  issue branch, so leaving the census in M2 left `select_orphans`/`ancestry`
  undefined at M1's boundary — measured red, not predicted. M1 is now "everything
  that exists as a thing" (Tasks 1–4), M2 is wiring/docs/guard.
- **The census deliberately cannot see the real cliproxyapi**
  (`cliproxy_conformance_spec`). Rejected chasing it: `lua/parley/cliproxy.lua`
  spawns that binary detached *by design* so it outlives Neovim, so a survivor is
  product behaviour, not a leak. Making it visible would mean writing its config
  inside the tree, which `scratch_placement_spec` forbids (#202).
- **Rejected a pure path-match for the census selector.** Matching every process
  whose argv names a path under `<root>/tests/` is what keeps it free of a stale
  enumeration — and it also matches the operator's editor sitting on a spec file,
  which the script would then SIGKILL. Second clause (`--headless`, or under
  `tests/fixtures/`) plus caller-ancestry exclusion.
- **Estimate went 4.90 → 5.98 → 7.79 → 8.71** across three judge rounds. Declined
  the judge's fourth pressure — correcting for this repo's repo-wide 0.5–0.7 ratio
  drift — on the grounds that per-issue correction is back-fitting and destroys
  the signal the ledger exists to carry. That is the model's job (ariadne#127).

## Lessons learned

- **A watchdog that only watches for a *change* misses the case it exists for.**
  Both watchdogs compared `getppid()` against a value sampled at startup. A
  process orphaned *while still booting* samples `1` as its own starting parent,
  so the rule never fired for the dominant case — and 897 fixtures had
  accumulated under a watchdog that looked correct and was even switched on. When
  a guard compares against a startup sample, ask what that sample reads when the
  condition is **already true**, and test that ordering deliberately.
- **An opt-in invariant is exactly as complete as the list of sites that opted
  in.** Two of eight spawn sites set the flag. Moving it into the constructor
  every long-lived fixture already passes through made it true by construction.
- **A rule broad enough to be complete is often too broad to act on.** See the
  census selector above. Completeness and blast radius are different axes.
- **This repo's guards are load-bearing and will find your design errors** — the
  plan-entity guard caught both a Python blind spot in its own matcher and a
  wrong milestone boundary. Run the arch specs early, not at the boundary.
- **Working with this operator: tick and log per unit of work.** See Thread arc.
