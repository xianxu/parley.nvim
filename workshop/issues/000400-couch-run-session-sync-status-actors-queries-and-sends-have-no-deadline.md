---
id: 000400
status: codecomplete
deps: []
github_issue:
created: 2026-10-19
updated: 2026-10-19
estimate_hours:
severity: low
collaboration-mode: collaboration
card_mirror: '910803abd2a827baf7581b83cab5cd69b1c111fc' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-19T12:01:16-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "e7520144", done: "220db29b"}
actual_hours: 1.24
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

- [x] `couch.run` defaults `timeout` to `DEADLINE_MS`, and `timeout = false` means the caller bounds the child itself. Add `couch.timed_out(obj)` (code 124, signal 15).
- [x] `document_registry` passes `timeout = false`.
- [x] The legacy submit send reports a timeout as unconfirmed (it may have arrived), not as failed.
- [x] Fake: `$FAKE_COUCH_QUERY_SLEEP` delays query answers.
- [x] Unit tests: the default kills a hung child, the callback fires once with code 124, an explicit timeout wins, `false` sets no timeout.
- [x] Integration tests:
  - A probe whose status query hangs past the deadline clears `s.probing`, so the next poll probes again and the ping arrives.
  - Every `couch` spawn on the submit, probe and ping path carries a positive timeout.
  - The legacy submit timeout message says the send is unconfirmed.

## Revisions

- 2026-10-19, close review round 1 (FIX-THEN-SHIP):
  - BR-2: the default deadline is `couch.deadline_ms()`, read per call through `document_registry.config_ms`, so the user's `agentic_submit_timeout_ms` applies. `couch.DEADLINE_MS` (the shipped value read at load) is gone. The legacy submit's message names the deadline the call actually got.
  - Minor: `couch.timed_out` keys on code 124 alone. vim.system sets 124 whenever its timer fired, so a child that traps TERM and exits 0 also counts.
  - BR-1: the Spec's status-query row was wrong. A timed-out status reads like every other failed status (the probe's documented rule, pair#437: any failure reads as nothing owed), so the band's owed mark clears until the next probe answers. It doesn't keep its last state. Making only timeouts keep the mark would split the failure rule in two; the behavior stays, and the row is corrected here.

- 2026-10-19, after round 1. The hub approved this design delta: queries get 1x, sends get 3x.
  - The rerun broke #357's 'a press joins the in-flight send'. The agentic submit's send is never killed at the submit deadline, because a kill can't tell delivered from not.
  - Queries keep 1x the submit deadline (`couch.deadline_ms`).
  - Sends get 3x (`couch.send_deadline_ms`, which is `document_registry.lost_ms`: the same ceiling #359 gives a rename before its reply counts as lost; 45 s by default). Within that window a press still joins the send; past it, a wedged Couch's send is killed.
  - The UI submit deadline is unchanged.
  - A killed send logs one line naming the recipient and the message's first line, so a later duplicate can be explained. Its stderr reads 'not confirmed within N s; it may have arrived', and the agentic band shows 'not confirmed, it may have arrived · Alt+Return resends'.
  - Accepted risk: a resend after a 45 s hang may duplicate a delivery that did land.
  - The #357 slow-send test now sleeps 2 s, not 3 s: past the 1 s submit deadline and inside the send's 3 s.

## Log

### 2026-10-19
- 2026-10-19: closed — Round-1 fixes plus the hub-approved send delta. The deadline reads the user setting on each call (unit test). Sends get 3x the submit deadline (document_registry.lost_ms); a killed send logs one line and the band shows it may have arrived (an agentic spec, red without the band line). The #357 join test passes inside the 3x window. couch.timed_out keys on code 124. The BR-1 Spec correction is under Revisions. make test-spec SPEC=modes/review and SPEC=modes/session_sync are green. Fake-backed only. The full suite is recorded on 5b58f710 via local-check. (done-when: contract moved since change-code; judged by the close review); review verdict: SHIP
- The hub approved the plan, with two checks:
  - **The callback can't fire twice when a kill and a normal exit race.** `couch.run`'s `finish` drops a second report; a unit spec feeds two reports and gets one. vim.system itself reports once, after its pipes close.
  - **Nothing blocks the UI thread.** No `:wait()` in `couch`, `session_sync`, `agentic_document`, `attention` or `document_registry`; every call is async through vim.system's exit callback.
- Finding: vim.system's exit callback waits for the stdio pipes to close (`_system.lua` `_on_exit`), so a timeout that kills only the direct child doesn't report while a grandchild holds the pipes. The real `couch` is a single Go binary (Mach-O), so a SIGTERM closes them. The fake's sleeps now end with the script, which dies by SIGTERM as couch would.
- Red check: with the default removed from `couch.run`, all three new integration tests fail; with it restored, they pass. The probe test first passed unfixed, because duplicate attaches on open spawn a second probe. It now waits on a timed-out result.
- Targeted runs: `make test-spec SPEC=modes/review` (couch_spec) and `SPEC=modes/session_sync`, all green.
