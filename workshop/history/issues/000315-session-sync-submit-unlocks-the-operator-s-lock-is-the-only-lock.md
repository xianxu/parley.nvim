---
id: 000315
status: done
deps: []
github_issue:
created: 2026-10-11
updated: 2026-10-11
estimate_hours:
card_mirror: 'a407a624dfe60e5129947a549a911ecadbf7be77' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-11T09:10:41-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "93f99eaf", done: "96fd1f6c"}
actual_hours: 0.42
---

# session-sync: submit unlocks; the operator's lock is the only lock

## Problem

On submit (Alt+Return in a session-sync file), parley rewrites the lock's holder from `operator` to `agent` and makes the buffer read-only until the agent releases it. If the agent forgets to release, the operator is locked out of their own file: on 10-11 the TL held the ops status file from 08:03 to about 09:00 and the operator couldn't add a comment (ops learnings, ariadne-robustness-1 kink 65). pair#439 removes the agent-held lock from Couch; parley must stop creating it.

## Spec

Design principle, the operator's (10-11): **pessimistic locking for the human, optimistic for the agent.**

- **The operator's lock is the only lock.** parley writes `<file>.lock` (holder `operator`) at the first edit, exactly as today, and holds it until submit.
- **Submit = save, delete the lock, send the submit message.** No `holder: agent` rewrite, no read-only buffer. The operator can keep reading and editing right after submitting; their next keystroke takes the lock again.
- **Agent writes land while the buffer is clean:** parley reloads the buffer silently (no prompt) when the file changes on disk and the buffer has no unsaved changes. The race (the agent writes just as the operator starts typing) keeps parley.nvim#314's `.clobbered` path: the operator's text is kept and the band flags it.
- **The band:** "<owner> owes a response, N min" is driven by Couch's owed events (`couch --session-sync status --json`, oldest `Owed[].At`), not by a lock holder. With no owed events and no lock, the band is neutral.
- **The liveness ping** (parley.nvim#314) keys off owed events only, not the lock.
- A legacy `holder: agent` lock on disk is treated as no lock (deleted on the operator's first keystroke).

Independent of pair#439's landing order: with today's Couch, a missing lock already lets the agent write, so this can land first.

## Done when

- After submit, `<file>.lock` is gone and the buffer is editable (test).
- An agent write while the buffer is clean reloads it without a prompt; while the operator holds the lock, the agent write refuses (Couch) and nothing in nvim prompts.
- The owes-a-response band and the ping come from owed events alone (test with a fake `status --json`).
- A stale `holder: agent` lock doesn't block the operator.

## Plan

- [x] Submit: save, delete the lock, send `submitted: <path>`; drop the holder rewrite and the read-only switch.
- [x] Clean-buffer silent reload on external change; keep the `.clobbered` path for the race.
- [x] Band and ping from owed events only; treat a legacy agent lock as none.
- [x] Tests for the Done-when rows; update the session-sync doc/atlas.

Core concepts:

| Name | Where | Role | Status |
|---|---|---|---|
| `turn` | `lua/parley/session_sync.lua` | lock text → `free` / `operator`; a legacy agent lock reads as free | modified |
| `view` | `lua/parley/session_sync.lua` | adds the `owed` state; operator states outrank it | modified |
| `owed_minutes` | `lua/parley/session_sync.lua` | minutes since couch's oldest owed event, or nil | new |
| `violation` | `lua/parley/session_sync.lua` | gains the race wording for a write just before the first edit | modified |
| `lock_minutes` | `lua/parley/session_sync.lua` | the agent-lock age that fed the old band | deleted |
| `unlock` | `lua/parley/session_sync.lua` | `<C-g>u` escape from an agent lock | deleted |

Design notes:
- Turn is `free` | `operator` only; `M.turn` reads a `holder: agent` lock as `free`. The first keystroke's `write_lock(operator)` overwrites it.
- The race (disk changed before the first keystroke took the lock) now takes the lock and goes through `violation()` with its own wording ("changed as you started typing"), instead of reloading and dropping the keystroke: the human's text is kept, the agent's optimistic write is set aside in `.clobbered` and the agent is told.
- A failed send leaves the file free (no lock to restore); the error says Alt+Return resends. The submit-generation guard goes with it.
- `<C-g>u` unlock is removed (config key, registry entry, init binding): with no agent lock there is nothing to unlock.
- Band: `owed` view (`<owner> owes a response, N min`, group `ParleySessionSyncOwed`) when no operator lock and couch reports owed events; operator states outrank it. `s.owed` = oldest `Owed[].At` from the latest status probe (nil on failure). The probe runs at most once per PING_CHECK_MS, and again right after a successful submit and after a reload, so the band follows within one tick.
- Durable artifacts: none new; the lock is now created at first edit and deleted at submit (or overwritten by a later edit).

## Log

### 2026-10-11
- 2026-10-11: closed — make test exit 0 (424 spec files pass, luacheck clean); session_sync specs 35/35 cover: submit deletes lock + buffer editable + one submitted: send; failed send leaves file free; clean-buffer silent reload via watch and :checktime; legacy holder:agent lock does not block; first-edit race keeps operator text with .clobbered; owed band and ping from fake couch status --json only (lock alone never owes); review verdict: SHIP

- Claimed and started on parley.nvim:1 from the TL dispatch; design notes in ## Plan.
- Implemented: turn is free/operator; submit saves, deletes the lock and sends; owed band + ping read couch's owed events only (probe forced after submit and reload); the first-edit race goes through `violation(buf, true)`; `<C-g>u` unlock removed (config, registry, init, atlas). `make test-spec SPEC=modes/session_sync`: 35/35 pass.
- The arch sweep `every symbol the Spec and plan tables name exists` needs a Core-concepts table on an issue branch; added one to ## Plan.
