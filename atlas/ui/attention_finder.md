# Spec: Attention Finder (#354)

Every file submitted with Alt+Return that Couch accepted, and every new side doc the agent writes for one, is listed as **waiting**, **answered** or **seen**, so the operator can find what came back. Open it with `<M-Space>` (Alt+Space), `<C-y><Space>` or `:ParleyAttention` (configured by `global_shortcut_attention`).

## States
- One pure transition, `attention_model.transition`, owns every change. States are derived, never stored:
  - **waiting**: some submit's message ID is still in the file's Couch `Owed`;
  - **answered**: nothing is owed, and the file hasn't been opened from the finder since;
  - **seen**: opened from the finder after its last answer.
- Answered means the agent folded the submit (`couch --session-sync write --fold ID`). A chat reply alone leaves it waiting.
- An observation removes only the IDs captured when its probe started, so a stale probe can't answer a newer submit. A failed probe only marks the entry `unknown`.
- A new submit resets the entry to waiting. A seen entry leaves `attention.seen_grace_minutes` (default 60) after it was opened. Answered and waiting entries never expire.
- The bound is 256 entries: seen go first, then answered. Waiting entries are never dropped; when all 256 are waiting, a new file's submit is refused with a warning.

## Side docs
- A new side doc the agent writes is listed as **answered**, marked `↳`, and leaves by the same rule. On every open, `attention.discover` scans the `.side/` folder of each entry: a `*.md` with frontmatter `type: side-doc`, written after its parent entered the finder, becomes a `discovered` event (applied as one `batch`). Side docs are entries, so their own `.side/` folders are scanned on the next open.
- "New" means modified after its parent entered the finder: a side doc that predates its parent's entry counts once the agent rewrites it. A side doc that leaves is `retired` (at most 256), so a scan never brings it back, rewritten or not. The frontmatter is read through `frontmatter.parse` and the folder through `document_move_plan.side_path`. Parley sees no agent writes, so this is a scan when the operator looks, not a file watcher.
- Cost on open: the sweep write, then a synchronous scan of at most 256 `.side/` folders (40 head lines per new candidate), then one batch write, before the rows render.

## Recording
- The one hook is in `session_sync`'s `release_and_send`, which both Alt+Return paths reach (agentic documents via `send_registered`, and `type: session-sync` files). It takes the breadcrumb through #353's `file_history.snapshot(win)` before sending, and calls `attention.record` when the send succeeds, before the engine's stale-state guard.
- The message ID is parsed from `couch --send-to`'s receipt line (`<ID> <from> -> <to> <status>`). With no ID, nothing is recorded and that is warned.
- `process-instruction:` sends aren't recorded, because nothing folds them.

## Finder
- Opening it sweeps the store, then lists the stored entries at once through `float_picker`. The rows come from `attention_rows.items`: `<state> [?] <name>  <dir>  <HH:MM>`, newest submit first, each highlighted whole as `ParleyAttentionWaiting`, `ParleyAttentionAnswered` (bright, `Title`) or `ParleyAttentionSeen` (dim, `Comment`). Typing filters by name and directory.
- `attention.refresh` then probes every waiting entry with `couch --session-sync status --json PATH`, at most 4 at a time. Each probe captures the entry's pending IDs as it starts. `attention.observation` turns the reply into an event; only a reply that has a ledger for the file is evidence. A failed call, or a file Couch keeps no ledger for, marks the row `?` and leaves its state alone. The open picker repaints as each result lands, keeping the cursor on its row. Results that land after the finder closed still reach the store.
- Selecting an entry opens its file in the current window (a missing file is reported, and nothing opens), applies `opened` (an answered entry becomes seen; a waiting one stays waiting), and calls `file_history.restore(win, breadcrumb)` through #353's seam. If the restore refuses, the ordinary open result stands and the reason is shown; the finder never reads snapshot fields.

## Store
- `state_dir/attention/attention.json`, written atomically under `document_lease("attention", "store")`, re-reading the file first. The lease is non-blocking: a busy lease is retried up to 10 times, 25 ms apart, then the lost record is warned.
- The file is parsed into typed entries at the read, with one warning for whatever was dropped. It is listed in `tests/helpers/sidecars.lua`.

## Tests
- `tests/unit/attention_model_spec.lua`: table-driven events × states, seeded random sequences with properties, the stale probe, and the bound.
- `tests/unit/attention_store_spec.lua`: the parse boundary, a held lease, the sweep, and the full refusal.
- `tests/unit/attention_rows_spec.lua`: one row per state, order, and the `?` marker.
- `tests/integration/attention_finder_spec.lua`: each user path against the fake Couch, the probe limit, the grace, and late observations.
- `tests/integration/attention_record_spec.lua`: both Alt+Return paths through the fake Couch (`tests/helpers/fake_couch.lua` prints receipt IDs; with `FAKE_COUCH_OWED` its registry owes them, and `fake_couch.fold` folds one).
