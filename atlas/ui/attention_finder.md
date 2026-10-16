# Spec: Attention Finder (#354)

Every file submitted with Alt+Return that Couch accepted is listed as **waiting**, **answered** or **seen**, so the operator can find what came back. M1 records the submits. M2 adds the finder (`<M-u>`, `:ParleyAttention`).

## States
- One pure transition, `attention_model.transition`, owns every change. States are derived, never stored:
  - **waiting**: some submit's message ID is still in the file's Couch `Owed`;
  - **answered**: nothing is owed, and the file hasn't been opened from the finder since;
  - **seen**: opened from the finder after its last answer.
- Answered means the agent folded the submit (`couch --session-sync write --fold ID`). A chat reply alone leaves it waiting.
- An observation removes only the IDs captured when its probe started, so a stale probe can't answer a newer submit. A failed probe only marks the entry `unknown`.
- A new submit resets the entry to waiting. A seen entry leaves `attention.seen_grace_minutes` (default 60) after it was opened. Answered and waiting entries never expire.
- The bound is 256 entries: seen go first, then answered. Waiting entries are never dropped; when all 256 are waiting, a new file's submit is refused with a warning.

## Recording
- The one hook is in `session_sync`'s `release_and_send`, which both Alt+Return paths reach (agentic documents via `send_registered`, and `type: session-sync` files). It takes the breadcrumb through #353's `file_history.snapshot(win)` before sending, and calls `attention.record` when the send succeeds, before the engine's stale-state guard.
- The message ID is parsed from `couch --send-to`'s receipt line (`<ID> <from> -> <to> <status>`). With no ID, nothing is recorded and that is warned.
- `process-instruction:` sends aren't recorded, because nothing folds them.

## Store
- `state_dir/attention/attention.json`, written atomically under `document_lease("attention", "store")`, re-reading the file first. The lease is non-blocking: a busy lease is retried up to 10 times, 25 ms apart, then the lost record is warned.
- The file is parsed into typed entries at the read, with one warning for whatever was dropped. It is listed in `tests/helpers/sidecars.lua`.

## Tests
- `tests/unit/attention_model_spec.lua`: table-driven events × states, seeded random sequences with properties, the stale probe, and the bound.
- `tests/unit/attention_store_spec.lua`: the parse boundary, a held lease, the sweep, and the full refusal.
- `tests/integration/attention_record_spec.lua`: both Alt+Return paths through the fake Couch (`tests/helpers/fake_couch.lua` prints receipt IDs; with `FAKE_COUCH_OWED` its registry owes them, and `fake_couch.fold` folds one).
