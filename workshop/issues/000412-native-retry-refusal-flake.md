---
id: 000412
status: open
deps: []
github_issue:
created: 2026-10-22
updated: 2026-10-22
estimate_hours:
collaboration-mode: collaboration
card_mirror: '8b1aff4acc71304554ef77b01df4d4220d4bcb18' # card fields mirrored from issue-cards; edit via sdlc
---

# Investigate native o-retry refusal flake on Neovim 0.11

## Problem

During #410 verification, Neovim 0.11.7 intermittently failed the existing `session-sync native edits retries refused admission with native o entry (#408 retry)` case in `tests/integration/session_sync_native_spec.lua`. The failure is in `refuse_insert_entry`, before the o-retry itself: after queuing native I and observing mode i, `assert.is_false(vim.bo.modifiable)` received true. Other retry keys and all remaining existing native cases passed. The new #410 late-autosaved baseline failure in that run is a separate, reproduced defect being fixed in #410.

The failing run used #410 code head c9dd02bb8d2b47b60b75e1f5b97209bcead7fb61: 151 pass, 2 fail, 0 errors across the native file (the second failure was the separate baseline defect). An isolated rerun of the same o-retry case on the same operator runtime, deliberately delaying the fake producer by 200 ms, passed 1/0/0. That rerun included unrelated in-progress #410 adoption/deadline corrections, so it is not claimed as exact-head fail-to-pass registry evidence. A subsequent corrected-head focused run also passed the o case with the pending-input matrix and Couch/architecture checks (80 cases total, zero failures/errors).

The initial failure captured only modifiable=true; it did not capture admission outcome, notifications, per-case duration or instantaneous machine load. Do not infer held refusal versus the approved 500 ms unavailable fallback from this observation. #410 adds notification/mode diagnostics to that assertion without changing its oracle. The tests share the workstation with other slots; elapsed suite times and current load are appended below, explicitly distinct from missing failure-time measurements.

## Spec

Identify whether native mode becomes observable before admission settles, or the fake producer legitimately exceeds its 500 ms budget under contention. Use explicit admission/process evidence and a reproducible controlled schedule. Preserve native I/o recovery coverage and the real refusal policy; do not weaken assertions or silently accept a retry pass.

## Done when

- Controlled reproduction distinguishes early observation from actual unavailable/refused/confirmed admission, with timing and load recorded.
- Test waits on the appropriate completed event and still fails when refusal protection is removed, or a demonstrated product defect is fixed with native regression coverage.
- The operator runtime and preferred runtime both pass; another load-sensitive failure records full diagnostics.
- Register the exact Lua identity once ariadne#556 provides a typed Lua flake registry/resume path. No Go test identity is fabricated.

## Plan

- [ ]

## Log

Filed unclaimed at TL direction (Couch 97e1636a-a721-4076-a494-410d5296969b). TL explicitly said not to block #410 on this separate case. Until ariadne#556 lands, a recorded suite failure on this exact case allows one evidenced rerun under that instruction. No other unknown failure is covered by that exception.

Local evidence: `/tmp/parley-410-native-operator.log`, `/tmp/parley-410-refusal-red.log` (despite its diagnostic filename, outcome PASS), `/tmp/parley-410-corrections-operator.log`. Durable numeric results above remain understandable if temporary logs expire.

Log creation/modification times: native operator run 2026-10-22 12:06:50–12:07:50 -0700 (60 seconds for the complete file); isolated delayed-producer case 12:12:10–12:12:12 (2 seconds). These are whole-command/file observations, not per-case duration. Current load sampled at 12:13 -0700 was 20.35 / 33.58 / 39.16 (1/5/15-minute averages); load at the failure itself was not sampled.
