---
id: 000400
status: working
deps: []
github_issue:
created: 2026-10-19
updated: 2026-10-19
estimate_hours:
severity: low
collaboration-mode: collaboration
card_mirror: '2bfa47f131222ce7bb912aed45a62d95023d7982' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-19T12:01:16-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
---

# couch.run: session-sync status/actors queries and sends have no deadline

## Problem

Some `parley.couch.run` callers give the child no deadline. `session_sync.probe` runs `couch --session-sync status --json` and `couch --actors --json` through `couch.query` with no `timeout`, and `couch.send` has none either. If `couch` hangs (a wedged supervisor, a blocked socket), the child and its two stdio pipes stay open for as long as it hangs. The probe's `s.probing` flag also stays set, so probing stops for that buffer. `document_registry` (deadline per operation, #382) and `attention` (`PROBE_TIMEOUT_MS`) already bound theirs. Found during #399 (no leak was measured on this path; this is the unbounded-lifetime gap, not the #399 root cause).

## Spec

`couch.run` (the one seam to the `couch` binary) applies a default deadline when its caller names none: `options.timeout` defaults to `couch.DEADLINE_MS`, which is `parley.config`'s shipped `agentic_submit_timeout_ms` (15000), the budget a submit already gets (ARCH-DRY). On expiry `vim.system` kills the child (SIGTERM), and the callback fires once with code 124. A caller that bounds the child itself passes `timeout = false`. Only `document_registry` does that: its own timer kills the child and reports the deadline with its own message (#382), and a second timer would race it.

Callers and their deadline after this change (ARCH-PURPOSE sweep of every `couch.run` path):

| Caller | Deadline |
|---|---|
| `session_sync.probe`: status, actors | default |
| `session_sync`: violation and ping sends | default |
| `session_sync.release_and_send` (legacy submit) | default |
| `couch.own_slot` (actors; also used by `agentic_document`) | default |
| `attention`: status probe | its own `PROBE_TIMEOUT_MS` (5000), unchanged |
| `document_registry` | `timeout = false`; its own timer, unchanged |

What a timeout means for each kind of call (ARCH-ORDER: a deadline is an unconfirmed outcome, not a failure):

| Call | After the deadline | Visible | Recovery | Possible loss |
|---|---|---|---|---|
| status or actors query | reads as no answer (nil): nothing owed, no ping, `s.probing` cleared | nothing; the band keeps its last owed state | the next poll probes again | one ping cycle is delayed |
| ping or violation send | ignored (fire-and-forget) | nothing | the next ping generation | one notice may be lost or late |
| legacy submit send | the message may have been queued | `send to OWNER not confirmed within Ns; it may have arrived. Alt+Return resends` | Alt+Return | a possible duplicate if it did arrive |

ARCH-CONSTRAINTS: these are local Unix-socket calls on the UI's async path; the editor never waits on them. A child now lives at most 15 s instead of forever. ARCH-MOCK: the fake couch gains `$FAKE_COUCH_QUERY_SLEEP`, which delays `--actors` and `--session-sync` answers, so a hung query is reproducible. ARCH-SECURE and ARCH-EVOLVE: N/A; no new input, secret or persisted format. ARCH-FUNERAL: this creates nothing durable; it ends child lifetimes that were unbounded.

## Done when

- Every `couch.run` caller passes a bounded deadline, or `couch.run` applies a default one, and the callback still fires once on expiry.
- A probe whose couch call times out clears `s.probing`, so the next poll probes again; a spec with a fake couch that sleeps past the deadline shows it.

## Plan

- [ ] `couch.run` defaults `timeout` to `DEADLINE_MS`, and `timeout = false` means the caller bounds the child itself. Add `couch.timed_out(obj)` (code 124, signal 15).
- [ ] `document_registry` passes `timeout = false`.
- [ ] The legacy submit send reports a timeout as unconfirmed (it may have arrived), not as failed.
- [ ] Fake: `$FAKE_COUCH_QUERY_SLEEP` delays query answers.
- [ ] Unit tests: the default kills a hung child, the callback fires once with code 124, an explicit timeout wins, `false` sets no timeout.
- [ ] Integration tests:
  - A probe whose status query hangs past the deadline clears `s.probing`, so the next poll probes again and the ping arrives.
  - Every `couch` spawn on the submit, probe and ping path carries a positive timeout.
  - The legacy submit timeout message says the send is unconfirmed.

## Log

### 2026-10-19
