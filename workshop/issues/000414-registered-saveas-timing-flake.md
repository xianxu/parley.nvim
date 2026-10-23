---
id: 000414
status: working
deps: []
github_issue:
created: 2026-10-22
updated: 2026-10-23
estimate_hours:
collaboration-mode: collaboration
card_mirror: '866e311dd20d099429749b06165a5b9c37cd08c6' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-23T05:49:02-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "20be0eae", done: "4de86a78"}
---

# Investigate registered-saveas timing flake under load

## Problem

The existing registered native saveas test intermittently exceeds its fixed elapsed-time assertion under load. The same code failed in the full session-sync mapping and passed in one isolated rerun during #410 close review. Related class: #412 (fixed-budget native timing under load); this is a separate test and must not silently inherit that case's exception.

## Spec

Investigate `tests/integration/agentic_document_spec.lua`, case `agentic markdown admission under a slow Couch (#357) a registered :saveas onto an absent file returns at once and lands (row 1)`. It registers the file, configures a 2-second delayed fake registry, invokes native saveas, and asserts the call returns in less than 500 ms before waiting for the move to settle. The failure is line257, `the rename waited on Couch`; saveas itself returned successfully. Determine which native/file/protection stage consumes time under load and distinguish a real synchronous wait regression from a fixture timing assumption. Preserve #410's separate real 500 ms input-admission requirement.

## Done when

- Capture stage timing/outcome evidence under the failing load and classify the source of the elapsed-time breach.
- Make the nonblocking-saveas assertion reject the intended regression with controlled evidence rather than a blind passing retry or blanket timeout increase.
- Verify a regression negative control and the affected mapping on supported Neovim runtimes.

## Plan

Root cause (measured in a disposable clone at main 20f3513b, hrtime marks at every stage of BufFilePre, BufFilePost and BufWritePost):
- Nothing on saveas's synchronous path waits on Couch. Idle: 20 reps at 46-52 ms. Under 3 CPU spinners plus an fsync dd loop: 79 reps, median 53, p95 63, max 91 ms. The cost is ss.acquire_observed (about 32 ms: turn, admission, refresh) and BufWritePost's hash plus advance (about 16 ms). The pause and the lease are under 1 ms. The bounded Couch lookup runs only when overwriting (decision.wait_destination), not in row 1.
- So a breach of 500 ms is a stall of the whole nvim process (scheduling under a full suite on a loaded machine), not a wait in the code under test. The fixture can't tell the two apart: with_timeouts(15000, 500) sets the move timeout equal to the 500 ms assertion bound, so the real regression (a synchronous Couch wait bounded by the move timeout) and a scheduling stall produce the same signal.

Fix (a fixture mechanism, so it waits for TL approval):
- [x] Add a gate to fake_couch_registry.py: in delay mode with FAKE_COUCH_REGISTRY_GATE=PATH, the registry answers only once PATH exists (polled, with the delay as an upper bound). The test then controls when Couch answers.
- [x] Row 1: gate the registry and raise the move timeout to 5000. Assert causally: saveas returns while the gate is closed, the move operation is still pending, and identity has not moved. Then open the gate and await the landing. A synchronous wait would either block until the 5 s timeout or see no answer at all, so the pending-operation assertion fails on any load. Drop the wall-clock bound for this row.
- [x] Same class, same file: row 2 ("plain saveas asks Couch nothing") becomes a count of registry requests (zero), not a time. Row 4 ("legacy move refuses at once") gets the same gate treatment as row 1. The Alt+Return press bound at line 113 is #410's 500 ms input-admission requirement and stays as it is.
- [x] Negative control in the disposable clone: force decision.wait_destination true for row 1, and make row 4's move wait on register. Each must fail deterministically on the causal assertion. Record the output in the Log.
- [ ] Verify the modes/session_sync mapping on nvim 0.12.5 and 0.11.7, plus 20 reps of the three rows under 4-process load. Then run the suite through local-check.

## Log

2026-10-22: Filed unclaimed at TL direction cb8f8ce2 while #410's recorded suite remains queued. Both observations use reviewed head199c3b90373e3007fc023d50a8f00652588aec93 (same product code as ff71df2b2f2fc69b57d3ccca4001de3d7dd47825; subsequent #410 fixes are documentation only). Reviewer used preferred Neovim0.12.5.

Failure: full32-file session-sync mapping853 passed/1 failed/0 errors. `/tmp/parley-410-review-tests.log:269` names this exact case; line271 reports `agentic_document_spec.lua:257: the rename waited on Couch`, boolean false where true expected. The assertion establishes elapsed >=500 ms; an exact duration and machine CPU/load snapshot were not emitted. The review also ran bounded focused/substitution checks in a distinct disposable checkout during the session; no claim about a measured load level.

Pass: `/tmp/parley-410-review-extra.log:85` names the identical case, followed by1 passed/0 failed/0 errors. The reviewer restored all Lua modules with git checkout from its199c3b90 checkout before selecting just this case. The successful assertion establishes elapsed <500 ms, with no exact duration emitted. The rest of that extra run passed Couch25 and owner architecture7. The earlier `/tmp/parley-410-review-negative.log` is a deliberate pre-correction control for other #410 cases and is NOT this passing rerun.

The implementer's own preferred mapping and complete operator Neovim0.11.7 mapping also passed this test (operator854/0/0). Raw local logs are diagnostic pointers; the assertion, setup, counts and limits above are durable evidence independent of those temporary files.

TL permits #410 to proceed with its retained queued suite; if that recorded suite fails on this exact case, one evidenced rerun is authorized. This does not authorize accepting other unknown failures or changing test budgets in #410.

2026-10-23: Plan approved by the TL. Done:
- Added FAKE_COUCH_REGISTRY_GATE: answers once the file exists, bounded by the delay, and also opens when its directory disappears.
- Added FAKE_COUCH_REGISTRY_TRACE: one verb per request.
- Swept the same zero-margin class in agentic_document_spec beyond the planned rows 1, 2 and 4: row 3 (unknown identity) and rows 1, 5 (registered move_path; the band check still waits past the 1 s deadline before opening the gate).
- Rows 3 and 4's causal check: a second move_membership while the gate is held returns the same refusal (nil; the question still stands and is deduplicated). A busy check was wrong; the first attempt failed on exactly that.
- Negative controls in the disposable clone, with control A (wait_destination forced true) and control B (move_membership replacing ask_in_background with bounded_request) applied together: 45/3/0.
  - Row 1 failed at :267, "rename not confirmed: Couch did not answer within 5 s".
  - Rows 3 and 4 failed at :230 and :306, "Couch did not answer within 1 s" instead of the background refusal.
  - Reverted: 48/0/0 on nvim 0.12.5 and 48/0/0 on 0.11.7 (agentic_document_spec).


2026-10-23: The first 20 reps under load (3 CPU spinners plus an fsync loop) passed 14 and failed 6, all on row 2. The trace was not empty: it held one lookup. Tracing the full argv showed that the lookup is for the new path, the renamed buffer's ordinary background identification. It is not a request made by the rename. Under load that lookup landed before the check, and the first version expected no requests at all.

Fixes:
- The trace records the full argv as JSON.
- Row 2 asserts that every request is a lookup of the target.

What row 2 still misses: a plain rename that waits on its own lookup of the target. That would need a product seam it doesn't have.
