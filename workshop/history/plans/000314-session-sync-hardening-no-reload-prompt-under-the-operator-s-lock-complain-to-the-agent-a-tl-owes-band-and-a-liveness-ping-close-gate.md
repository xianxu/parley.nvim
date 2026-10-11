---
gate: boundary-review
issue: 314
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-10-11T00:07:14-07:00"
      dispatched: "2026-10-11T00:04:58-07:00"
      agent: claude
      findings:
        - id: BR-1
          severity: Critical
          title: Probe crashes on JSON null (Owed/Status/Actors/Binding) and leaves s.probing stuck, disabling pings for the buffer
          detail: vim.json.decode maps null to truthy vim.NIL; `Owed or {}` passes it to ipairs, which raises (verified headless). A Go nil slice encodes as null. Decode with luanil, type-check tables, and reset probing on all paths; add a fake-couch test with Owed:null / Actors:null.
          family: untrusted-json-shape
          round: 1
        - id: BR-2
          severity: Important
          title: violation() ignores fs_copyfile failure, then write! overwrites the agent copy and the message names a missing or stale .clobbered
          detail: lua/parley/session_sync.lua:276-280. Check the copy result; handle a deleted file explicitly; do not claim a copy that was not made. Add a test where the agent deletes the file under the lock.
          family: unchecked-io-before-destructive-write
          round: 1
        - id: BR-3
          severity: Minor
          title: Per-buffer state grows as loose booleans (violated/complained/probing/pinged) with unwritten legal combinations
          detail: 'ARCH-ORDER: fold violated/complained into the operator-turn state rather than parallel flags.'
          family: flag-constellation-state
          round: 1
        - id: BR-4
          severity: Minor
          title: Fake couch (--actors/--session-sync status) has no conformance check against the real binary
          detail: The Resting misreading in Revisions is exactly the drift such a check catches; add one when pair#437 lands.
          family: fake-without-conformance
          round: 1
        - id: BR-5
          severity: Minor
          title: README does not document session-sync or its config keys (session_sync_ping_minutes added)
          family: readme-surface-gap
          round: 1
      recipe: milestone-review
      blocked: true
    - "n": 2
      timestamp: "2026-10-11T00:10:35-07:00"
      dispatched: "2026-10-11T00:09:14-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: query() decodes with luanil and returns nil unless Code=ok; list()/find_actor type-check; probing reset on all paths; integration test with Owed:null, Status:null, Binding:null, LastActivity:null fails under the old `Owed or {}` code and passes now.
          round: 2
        - id: BR-2
          disposition: addressed
          note: violation() distinguishes deleted / copied / copy-failed; a failed copy is never overwritten and the message says so; tests for deletion and for a failed copy (directory at .clobbered) both pass.
          round: 2
        - id: BR-3
          disposition: not-addressed
          note: violated now carries the outcome text, but violated/complained/probing/probed/pinged are still independent fields, and violation() branches on its own band text.
          round: 2
        - id: BR-4
          disposition: not-addressed
          note: Reasonably deferred until pair#437 lands the verb; still open.
          round: 2
        - id: BR-5
          disposition: not-addressed
          note: README still lacks session-sync and session_sync_ping_minutes; the author declined, and atlas documents it.
          round: 2
      findings:
        - id: BR-6
          severity: Important
          title: submit hands the turn to the agent after violation() left the agent's copy on disk (copy failed)
          detail: 'This is the 2nd finding in family unchecked-io-before-destructive-write. Rule: every caller of violation() must act on its outcome. When the outcome is "copy failed", no later writer (submit, write_lock agent) may proceed. Return a tagged outcome from violation(), make submit refuse on copy-failed the way the free-turn branch refuses, and test <M-CR> after a failed copy.'
          family: unchecked-io-before-destructive-write
          round: 2
      recipe: milestone-review
      blocked: true
    - "n": 3
      timestamp: "2026-10-11T00:18:29-07:00"
      dispatched: "2026-10-11T00:17:33-07:00"
      agent: claude
      dispose:
        - id: BR-6
          disposition: addressed
          note: violation() returns whether the operator's copy is on disk; submit refuses on a failed copy (session_sync.lua:567-571). The regression test at the session_sync_spec.lua:290 failed-copy case asserts the lock stays with the operator and the agent's text stays on disk. The remaining writers (watch tick, FileChangedShell) only render.
          round: 3
        - id: BR-3
          disposition: not-addressed
          note: Still loose booleans; the new unkept field adds to the group. Minor; fold into a tagged operator-turn state later.
          round: 3
        - id: BR-4
          disposition: not-addressed
          note: Still no live conformance check for the fake couch; deferred until pair#437 lands. Minor.
          round: 3
        - id: BR-5
          disposition: not-addressed
          note: README.md is unchanged in the window; session-sync and session_sync_ping_minutes are still undocumented there. Minor.
          round: 3
      recipe: milestone-review
      reviewed: e53f5d94d977c82ff14d2341688a04215f9a4506
      blocked: false
---

# Gate ledger — parley.nvim#314 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-11T00:07:14-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Critical] `untrusted-json-shape` Probe crashes on JSON null (Owed/Status/Actors/Binding) and leaves s.probing stuck, disabling pings for the buffer
  vim.json.decode maps null to truthy vim.NIL; `Owed or {}` passes it to ipairs, which raises (verified headless). A Go nil slice encodes as null. Decode with luanil, type-check tables, and reset probing on all paths; add a fake-couch test with Owed:null / Actors:null.
- **BR-2** [Important] `unchecked-io-before-destructive-write` violation() ignores fs_copyfile failure, then write! overwrites the agent copy and the message names a missing or stale .clobbered
  lua/parley/session_sync.lua:276-280. Check the copy result; handle a deleted file explicitly; do not claim a copy that was not made. Add a test where the agent deletes the file under the lock.
- **BR-3** [Minor] `flag-constellation-state` Per-buffer state grows as loose booleans (violated/complained/probing/pinged) with unwritten legal combinations
  ARCH-ORDER: fold violated/complained into the operator-turn state rather than parallel flags.
- **BR-4** [Minor] `fake-without-conformance` Fake couch (--actors/--session-sync status) has no conformance check against the real binary
  The Resting misreading in Revisions is exactly the drift such a check catches; add one when pair#437 lands.
- **BR-5** [Minor] `readme-surface-gap` README does not document session-sync or its config keys (session_sync_ping_minutes added)

## Round 2 — 2026-10-11T00:10:35-07:00 (claude) — BLOCKED

### Disposed

- BR-1 — addressed — query() decodes with luanil and returns nil unless Code=ok; list()/find_actor type-check; probing reset on all paths; integration test with Owed:null, Status:null, Binding:null, LastActivity:null fails under the old `Owed or {}` code and passes now.
- BR-2 — addressed — violation() distinguishes deleted / copied / copy-failed; a failed copy is never overwritten and the message says so; tests for deletion and for a failed copy (directory at .clobbered) both pass.
- BR-3 — not-addressed — violated now carries the outcome text, but violated/complained/probing/probed/pinged are still independent fields, and violation() branches on its own band text.
- BR-4 — not-addressed — Reasonably deferred until pair#437 lands the verb; still open.
- BR-5 — not-addressed — README still lacks session-sync and session_sync_ping_minutes; the author declined, and atlas documents it.

### Raised

- **BR-6** [Important] `unchecked-io-before-destructive-write` submit hands the turn to the agent after violation() left the agent's copy on disk (copy failed)
  This is the 2nd finding in family unchecked-io-before-destructive-write. Rule: every caller of violation() must act on its outcome. When the outcome is "copy failed", no later writer (submit, write_lock agent) may proceed. Return a tagged outcome from violation(), make submit refuse on copy-failed the way the free-turn branch refuses, and test <M-CR> after a failed copy.

## Round 3 — 2026-10-11T00:18:29-07:00 (claude) — passed

### Disposed

- BR-6 — addressed — violation() returns whether the operator's copy is on disk; submit refuses on a failed copy (session_sync.lua:567-571). The regression test at the session_sync_spec.lua:290 failed-copy case asserts the lock stays with the operator and the agent's text stays on disk. The remaining writers (watch tick, FileChangedShell) only render.
- BR-3 — not-addressed — Still loose booleans; the new unkept field adds to the group. Minor; fold into a tagged operator-turn state later.
- BR-4 — not-addressed — Still no live conformance check for the fake couch; deferred until pair#437 lands. Minor.
- BR-5 — not-addressed — README.md is unchanged in the window; session-sync and session_sync_ping_minutes are still undocumented there. Minor.

## Open findings

- **BR-3** [Minor] `flag-constellation-state` Per-buffer state grows as loose booleans (violated/complained/probing/pinged) with unwritten legal combinations
- **BR-4** [Minor] `fake-without-conformance` Fake couch (--actors/--session-sync status) has no conformance check against the real binary
- **BR-5** [Minor] `readme-surface-gap` README does not document session-sync or its config keys (session_sync_ping_minutes added)
