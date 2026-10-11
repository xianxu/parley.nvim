---
id: 000314
status: working
deps: []
github_issue:
created: 2026-10-10
updated: 2026-10-10
estimate_hours:
card_mirror: 'eb349e8df26c6a59b9694975f0c44a7c96bda062' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-10T23:41:27-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "81a79b3d", done: "64344d3a"}
---

# Session-sync hardening: no reload prompt under the operator's lock, complain to the agent, a 'TL owes' band, and a liveness ping

## Problem

On 10-10 the ops TL wrote the session-sync status file while the operator held the lock (ops learnings kink 60). The
buffer has `autoread` on and no `FileChangedShell` handler, so nvim looped "WARNING: The file has been changed since
reading it!!! Do you really want to write to it (y/n)?" on every key that wasn't y or n. Separately, the TL ended a
turn without folding the operator's submit into the file, and nothing showed the operator that the TL owed a response.
The operator (10-10): parley is a good second line of defense, and keep it agent-neutral.

## Spec

- **Under the operator's lock, an external write never prompts.** A `FileChangedShell` handler keeps the operator's
  buffer (`v:fcs_choice = ""`), marks the buffer "agent wrote under your lock" in the band, and sends the owner one
  couch message naming the violation. The operator's next save wins without a W12 prompt (the buffer records the
  disk version it overrode, so nothing is silently lost: e.g. keep it as `<file>.clobbered` beside the file).
- **"TL owes a response, N min."** While the lock is held by `agent` after a submit, the band counts the minutes.
- **Liveness ping.** Parley pings the owner (`couch --send-to <owner>`, once per episode) when **owed work** is
  older than 5 minutes **and the owner's turn has ended**:
  - Owed work: the agent holds the lock after a submit, or `couch --session-sync status --json` (pair, filed
    alongside) lists owed deliveries.
  - Turn ended: `couch --actors --json` reports the owner's `Resting: true`. A ping mid-turn would only queue.
  - No ping when nothing is owed, however stale the file, and no ping to a slot that isn't live.
  - Until the pair verb lands, use only the lock condition.
- The ping is a session-sync-originated message; pair's breaker work (pair#433) should count it like a submit, not
  spend the TL's allowance.

## Done when

- [x] An external write while the operator holds the lock: no prompt, buffer kept, band flagged, one message sent (test).
- [x] The band shows "TL owes a response, N min" while the agent holds the lock (test).
- [x] The ping fires once when owed for 5 minutes with the owner quiet (turn ended), and not while it's mid-turn or owes nothing (test with fake couch).

## Plan

Durable plan: `workshop/plans/000314-session-sync-hardening-plan.md`.

- [x] Watch in every turn; violation handler (FileChangedShell, watch, submit); band flag; one complaint.
- [x] Agent band: "<owner> owes a response, N min".
- [x] Liveness ping behind the couch seam (lock condition + `--session-sync status --json`, `--actors --json` Resting), once per episode.
- [x] Tests (fake couch), atlas.

## Log

### 2026-10-10

- Dispatched by ops:0. JSON shape for pair#437 `status --json` proposed to ops:0 and relayed to pair:5; the TL said proceed behind the seam. pair#433 keys the breaker on sender binding, so the ping/complaint (same nvim as submit) need no marker.
- Verified headless: buffer-local FileChangedShell with `fcs_choice=""` keeps the buffer without prompting; `:write!` then overwrites without W12, and later `:w` is quiet.
- Close review round 1 (REWORK). BR-1: couch JSON nulls decoded to vim.NIL and crashed the probe with `probing`
  stuck. Fixed for the class: every couch query decodes with `luanil` and each list is type-guarded (`list`,
  `find_actor`); test feeds nulls and proves the probe recovers. BR-2: `violation` ignored a failed copy. It now
  distinguishes deleted (restore, claim nothing kept), copied (restore), and copy-failed (never overwrite; adopt the
  disk mtime so no retry loop; a later save meets Neovim's own prompt); band and message say which. Minors: the
  violated flag now carries its outcome, not a bare boolean; the fake couch's conformance check waits for pair#437
  to land (the verb doesn't exist yet); README never documented session-sync (atlas does), left as is.
- Watch now stops on an unloaded buffer: `:bdelete` never fires BufWipeout, so the always-on watch kept handling a
  closed file (found from a stray notice in the suite).

## Revisions

- 2026-10-10 (TL correction via ops:0, overrides the dispatch and the Spec's "Turn ended" bullet): `Resting` in
  `couch --actors --json` means the slot is on its resting branch, not that its turn ended (ops:0 reads
  `Resting: true` mid-turn). The owner's turn has ended when `now - LastActivity >= 30 s` (couch's QuietInterval,
  the rule couch routing uses).
