# #314 Session-sync hardening — plan

Issue: `workshop/issues/000314-…-liveness-ping.md`. Builds on #313 (`lua/parley/session_sync.lua`).
Single pass, one close (no Mx).

## Verified premises (headless nvim, 2026-10-10)

- A buffer-local `FileChangedShell` that sets `v:fcs_choice = ""` suppresses every prompt and keeps the
  modified buffer (`fcs_reason = "conflict"`).
- `:write!` then overwrites the newer disk file without the W12 "changed since reading it" prompt, and a later
  plain `:w` is quiet (the buffer's recorded mtime is current again).

## Design

### 1. A write under the operator's lock (violation)

`violation(buf)`, the one handler, reached from two detectors:
- the **watch**, which now runs in every turn (it was closed during the operator's turn — that is why the
  violation went unseen until a save prompted). In the operator's turn a tick with `disk_changed` is a violation.
- a buffer-local **`FileChangedShell`** (focus/`checktime`): in the operator's turn it sets
  `v:fcs_choice = ""` and schedules `violation` (no buffer writes inside the autocmd); otherwise it sets
  `"reload"` for an unmodified buffer and `"ask"` for a modified one (Neovim's default behaviour with autoread).
- `submit` in the operator's turn with `disk_changed` runs `violation` first instead of refusing (the
  operator's lock wins). Outside the operator's turn it still refuses.

`violation(buf)`: copy the disk file to `<file>.clobbered` (nothing silently lost), `silent write!` the
operator's buffer (the lock-holder's copy is restored at once, so no later save prompts), mark
`s.violated` (band: `agent wrote under your lock; theirs is in <name>.clobbered`, in the operator colour), and
send the owner **one** couch message per operator turn:
`session-sync violation: <path> was written while the operator held the lock; the operator's copy was kept,
yours is at <path>.clobbered`. `s.violated` / the complaint flag reset when the turn leaves the operator.

Note vs. the issue's spec wording "the operator's next save wins": the restore *is* that save, done at
detection, so the disk never shows the violating copy while the operator types; any unsaved operator edits are
saved with it (the operator holds the lock, so that is their file).

### 2. "`<owner>` owes a response, N min"

The agent view's label becomes `%s owes a response, %d min, read-only`; N = whole minutes since the lock
file's mtime (written at submit). The watch re-renders when N changes.

### 3. Liveness ping (seam: the `couch` binary on PATH)

Config `session_sync_ping_minutes = 5`. At most once per `M.PING_CHECK_MS` (60 s) per buffer, one probe at a
time (in-flight guard), from the watch:
1. **Owed since** = the earliest of: the lock's mtime when the agent holds the turn (lock condition, local),
   and the oldest `Status.Owed[].At` from `couch --session-sync status --json FILE` (pair#437). A non-zero
   exit, unparsable JSON or `Code ~= "ok"` (verb not landed) → lock condition only.
2. Nothing owed, or owed for less than the threshold → stop.
3. Episode = the owed-since time; already pinged for it → stop.
4. `couch --actors --json`: the owner's actor (exact `Slot`, else the unique slot whose repo part starts with the
   owner's repo part and whose index matches). Missing / not `Known` → not live, no ping. `Resting ~= true` →
   mid-turn, no ping (retry next probe).
5. Re-check the buffer state is still this probe's (lesson #313 BR-1), then
   `couch --send-to <owner> --message "session-sync ping: <path> owes a response since <RFC3339>"` and record the
   episode.

JSON shape agreed through ops:0 (proposed by parley:1, relayed to pair:5; the TL said proceed):
`{"Code":"ok","Error":"","Status":{"File","Owner","Holder","LastWrite","Owed":[{"ID","Kind","From","At"}]}}`.
Parley reads only `Code` and `Owed[].At` (RFC3339 → epoch via a small parser, offset-aware).

### ARCH notes

- ARCH-FUNERAL: `<file>.clobbered` — created by `violation`, last needed by the agent reading the complaint;
  bounded to one file per session-sync file (overwritten by the next violation), removed by the agent or the
  operator. Timers: the watch now lives for the buffer's life (closed on BufWipeout); probes are one-shot
  processes with an in-flight guard. Ping episodes are in-memory.
- Async completions (status, actors, send) re-check `state[buf] == s` before acting (lesson #313 BR-1).

## Steps

- [ ] Watch in every turn; `violation` + FileChangedShell + submit path; band flag; one complaint.
- [ ] Agent view: owes N min, re-rendered as N changes.
- [ ] Ping probe (status seam + lock condition, actors, once per episode), config key.
- [ ] Tests (integration, fake couch extended for `--actors --json` and `--session-sync status --json` from env):
  violation via watch and via FileChangedShell (no prompt, buffer kept, `.clobbered` holds the agent copy, band
  flagged, exactly one message); submit under a violation wins; owes band text with N; ping fires once when owed
  ≥ threshold and owner resting; not mid-turn; not when nothing owed; not when the owner isn't listed; status
  JSON owed (no lock) pings; a failing status verb falls back to the lock. Unit: RFC3339 parser, owner matching.
- [ ] Atlas `atlas/modes/session_sync.md`; lessons if review finds any.

### Sender identity (pair#433, via ops:0)

pair#433's breaker keys on sender binding, not text: a `couch --send-to` run from an editor inside the owner's
slot counts as an operator submit. The complaint and the ping are sent by the same nvim process as the existing
submit, so they share its binding; no new sending path (one from another slot's editor) is added.
