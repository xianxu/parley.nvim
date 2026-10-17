---
id: 000372
status: codecomplete
deps: []
github_issue:
created: 2026-10-17
updated: 2026-10-17
estimate_hours:
collaboration-mode: collaboration
card_mirror: '45d3ad53a731705e126c83fc186dcf350b7c63a5' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-17T05:19:56-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "7ff47f0f", done: "c59f7fa3"}
actual_hours: 0.32
---

# owned-move spec: a reopened buffer shows the source identity after Couch confirms the tree-door rename (flake)

## Problem

In `tests/integration/agentic_document_owned_move_spec.lua`, the case "moves an unloaded registered ordinary file through the public tree door" fails intermittently at line 224 (`assert.equals(new_path, document.identity(reopened).File)`). The reopened buffer's identity still names the source path (`…/source/ordinary.md`), even though the case has just awaited Couch's registry reporting the document registered at the new path.

- First seen during #359's build: one failure, then 9 consecutive passes and green suites. Seen again on 2026-10-17 during #361's full suite on d59f6407024926a27b621aa36ef55d16773fde3: 15 of 16 cases passed; #361 touches nothing on the move path.
- Retained log: `/Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/8ea1c8ed7dcdf4dd7b71ee92f8b6d396.log`.

Likely mechanism (unverified): the case waits on the registry (`lookup(new_path)`), but the loaded buffer adopts the new `File` only when the rename reply's reconcile effect runs on the main loop. A registry that already answers "registered at NEW" is earlier evidence than the buffer having adopted it. Either the spec awaits the wrong observable, or #359's adoption path has an ordering gap where a reopen reads the old identity.

## Spec

Decide which side is wrong with a deterministic ordering: hold the rename reply (for example `FAKE_COUCH_REGISTRY_DELAY` limited to the rename op) so the registry's answer and the buffer's adoption land in a controlled order. If a reopened buffer can show the old identity after Couch has confirmed the new one, that is a product defect in #359's adoption; fix it there. Otherwise the spec awaits the buffer's identity.

## Done when

- A controlled ordering reproduces the line-224 state, or shows it is unreachable from the product's side.
- The fix is at the cause, with a deterministic regression; the focused spec and the full suite pass.

## Plan

- [x] Fake: `FAKE_COUCH_REGISTRY_REPLY_DELAY` (+ `_OPS`), applied after the change is published and the lock released.
- [x] Check the adoption ordering in the product (the TL's question): not a defect, see Log.
- [x] The tree-door case holds the rename reply 0.5 s and awaits the buffer's adopted identity before checking the registry.
- [x] Sweep the spec for the same order (registry first, then an immediate identity read).
- [x] Full suite, close.

## Log

### 2026-10-17
- 2026-10-17: closed — Not a product gap: the editor adopts NEW only from the rename reply (document_session, then finish_move, then metadata_done) and shows done only after adopting. Spec race: Couch publishes before it replies; the case polled the registry, then read the buffer identity a tick early. Repro: the new FAKE_COUCH_REGISTRY_REPLY_DELAY (after publish and lock release) with _OPS=rename made the old case fail 3/3 at the identity assertion. Fix: the case holds the reply 0.5 s and awaits the adopted identity before checking the registry; 16/16 five runs in a row; the sweep found no other registry-then-identity read. Suite on b4a3befa: exit 0 in 2m26s, first attempt.; review verdict: SHIP

## Log

### 2026-10-17 — a spec ordering race, not a product adoption gap

- Product order (the TL's question, checked first): the buffer adopts NEW only from the rename reply. `document_session` sets `state.registration` from `result.registration` and emits `finish_move`, which moves `s.path`, re-caches and then calls `metadata_done`, the only path to the "moved" band. So the editor never reports confirmation before it adopts. Until the reply arrives, the rename operation is in flight, the band says "moving: confirming with Couch", and the journal holds the step. The old `File` there is the editor's honest view, not a stale claim.
- Spec order: Couch is a separate process that publishes the rename before its reply travels. The case polled the registry (`lookup(new_path)`) and then read `document.identity` at once, so whenever the registry won the race by more than a tick, line 224 saw the source path.
- Deterministic reproduction: the new `FAKE_COUCH_REGISTRY_REPLY_DELAY=1` with `_OPS=rename` publishes and releases the lock, then holds the reply. The original case then failed 3/3 at the identity assertion. The fake used to print its reply while holding the state lock, which would also have blocked the spec's own lookups; the delay sits after the lock.
- Fix: the case keeps a 0.5 s reply delay, so it always crosses the window, and awaits the buffer's identity adopting NEW (the editor's confirmation) before checking the registry. 16/16, five runs in a row.
- Sweep: the other cases in the spec already await `identity.File == new_path` or wait for `status(buf).operation` to clear first. The legacy-move case compares only the ID, which a rename doesn't change. No other site reads the identity right after a registry await.
- The suite on #361's heads hit this in 3 of 5 runs (d59f6407 attempt 1, 12105c27 attempt 1, and #361's merge on cfcbd279), so it blocked every parley landing.
