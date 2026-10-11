---
id: 000315
status: open
deps: []
github_issue:
created: 2026-10-11
updated: 2026-10-11
estimate_hours:
card_mirror: '7542cc4abad2f21306500d4f5af43b3c3d65a73f' # card fields mirrored from issue-cards; edit via sdlc
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

- [ ] Submit: save, delete the lock, send `submitted: <path>`; drop the holder rewrite and the read-only switch.
- [ ] Clean-buffer silent reload on external change; keep the `.clobbered` path for the race.
- [ ] Band and ping from owed events only; treat a legacy agent lock as none.
- [ ] Tests for the Done-when rows; update the session-sync doc/atlas.

## Log

### 2026-10-11
