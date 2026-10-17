---
id: 000374
status: working
deps: []
github_issue:
created: 2026-10-17
updated: 2026-10-17
estimate_hours:
collaboration-mode: collaboration
card_mirror: '702eb00d5e53677666a4764fc9b721737c86e35d' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-17T03:37:23-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "461e862b", done: "9a3f2a5c"}
---

# Spec sweep: positive waits on a process or timer use the product deadline, not a 2 s literal (19 files; #370 lesson)

## Problem

## Spec

From #370 (2026-10-17). A spec that waits a fixed 2 s for a process or timer it started (`assert.is_true(vim.wait(2000, ...))`) flakes under suite load. In #370 a file that takes about 1 s unloaded took 22–33 s across 141 attempts under a suite. #370 fixed session_sync_spec by tying every positive wait in it to the product's own deadline.

19 other spec files still use the 2 s pattern:
- unit: build_messages, outline, response_preparation, dispatcher_query;
- integration: response_target, chat_tree_context, tasker_supervision, review_send, async_builtin, define, document_registry, skill_invoke, generation_turn, generation_sequences, entity_navigation_native, response_submission, unscoped_kill, session_sync_native, lock_leave_reminder.

Rule (the #370 lesson): a positive wait, one that returns on arrival, is bounded by the product deadline it observes, or by one shared suite arrival budget where no product deadline exists. Absence checks keep their short fixed waits.

## Done when

- Each positive 2 s wait on a process or timer in those files uses the product deadline or the shared budget. Waits on pure in-memory state may stay, with the reason noted.
- A lint or arch test refuses a new literal positive `vim.wait(N, ...)` assertion under the integration specs, naming the helper to use.
- The suite still passes, and a passing run is not slower, since positive waits return on arrival.

## Plan

- [x] tests/helpers/arrival.lua: one shared arrival budget, MS = 15000, the product's longest round-trip deadline (agentic_submit_timeout_ms). session_sync_spec keeps its product deadline.
- [x] Mechanical rewrite: every positive wait's literal bound in tests/unit and tests/integration becomes arrival.MS. That is 275 sites in 93 files; the one 30 s wait (stream_integrity) becomes 2 * arrival.MS. The two waits assigned to a local first (session_sync_native, document_presentation_reentrant) are converted by hand. The second passes the budget into its child Neovim.
- [x] (superseded by the round-2 entry below) '-- bound: <reason>' marker: reviewed the candidates whose case names suggest timing ("before", "immediate", "native timers run"). Each checks its property after the wait, so none needed the marker.
- [x] tests/arch/arrival_budget_spec.lua: refuses a bare literal in the three assert forms, with a floor of 250 found. Mutation check: one literal reintroduced in outline_spec fails it, and the same line with '-- bound: probe' passes.
- [x] atlas/infra/test_harness.md: the rule, the marker and the arch test's reach.
- [x] Full suite green, round 1: sdlc local-check on 236db111 (3m54s).
- [x] Round 2 (close review REWORK): the round-1 sweep and arch test saw only the one-line assert form. That left 185 bare and local-assigned predicate waits with literals in 43 files, among them define_spec's and skill_invoke_spec's 2 s waits. Round 1's "only two local-assigned waits" claim was wrong. Each site was classified by reading what follows it:
  - 158 positive, now on arrival.MS; the waits over 15 s take 2 * arrival.MS;
  - 11 absence checks, which keep their literal and are marked '-- absence:';
  - 11 teardown drains, marked '-- drain:';
  - 3 bounds that are the property, marked '-- bound:' (skill_invoke 377 and 414 fake hrtime; query_cache 115 is the SIGTERM grace before SIGKILL).
  The review named cliproxy_login 72 and 200 as positive. They are absence checks: the next line asserts the count did not grow.
- [x] The arch test now reads every `vim.wait(<literal>, <predicate>)` whatever its form, needs a reason marker on any kept literal, and has a floor of 400. Mutation check: a bare, unasserted `vim.wait(500, pred)` in outline_spec fails it.
- [ ] Full suite green, round 2.

## Revisions

- 2026-10-17: scope widened from the 2000 ms literals in 19 files to every literal positive wait (about 275 sites; 93 files as measured), so that the arch test can refuse new literals. Approved by the hub. Out of scope: tests/packaging and tests/perf, which run outside the suite, and cliproxy_conformance's assigned 20 s live wait.
- 2026-10-17, round 2: the assert-form sweep missed the bare and local-assigned positive waits. Both were swept as well, and the arch test was widened to every predicate wait, with absence/drain/bound reasons. The round-1 count, "275 sites in 93 files", covered the assert form only. cliproxy_conformance's 20 s waits are now 2 * arrival.MS too.

## Log

### 2026-10-17

- Cost, as the hub asked: a broken case now takes up to 15 s to report, since a case stops at its first failed wait. The files with the most positive waits are tool_path_authority (19), skill_invoke (18), tasker_run (15) and session_sync_native (11). If everything such a file exercises broke at once, it would take up to cases x 15 s. More than about 13 failing cases in one file reaches the runner's 200 s absolute ceiling (base 50 s x 4), and that file then reports as timed out rather than per assertion. Accepted.
- First `make -k test` on the branch had two failures. (1) packaging_launcher_spec: the rewrite reached a wait inside Lua source the spec writes for a child launcher, where `arrival` is unbound. Fixed by interpolating the budget into the generated line; focused run 11/11. (2) single_source_sweeps_spec "every symbol the Spec and plan tables name": it fails on any quick-flow issue branch, since it takes the id from the branch name and finds no Core-concepts table. It is pre-existing, not #374's. sdlc's detached suite checkout makes it pending, so it never shows at landing. Filed as #375, unclaimed.
- Lesson: a mechanical rewrite of test source also rewrites code that a spec writes out for a child process. Grep the rewritten names inside string literals before running.
