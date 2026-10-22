---
collaboration-mode: discussion
---

# Test run lease: admission at target execution

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent any test-target entry, including aliases, prerequisites and default goals, from running scratch mutation or census outside its checkout lease.

**Architecture:** Keep the existing kernel lease and inherited descriptor. Replace the MAKECMDGOALS-dependent dispatcher with an unconditional public wrapper for every protected target, forwarding to a guarded internal recipe. Recursive calls reuse the same descriptor; native make goal scheduling is serial and per-spec concurrency uses JOBS.

**Tech Stack:** GNU make (including Apple's 3.81), Python stdlib flock/exec, headless Neovim, existing recorded ps and controlled-process test seams.

## Why this revision

BR-1 reproduced an active harness killed through `review-alias: test-spec`: inspecting the requested goal cannot establish what recipes Make's dependency graph will execute. The simplest alternative, retaining the request-name dispatcher and enumerating more aliases, cannot cover future aliases or default goals. Admission belongs to the protected target itself (ARCH-PURPOSE, ARCH-ORDER).

This replaces routing, not the lease resource. The stable lock inode, holder diagnostic, cancellation, inherited-child lifetime, standalone reaper and independent-checkout behavior remain the approved contract. Current code exceeds 100 added lines, so use the full workflow for this revised plan.

## Core concepts

No new PURE entity: process-table parsing, ancestry and selection in `scripts/reap-test-orphans.py` remain the existing pure core. This correction is integration routing, not a new process classifier (ARCH-PURE).

| Integration | Lives in | Status | Wraps |
|---|---|---|---|
| Checkout lease | `scripts/test-run-lease.py` | new in issue | flock, descriptor identity, exec |
| Protected target admission | `Makefile.parley` | modified | public Make targets, guarded internal recipes |
| Live census admission | `scripts/reap-test-orphans.py` | modified | shared lease followed by existing ps/signal boundary |

One protected public target owns one internal recipe; all wrappers derive from the one target list. One checkout has one stable lock file and potentially several inherited references to its same open description. No separate PID/boolean authority or watcher is added. The holder PID is diagnostic only (ARCH-DRY, ARCH-SECURE).

## Routing and lifetime contract

1. Every target in PARLEY_TEST_TARGETS always has a public wrapper. Neither its existence nor its execution depends on MAKECMDGOALS.
2. The wrapper runs `python3 scripts/test-run-lease.py --root "$(CURDIR)" -- $(MAKE) --no-print-directory -f "$(firstword $(MAKEFILE_LIST))" parley-test-body-$@`. Existing argv quoting and command-line variable inheritance are retained.
3. Rename only protected implementation recipes to `parley-test-body-<target>`. The full test body's recursive calls continue to use public names, reusing the inherited lease. Move check-test-deps prerequisites to internal recipes so prerequisites execute under admission.
4. Every internal body has an order-only prerequisite `parley-test-require-lease`. Its recipe invokes the shared helper's `--require` mode, which validates the inherited descriptor and fails explicitly if missing/invalid. It does not acquire a short-lived replacement lock. Thus direct internal calls cannot run unowned effects.
5. Remove the old whole-file conditional dispatcher and parse-time lease probe. Keep unrelated help/lint/dependency definitions available. Preserve the standalone Makefile.parley default help goal when no enclosing makefile has set one.
6. Use native `.NOTPARALLEL` for make recipe goals, including aliases with multiple protected prerequisites. This file's test fan-out still uses JOBS/xargs; no machine-wide admission changes are made.
7. A dry-run wrapper forwards to the internal make with no lease command prefix; inherited `-n` makes the internal guard and recipe print-only. Reuse the tested compact/long MAKEFLAGS detection. Add alias/default/internal dry-run coverage. No dry-run takes a lock or changes scratch.
8. Standalone live census still calls the shared lease owner; recorded --ps-from remains signal-free. Fixed `.test-run.lock` is never unlinked by commands; checkout removal ends its one-file lifetime (ARCH-FUNERAL).

The helper's `--require` is an internal integration check, not a new public contributor workflow. Remove obsolete `--check` mode if it has no consumers. No persisted application format changes (ARCH-EVOLVE).

## State and scope

Actions: run, wait, cancel, retry.

| State / event | Visible outcome | Recovery | Loss |
|---|---|---|---|
| Public direct/alias/default target, lease busy | waits and names original owner | wait or cancel | none |
| Wrapper acquires or reuses valid lease | internal recipe runs through final census | wait or cancel | interrupted test progress if cancelled |
| Direct internal target without valid descriptor | explicit refusal before scratch/census | retry through public target | none |
| Dry-run on any entry path | recipes print without admission | run normally when wanted | none |
| Owner dies while descriptor remains in descendant | competing run still waits | wait for descendant shutdown | interrupted progress |
| Last holder exits | next wrapper acquires and performs existing before census | retry | abandoned processes are reaped |

This is batch infrastructure: one stable file and constant descriptor footprint per checkout, no added per-spec scans, cancellable waiting until holder exit (ARCH-CONSTRAINTS). Existing pure recorded-table tests and gated real make/flock/nvim tests are the stateful seam plus live conformance; no new external service is introduced (ARCH-MOCK). Include direct, prerequisite-chain, default and internal-entry paths in behavioral coverage, not just a source enumeration (ARCH-ORDER).

## Task 1: reproduce the entry class

Files: `tests/unit/test_run_lease.py` (existing disposable checkout/gates).

- [x] Extend the fixture runner to accept explicit goals, including no goals. Append aliases `first-alias: test-spec` and `outer-alias: first-alias`; set a default alias in a separate case.
- [x] Gate the first alias/default-run Neovim, then start a second direct run and a manual census. Assert their waiting diagnostics before scratch creation or signalling, then release both runs and assert success. Reuse the existing two-run assertion helper rather than copy it.
- [x] Run `python3 -B -m unittest tests.unit.test_run_lease -v`; confirm these added cases fail on current routing. Add direct internal-entry refusal and dry-run cases once the internal target name is specified; expected refusal must precede scratch effects.

## Task 2: replace request inspection with target wrappers

Files: `Makefile.parley`, `scripts/test-run-lease.py`, `tests/unit/test_isolation_spec.lua`, `tests/unit/test_run_lease.py`.

- [x] Implement the routing contract above, using a single target registry, public wrappers, guarded internal recipes, preserved standalone help default, serial goal scheduling and dry-run forwarding.
- [x] Update the existing source guard that identifies check-couch-actors-live to understand its internal recipe name; retain its real environment/sentinel assertions.
- [x] Extend target coverage checks to map every census/scratch body to a public wrapper and required lease guard. Verify a directly requested internal body refuses without ownership.
- [x] Run all direct Python lease and census/watchdog tests. Expected: all green, no surviving fixture processes. Keep status/cancellation, owner/descendant death, unrelated-command and separate-checkout controls.
- [ ] Commit code/tests with the issue log and learned rule; record the BR-1 counterexample and fix without claiming disposition before gate review.

## Task 3: verify and finish

Files: `TOOLING.md`, `atlas/infra/test_harness.md`, issue details, `workshop/lessons.md`.

- [x] Document target-execution admission, internal refusal, aliases/default goals, serial Make goals and dry-run behavior; retire old request-dispatch claims with this Revision.
- [ ] Run `make test-spec SPEC=infra/test_harness` and `make lint`; inspect actual mapped output and final census. Run required authoring/architecture checks through the mapped harness and recorded suite.
- [ ] Push with `sdlc pr`; run `sdlc local-check run --name suite` on final code. The old queued run lease-3134723290 was cancelled via its supported command after BR-1; it provides no passing evidence.
- [ ] Run `sdlc close --issue 409 --verified '<fresh evidence>'` for full boundary review. It may overlap the new retained suite per tl-worker; fix/dispute findings by their class.
- [ ] Require a recorded suite pass on final code plus green CI before landing. Follow TL landing direction and `sdlc merge --yes`, report the PR outcome, then stop.

## Revisions

### 2026-10-22 — guard prerequisite ordering

The required-lease check is the first normal prerequisite rather than order-only, so it also precedes later check-test-deps prerequisites on direct internal entry. Every internal body is already phony; this strengthens admission ordering without changing scheduling, resource ownership or the public contract.
