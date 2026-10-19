---
id: 000394
status: working
deps: []
github_issue:
created: 2026-10-18
updated: 2026-10-19
estimate_hours:
collaboration-mode: collaboration
card_mirror: 'fbfb77660ef21066f0af4f6342dbe19a9a50bcfe' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-19T14:14:24-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "3bed86d6", done: "87a22e9a"}
---

# Registry queue deadline flake

## Problem

The existing document_registry_spec queue/deadline case is intermittent under parallel suite load. In #393 recorded suite cb7588a68bab3b4b10fa36c1e134718c on d6e05403, request 1 returned unavailable: Couch registry deadline exceeded after 1000 ms; queued_ms=0, ran_ms=1000, instead of absent. All other preferred-runtime spec files passed; make stopped before the compatibility pass. The same unchanged spec passed all 11 cases alone immediately afterwards (/tmp/parley-393-registry-alone.log).

The test starts eight Python-backed fake lookups with a 0.6-second sleep and a one-second per-child deadline, leaving only 0.4 seconds for interpreter/startup/scheduling under load. Neither registry code nor its spec differs between #393 and origin/main; #393 changes only the spelling default.

## Spec

Remove the load-sensitive timing assumption while preserving the actual invariant: a queued request gets its execution deadline only when its child spawns. Reproduce deterministically through controlled scheduling, not a larger timeout alone. Keep separate real process-boundary coverage.

## Done when

- A deterministic regression catches a deadline started at queue admission.
- Parallel suite load no longer causes this case to classify a valid request as unavailable because of the test's narrow real-time slack.

## Plan

Diagnosis: in the recorded failure, request 1 failed with `queued_ms=0` and `ran_ms=1000`. It never queued. Its own Python fake child took longer than the 1 s deadline under load. The queue invariant held; the test's 0.4 s of real-time slack is what broke. No registry code changes.

- [x] Deterministic regression (controlled scheduling). Stub `couch.run` so that no child answers until the test answers it.
  - Requests 1–4 take long deadlines (arrival.MS) and hold all four active slots.
  - Request 5 has a 300 ms deadline and waits in the queue.
  - Hold the queue for 900 ms, then answer request 1 with a null-registration reply. That frees a slot, and request 5 spawns.
  - The stub answers request 5 synchronously with the same reply (the registry handles a synchronous answer).
  - Assert: request 5 is `absent` with `queued_ms >= 900`, and `couch.run` ran five times.
  - Why it's deterministic: a deadline started at admission would fire during the hold, because a timer never fires early. Request 5's real deadline never comes into play, because its answer arrives in the same call that starts it.
  - Red check: start the timer at admission and confirm the test fails.
- [x] Real process-boundary coverage stays, without the narrow slack.
  - Eight lookups through the Python fake now sleep 0.2 s and take the arrival deadline, not 1 s.
  - All eight answer `absent`, and at least four queued for at least 150 ms. A queued request waits for a child that sleeps at least 0.2 s, so the lower bound is structural, not a timing guess.

## Log

### 2026-10-18

Failed evidence: /Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/cb7588a68bab3b4b10fa36c1e134718c.log (SHA-256 prefix 1fb5f695372b). File: tests/integration/document_registry_spec.lua, case starts a request's deadline when its child spawns, not when it queues. Failure assertion line 115. The isolated unchanged run passed 11/11. Filed unclaimed for the hub; #393 will retain this failure and make one unchanged recorded rerun per the worker flake rule.

### 2026-10-19

- Request 1 failed with `queued_ms=0`, so its own child, not the queue, overran the deadline. The registry needed no change; the test's 0.4 s slack did.
- The deterministic test stubs `couch.run`, holds request 5 in the queue for three times its deadline, then answers it in the call that starts it.
- Red check: with the deadline timer armed at admission, the deterministic test fails, while the real-process test still passes (the red check is the deterministic test's job). With the real code, both pass.
- `make test-spec SPEC=modes/session_sync` is green (28 files, 0 failed).

