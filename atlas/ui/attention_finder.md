# Spec: Attention Finder (#354)

Every file submitted with Alt+Return that Couch accepted, and every new side doc the agent writes for one, is listed as **waiting**, **answered** or **seen**, so the operator can find what came back. Open it with `<M-Space>` (Alt+Space), `<C-y><Space>` or `:ParleyAttention` (configured by `global_shortcut_attention`).

## States
- One pure transition, `attention_model.transition`, owns every change. States are derived, never stored:
  - **waiting**: some submit's message ID is still in the file's Couch `Owed`;
  - **answered**: nothing is owed, and the file hasn't been opened from the finder since;
  - **seen**: looked at after its last answer: opened from the finder, or viewed in a window (`viewed(path, at)`: focusing a window on the file, or moving the cursor or scrolling in it while it is current). A view counts only if it comes after the answer was observed.
- Answered means the agent folded the submit (`couch --session-sync write --fold ID`). A chat reply alone leaves it waiting.
- An observation removes only the IDs captured when its probe started, so a stale probe can't answer a newer submit. A failed probe only marks the entry `unknown`.
- A new submit resets the entry to waiting. A seen entry leaves `attention.seen_grace_minutes` (default 60) after it was seen. Answered and waiting entries never expire.
- The bound is 256 entries: seen go first, then answered. Waiting entries are never dropped; when all 256 are waiting, a new file's submit is refused with a warning.

## Side docs
- A new side doc the agent writes is listed as **answered**, marked `↳`, and leaves by the same rule. On every open, `attention.discover` scans the `.side/` folder of each entry: a `*.md` with frontmatter `type: side-doc`, written after its parent entered the finder, becomes a `discovered` event (applied as one `batch`). Side docs are entries, so their own `.side/` folders are scanned on the next open.
- **Agent writes (#367).** An agent write is a file mtime that the operator's editor did not write. Every BufWritePost of a file in a `.side/` folder records its mtime (`"sec.nsec"`) in the store's `saved` map, the event `saved`. That store is the one file every parley Neovim shares, so a save in Couch's pane reads as the operator's in the other editor too. `attention_model.scan` owns the rule, given each `*.md` in the folder with its mtimes:
  - **new** (neither an entry nor retired): an agent write after its parent entered the finder becomes `discovered`. A side doc that predates its parent's entry counts once the agent rewrites it; one the operator creates and saves is not listed.
  - **retired** (it left the finder; at most 256): an agent write after it retired becomes `discovered`, which un-retires it.
  - **seen**: an agent write after the operator saw it becomes `rewritten`, so it is answered again. A write to a waiting or answered entry changes nothing.
  - `saved` records only `*.md` files directly in a `.side/` folder, and on every save keeps only the ones a scan can still ask about (of an entry, of a retired path, or in an entry's `.side/` folder), at most 512, newest first.
- Answer docs are side docs too (every one carries `type: side-doc` in a `.side/` folder), so this one rule covers them. The frontmatter is read through `frontmatter.parse`, only for the files the rule picks, and the folder through `document_move_plan.side_path`. Parley sees no agent writes directly, so this is a scan when the operator looks, not a file watcher.
- Limits:
  - An edit made outside this editor, or in a Neovim without parley, counts as an agent write.
  - mtimes are compared at whole seconds against `seen_at`, so an agent write in the same second as the operator's view is missed.
  - Only the `.side/` folders of current entries are scanned: a side doc whose parent has also left comes back with the parent's next submit.
  - Past 512 kept saves the oldest is dropped, and that file then reads as agent-written on its next scan.
  - A store written before #367 has no `saved` map: a seen or retired side doc the operator had edited reads as agent-written once, on the first open after the upgrade.
- Cost on open: the sweep write, then a synchronous scan of at most 256 `.side/` folders (a stat per file, and 40 head lines for each file the rule picks), then one batch write, before the rows render.

## Recording
- The one hook is in `session_sync`'s `release_and_send`, which both Alt+Return paths reach (agentic documents via `send_registered`, and `type: session-sync` files). It takes the breadcrumb through #353's `file_history.snapshot(win)` before sending, and calls `attention.record` when the send succeeds, before the engine's stale-state guard.
- The message ID is parsed from `couch --send-to`'s receipt line (`<ID> <from> -> <to> <status>`). With no ID, nothing is recorded and that is warned.
- `process-instruction:` sends aren't recorded, because nothing folds them.

## Finder
- **Slot scope (#388):** the accepted send receipt's sender is stored as `slot`, independently of its recipient/owner. Each file still has one entry: its latest submit sets its slot and breadcrumb, while older pending IDs remain tracked. Newly discovered side docs inherit their parent's current slot; existing entries retain theirs until resubmitted.
- Opening resolves the pane through `couch.own_slot`. The default shows this slot plus legacy entries without a slot. Ctrl+A (`attention_finder_mappings.toggle_scope`, registered as `attention_scope`) toggles current/all slots, named in the title; each open resets to current. Outside Couch shows all. If a live pane cannot be resolved, show all and warn to reopen. Scope is presentation only: discovery, probes, seen/saved tracking and one leased store remain shared. Filtering adds one O(N) pass before the existing sort, N at most 256; late probe repaints retain the chosen scope, query and surviving selection.
- The file in the current window is left out: it is already in front of the operator.
- `attention.setup()` installs the view autocmds (augroup `ParleyAttentionViews`). They check an in-memory set of answered paths before touching the store, so a cursor move stays cheap.
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
