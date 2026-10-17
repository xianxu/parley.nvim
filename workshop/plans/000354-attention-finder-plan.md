# Attention Finder Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A floating finder that lists every file submitted with Alt+Return, newest first, as **waiting**, **answered** or **seen**. Opening an entry restores the breadcrumb it had at submit time, and seen entries leave the list after a configurable grace period.

**Architecture:**
- A pure model owns the entries and their transitions; all state changes go through one `transition(state, event, now)`.
- A store persists the model as one JSON file under `state_dir`.
- Thin glue:
  - records a submit when #332's agentic-document send succeeds, keeping Couch's message ID;
  - asks Couch which submits are still owed (`couch --session-sync status --json FILE`);
  - renders the entries in `float_picker`.

**Tech Stack:** Lua (Neovim plugin), the `couch` CLI through `parley.couch`, `float_picker`, and plenary/busted specs under `make test-spec`.

---

## Facts this design rests on

All verified in the code on 2026-10-16.

**The Couch submit path** (`agentic_document.lua:247`):
- `session_sync.send_registered` runs `couch --send-to OWNER --message "submitted: /abs/path"`.
- The send's stdout starts with the broker message ID (`<ID> <from> -> <to> <status>`, pair `couchcmd/messages.go:133`).
- That ID is the ledger row's ID, and it is the `Owed[].ID` in `couch --session-sync status --json FILE`. The status output is `{"Code":"ok","Status":{"File","Owner","Owed":[{"ID","Kind","From","At"}],...}}`; `Owed` is never null.

**When a submit counts as answered:** its ID leaves `Owed`. That happens only when the agent writes the file with `couch --session-sync write ... --fold ID`. A turn end or a chat reply does not fold. Ledger rows older than 14 days are trimmed and also leave `Owed`.

**#332's receipt is in memory only** (`document_session.lua:243`): `{namespace, id = Registration.ID, owner, hash, display_time}`. Nothing on disk records individual submits. So the finder keeps its own record.

**`float_picker.open(opts)`:**
- Items are `{display, search_text, value, highlights = {{start, finish, group}}}`.
- The returned handle has `update(items)`.

**#353's breadcrumb seam**, agreed with parley.nvim:2 on 2026-10-16 (their commit f165ed8e) and not yet landed:
- `file_history.snapshot(win)` returns an opaque, detached, JSON-safe value, or nil plus a reason.
- `file_history.restore(win, value)` opens nothing. The caller opens the file first. It validates before changing anything, drops ancestors that are really gone (a failed stat is not absence), and installs the trail and its Back entries. It returns true, or false plus a reason. On refusal, the open file stays an ordinary root.

## Core concepts

### Pure entities

| Name | Lives in | Status | Surface |
|------|----------|--------|---------|
| `attention_model` | `lua/parley/attention_model.lua` | new | `empty`, `transition`, `state_of`, `list`, `answered_unseen` |
| `attention_rows` | `lua/parley/attention_rows.lua` | new | `items` |

- **attention_model:** the entries and their transitions.
  - State: `{version = 1, entries = {[path] = Entry}}`, with `Entry = {path, pending = {[message_id] = submitted_at}, submitted_at, answered_at?, seen_at?, breadcrumb?, unknown?}`.
  - The state of an entry is derived, never stored:
    - **waiting** when `pending` is non-empty;
    - **answered** when `pending` is empty and `seen_at` is nil, or when `seen_at < answered_at`;
    - **seen** when `pending` is empty and `seen_at >= answered_at`.
  - `transition(state, event, now) -> state'` handles these events:
    - `{type="submitted", path, id, breadcrumb}`: adds `id` to `pending` and replaces `submitted_at` and `breadcrumb`. A new submit resets the entry to waiting.
    - `{type="observed", path, probed_ids, owed_ids}`: removes from `pending` every ID in `probed_ids` (the pending set when the probe started) that is not in `owed_ids`; an ID outside `probed_ids` is never removed, and sets `answered_at = now` when `pending` becomes empty. It ignores a path with no entry, and leaves alone an entry that has no pending IDs.
    - `{type="observe_failed", path, reason}`: sets `unknown = reason`. State is unchanged, because a failed probe is not evidence of an answer (ARCH-ORDER). The next successful observation clears it.
    - `{type="opened", path}`: sets `seen_at = now` only when the entry is answered. Opening a waiting entry changes nothing.
    - `{type="sweep", grace}`: removes an entry that is seen with `now - seen_at >= grace`. Waiting and answered entries never expire.
  - `M.state_of(entry)`, `M.list(state)` (newest `submitted_at` first) and `M.answered_unseen(state)` (a count) are queries.
  - **Bound:** 256 entries. When an insertion exceeds it, the oldest seen entries go first, then the oldest answered. A waiting entry is never dropped; the store refuses a submit record only when all 256 are waiting, and says so.
  - **DRY rationale:** the only owner of these rules. The finder, the store and the glue never test `pending` themselves.
  - **Future extensions:** a winbar count of answered-but-unseen entries reads `answered_unseen`.
- **attention_rows:** turns `M.list(state)` into `float_picker` items.
  - Each row is `<state> <basename> <dir> <HH:MM>`, with whole-row highlights `ParleyAttentionWaiting`, `ParleyAttentionAnswered` (bright) and `ParleyAttentionSeen` (dim).
  - An entry with `unknown` set gets a `?` marker.
  - Pure: unit-tested on strings and offsets.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `attention_store` | `lua/parley/attention_store.lua` | new | the JSON file `state_dir/attention/attention.json`: `dir`, `path`, `parse`, `load`, `apply`, `grace_seconds` |
| `couch.query` | `lua/parley/couch.lua` | modified | the couch CLI: `query` takes `options` for vim.system (the probe timeout) |
| `attention` | `lua/parley/attention.lua` | new | the couch CLI, the editor, #353's seam: `record`, `parse_message_id`, `breadcrumb`, `observation`, `refresh`, `open`, `discover`, `is_side_doc`, `viewed`, `setup`, `clock` |
| `release_and_send` | `lua/parley/session_sync.lua:802` | modified | records a submit |

- **attention_store:** `load()` and `apply(event, on_done)`.
  - `apply` takes `document_lease.acquire("attention", "store", { root = state_dir })`, re-reads the file, runs the transition, writes it with `helper.table_to_file_atomic`, and releases. Several editors may submit at once.
  - **Busy lease:** `acquire` is non-blocking (`LOCK_NB`; another holder returns `failure('busy')`). `apply` retries on `busy` with `vim.defer_fn`, at most 10 times, 25 ms apart (both injectable). After the last try it warns `attention: submit record for <file> lost (store busy)` and writes nothing. Any other failure (`unavailable`, `limit`) warns at once. A lost record is never silent.
  - **Input handling (ARCH-SECURE):** a missing, truncated or hand-edited file, or one written by a different version, is parsed into a typed state at the boundary. Anything that doesn't fit reads as empty and is reported once with a warning; it is never trusted as entries. The file joins `tests/helpers/sidecars.lua` for its corruption cases.
  - **Lifetime (ARCH-FUNERAL):** one file of at most 256 entries, each about 1 KB plus its breadcrumb. Entries leave by `sweep`, which runs on every `apply`, or by the bound.
- **attention (glue):**
  - **Where a submit is recorded:** both Alt+Return paths that send through Couch end in `session_sync`'s `release_and_send`: the agentic document's send effect (`send_registered`) and `type: session-sync` files (`review_send.submit` → `session_sync.submit` → `submit_now`). One hook there covers both (ARCH-DRY). `release_and_send` takes `file_history.snapshot(vim.fn.bufwinid(buf))` before it sends, since the operator may move on while the send runs, and calls `attention.record(path, breadcrumb, obj)` in the send callback when `obj.code == 0`. The call sits before the callback's stale-state guard, because the message has been sent whatever the engine did meanwhile, and it uses the path captured at send time.
  - `record(path, breadcrumb, send_result)` parses the message ID from the send's stdout and applies `submitted` (a nil breadcrumb, before #353 lands or with no observable window, is stored as no breadcrumb). With no ID in the stdout it records nothing and warns.
  - The `process-instruction:` `couch.send` path stays out: nothing folds it, so it could never read as answered.
  - `refresh(on_done)` probes each waiting entry with `couch.query({"couch","--session-sync","status","--json",path})`, at most 4 at a time. It captures the entry's pending IDs **when the probe starts** and applies `observed` with that set and the `Owed` IDs, or `observe_failed` with the Couch `Code`.
  - `open()` opens the picker from the stored state, starts a refresh, and calls `handle.update` as observations land. On select, it:
    1. opens the file in the current window, or reports a missing file and opens nothing;
    2. applies `opened`;
    3. calls `file_history.restore(win, entry.breadcrumb)` when #353 is present, keeping the file as a root if restore refuses.
  - **Injected:** the couch runner, the `file_history` seam and the clock, so the integration specs drive a stateful fake Couch.
- **The fake Couch (ARCH-MOCK):** extend the existing `tests/helpers/fake_couch.lua` (the shell `couch`) and `tests/fixtures/fake_couch_registry.py` (its `--session-sync` state file).
  - **Send:** today it prints nothing on stdout. It will print `<ID> me -> <to> queued`, with IDs from a counter file beside the log, and append the ID to the file's `Owed` in the registry state when `$FAKE_COUCH_REGISTRY` is set.
  - **Owed and fold:** the registry already persists a per-file `Status` (keyed by registration ID, or by path for an unregistered file) and returns it from `status`. A new helper, `fake_couch.fold(registry, path, id)`, removes an ID from that `Owed`, the way an agent's `write --fold` does.
  - **Refusals:** the registry's existing `FAKE_COUCH_REGISTRY_MODE` (`unsupported`, `malformed`, `missing`) and `FAKE_COUCH_STATUS` give the failure codes.
  - Live conformance: the shape matches pair's `couchcmd/session_sync.go:234`. A live check is the operator's smoke in Couch's nvim.

### Interaction, constraints and ordering

- **ARCH-CONSTRAINTS:**
  - Opening the finder reads one file (≤ 256 entries) and renders at once.
  - Probes are asynchronous, bounded at 4 concurrent `couch` processes, and only for waiting entries. A finder with 50 waiting entries costs 50 short `couch` runs in the background, with no wait on the UI path.
  - Recording a submit is one atomic write, after the send has already succeeded.
- **ARCH-ORDER:** the events that cannot be blocked are:
  - two editors applying events at once: the lease admits one; the other gets `busy` and retries (bounded, then a visible warning), and each `apply` re-reads the file under the lease;
  - observations arriving after the finder closed: they apply to the store, and the update to the closed handle is skipped;
  - a probe that started before a newer submit: `observed` carries the pending set captured at probe start and removes only those IDs that are absent from `Owed`. An ID recorded after the probe started is outside that set, so it survives and the entry stays waiting. Without this, a stale probe would mark a fresh submit answered;
  - a failed probe: `observe_failed`, with no state change;
  - the 14-day ledger trim, which reads as answered. A trimmed ID really is past the point where Couch can tell us more.

  The event most likely to be mishandled is a probe that fails (Couch not recording, the file not registered) being read as "answered". The model has no path from a failure to answered, and a test pins this.

## Decisions for the TL and operator

1. **What answered means:** the agent folded the submit through `couch --session-sync write --fold`. A reply in chat alone leaves the entry waiting; changing that is a Couch change, out of scope here.
2. **The chord:** `<M-u>`, for "unread". It is unbound in parley; Couch, zellij and tmux bindings are unchecked. `<M-e>` and `<M-b>` are also free.
3. **The grace default:** `attention.seen_grace_minutes = 60` (the operator said 1 h; 15 min is being confirmed).
4. **Out of scope:**
   - the winbar count ("may" in the Spec): the model exposes `answered_unseen` for it;
   - submits outside Couch (`session_sync` without Couch, legacy `process-instruction:`), which have no ledger to observe.

## Milestones

### M1: model, store and recording

#### Task 1: attention_model

**Files:**
- Create: `lua/parley/attention_model.lua`
- Test: `tests/unit/attention_model_spec.lua`

- [x] **Step 1: write the failing tests.** Strategy:
  - `transition`, table-driven over each event in each derived state (waiting, answered, seen, absent), plus random event sequences checked by properties: no `observe_failed` reaches answered; a waiting entry is never swept or dropped by the bound; an ID outside `probed_ids` survives `observed`.
  - One named sequence pins the stale probe: probe starts, a submit records ID2, the probe's result without ID2 applies, and the entry is still waiting.
  - `bound` and `list`: a 257-entry table checks the drop order (seen, then answered) and the refusal when all are waiting.
- [x] **Step 2:** run `make test-spec SPEC=scratch MAP_FILE=$TMPDIR/m.yaml` with the spec mapped. Expect it to fail, because the module doesn't exist yet.
- [x] **Step 3:** implement `transition`, `state_of`, `list`, `answered_unseen` and `bound`, as pure functions with no `vim.api`.
- [x] **Step 4:** run it. Expect a pass.
- [x] **Step 5:** commit with `git commit -m "#354: attention model: one transition owns waiting, answered, seen and the sweep"`.

#### Task 2: attention_store

**Files:**
- Create: `lua/parley/attention_store.lua`
- Modify: `tests/helpers/sidecars.lua` (register `attention.json`)
- Test: `tests/unit/attention_store_spec.lua`

- [x] **Step 1: write the failing tests.** Strategy:
  - the parse boundary, through the `sidecars.lua` corruption cases (missing, truncated, wrong version, malformed entry): each reads as empty with one warning;
  - the lease, with a real `document_lease` held by the test: released within the retry window → the event lands; held throughout → no write and the "lost (store busy)" warning; two stores over one path both keep their events.
- [x] **Steps 2-5:** run it (fail), implement with `helper.table_to_file_atomic`, `fs.ensure_dir` and `document_lease.acquire("attention", "store", { root = state_dir })` with the busy retry, run it (pass), commit.

#### Task 3: recording a submit

**Files:**
- Create: `lua/parley/attention.lua` (`record`, `parse_message_id`)
- Modify: `lua/parley/session_sync.lua` (`release_and_send`: snapshot the breadcrumb before the send, and call `require("parley.attention").record(path, breadcrumb, obj)` on success, before the stale-state guard)
- Modify: `lua/parley/config.lua` (`attention = { seen_grace_minutes = 60 }`)
- Modify: `tests/helpers/fake_couch.lua` and `tests/fixtures/fake_couch_registry.py` (the send prints `<ID> me -> <to> queued` and adds the ID to `Owed`; `fake_couch.fold`)
- Test: `tests/integration/attention_record_spec.lua`

- [x] **Step 1: write the failing tests.** Strategy: drive both Alt+Return paths end to end through the fake Couch (an agentic document, and a `type: session-sync` file through `review_send.submit`); each must leave one waiting entry carrying the fake's ID. The failure paths (a failed send, stdout without an ID) leave no entry and warn. `parse_message_id` gets a table of stdout shapes.
- [x] **Steps 2-5:** run it (fail), implement, run it (pass), commit.
- [ ] **M1 close:** run `sdlc milestone-close --issue 354 --milestone M1`.

### M2: the finder

#### Task 4: attention_rows

**Files:**
- Create: `lua/parley/attention_rows.lua`
- Modify: the highlight definitions (`ParleyAttention*`, linked to existing groups, with Seen dimmer)
- Test: `tests/unit/attention_rows_spec.lua`

- [x] **Steps 1-5:** test-driven: the row text, the highlight ranges for each state, the `?` marker, `search_text` (basename plus dir), newest first.

#### Task 5: refresh and open

**Files:**
- Modify: `lua/parley/attention.lua` (`refresh`, `open`)
- Modify: `lua/parley/keybinding_registry.lua` and `config.lua` (`global_shortcut_attention = <M-u>`)
- Modify: `init.lua` (`:ParleyAttention`)
- Test: `tests/integration/attention_finder_spec.lua`

- [x] **Step 1: write the failing tests.** Strategy: one spec per user path against the fake Couch, with the clock and the `file_history` seam injected: list then a live fold (`update` turns waiting into answered); select answered (opens, seen, `restore` called; a refusal keeps the ordinary open result and shows the reason); select waiting (unchanged); select a missing file (reported, nothing opens); a refusal `Code` (`?`, state kept); a probe counter asserting at most 4 at once; typeahead; a seen entry past the grace gone on the next open; an observation after close.
- [x] **Steps 2-5:** run it (fail), implement, run it (pass), commit.

#### Task 6: docs

- [x] Add `atlas/ui/attention_finder.md` and link it from `atlas/index.md`. Add the chord to `atlas/ui/keybindings.md` and the specs to `atlas/traceability.yaml`.
- [ ] **M2 close:** run `sdlc milestone-close`, then `sdlc close`, then the operator's live check in Couch's nvim (staged only with the hub's go).

## Revisions

- **2026-10-16, the TL's approval.** The four decisions are settled:
  1. answered means folded by the agent (the protocol);
  2. the chord is `<M-u>`: the TL checked pair's zellij binds and Couch's key catalog, and it is free there. Adding it to Couch's key help (`pair/cmd/internal/keyhelp/catalog.go`) is pair work, handed to the TL to file rather than edited from this slot;
  3. `attention.seen_grace_minutes` defaults to 60 and stays a config value; the operator has not picked between 60 and 15;
  4. the winbar count and submits outside Couch stay out of scope.
- **2026-10-16, plan-quality round 1.** Three blocking findings, all accepted:
  - PQ-1: `document_lease.acquire` is non-blocking, so `apply` now retries `busy` (bounded) and warns when a record is lost;
  - PQ-2: a probe that started before a newer submit could clear that submit's ID, so `observed` carries the pending set captured at probe start and removes only those IDs;
  - PQ-3: `type: session-sync` files also send through Couch, so the record hook moves from the agentic document's send effect into `session_sync`'s `release_and_send`, which both paths share.

  The minor findings were folded in too: the test lists became one strategy line each; the fake extends the existing `fake_couch.lua` and its registry fixture; and #353 is declared a dependency. Until #353 lands, the restore runs against the injected seam.
- **2026-10-16, building M1.**
  - The store file moved to its own directory, `state_dir/attention/attention.json`. That way stale `table_to_file_atomic` temps can be removed under the lease without touching other sidecars' in-flight writes in `state_dir` (ARCH-FUNERAL).
  - The parse does its own typing, without `helper.conform`: `sidecar_degrade_spec` allows one warning per read, and conform plus a dropped-entry warning made two.
  - The fake's owed recording is opt-in (`FAKE_COUCH_OWED`), so the existing session-sync specs, whose winbar renders owed events, keep their ledgers.
  - Agreed with parley.nvim:2 on #353's refusal edge: when `restore` refuses, the ordinary open result stands. A reused, already-current file keeps its existing trail, and the reason is shown in one notice. There is no root-reset operation, and the finder never reads snapshot fields.
- **2026-10-16, the M1 review.**
  - BR-2 (Important): fixed with a late-completion spec. A slow send completes after its buffer is wiped, and the record still lands; moving the record below the guard fails it.
  - Minor: the record and the breadcrumb snapshot run under `pcall` in the send callback, and a throwing record is tested.
  - Minor: `attention_model` uses a local copy, not `vim.deepcopy`.
  - Minor: the "two stores over one path" store test interleaves a direct write between two applies. It can't contend for the lease inside one process; the held-lease specs cover contention.
- **2026-10-16, building M2.**
  - Task 6 also updates README.md (the review's advisory), next to the Alt+Shift+O paragraph.
  - A probe reply whose `Status` is null (Couch keeps no ledger for the file) is `observe_failed`, not an empty `Owed`. Reading it as answered would be the failure the plan names as most likely.
  - The live check is the TL's to sequence, together with #353, since they share the restore seam. This slot doesn't stage it.
- **2026-10-16, the M2 review.**
  - BR-8 (Important, the second finding in the declared-ordering-untested family): the probe-start capture is now pinned through the glue. A held probe interleaves with a newer submit and folds, and moving the capture into the probe callback fails the spec.
  - Class sweep of the ARCH-ORDER list against tests that drive production code: two editors (the store's held-lease specs), an observation after close, a failed probe, the stale probe vs a newer submit (now covered), and the 14-day trim (the same path as a fold).
  - `observe_failed` records fixed reasons ("couch status unavailable", "no Couch ledger for this file"): `couch.query` returns nil for any Code other than ok, so the Code isn't visible here.
  - `select` restores the breadcrumb, then applies `opened`.
  - The keybindings atlas paragraph is back under File history.
- **2026-10-16, the M2 review, round 2.**
  - BR-11 (Important, second in plan-test-strategy-drift): Task 5's typeahead and cursor-keeping now run on the real `float_picker`. A typed filter and the selected row survive a repaint that inserts another editor's newer row above the cursor, and Enter opens the chosen row; dropping the repaint's selection identity fails it. The after-close case also runs on the real picker: it is cancelled before the probe lands, and the probe still reaches the store.
  - Class sweep of Task 5's strategy line against specs: list and live fold; select answered, waiting and missing; refused restore; `?`; the limit of 4; typeahead and cursor (real picker); the grace; after close (real picker). Each has a spec.
  - Minor: probes are bounded by a 5 s timeout through `couch.query`'s new `options`; expiry reads as failed (`?`), never as answered.
- **2026-10-16, scope addition (the operator, via the TL): side docs.** New side docs (and answer docs) the agent writes appear as answered, not yet seen, and leave by the same rule. The mechanism (sent to the TL) is a scan, not a watch:
  - on every finder open, `attention.discover` lists the `.side/` folder of each entry already in the finder. A `*.md` with frontmatter `type: side-doc` (`attention.is_side_doc`, the head of the file only), written after its parent entered the finder (`recorded_at`; for a side-doc parent, its own time), becomes a `discovered` event. Parley sees no agent writes, so a watch would need a watcher per folder, with its own lifetimes, for the same result at the moment the operator looks;
  - the model's `discovered` creates `{kind = "side", parent, pending = {}}`, which is answered. The scan's events apply as one `batch` (one store write). Side docs are entries, so nested side docs are found on the next open;
  - a side doc that leaves (sweep or bound) is `retired` (at most 256, the oldest drop first), so a later scan never brings it back. A rewrite of a seen side doc does not resurface it (only new files count). The row marker is `↳`, and the parent's name is searchable;
  - I found no separate answer-doc type in ariadne or ops; the TL was asked for the rule if answer docs differ.
- **2026-10-16, the M2 review, round 3.**
  - BR-13 (Important, reuse an existing owner): `is_side_doc` reads through `frontmatter.parse` (a closed block, case-folded keys, trailing comments) and the folder through `document_move_plan.side_path`. The spec gains a comment case and an unclosed block.
  - The scope addition re-checks the cross-cutting sections (the plan-code-drift rule):
    - **Core concepts, the state shape:** an entry also carries `recorded_at`, `kind = "side"` and `parent`; the state also carries `retired = {[path] = at}` (at most 256).
    - **Events:** add `discovered(path, parent, at)` and `batch(events)`. Rows mark a side doc with `↳`.
    - **ARCH-CONSTRAINTS:** opening the finder is the sweep write, a synchronous scan of at most 256 `.side/` folders (40 head lines per new candidate), and one batch write, then the rows render. It no longer just reads one file and renders at once.
    - **ARCH-ORDER:** discovery is idempotent under the lease (an existing or retired path is ignored), so two editors scanning at once add each doc once.
    - **ARCH-FUNERAL:** `retired` is bounded like the entries.
    - **"New":** modified after the parent entered the finder, so a side doc older than its parent's entry counts once it is rewritten. The atlas says so.
  - Minor: a refused batch warns "new side docs were not recorded", not a nil path.
  - Class sweep of BR-13 ("a fact the codebase already owns is read through its owner") over the attention modules: the bounded probe loop was hand-rolled too, so `refresh` now runs through `async_operation_queue` (the queue `async_file_source` uses); the capture-point and limit mutations still fail their specs. No other owner was found for Couch's receipt line or for home-relative directory display; `attention_rows` stays pure Lua.
- **2026-10-16, the operator's chord decision (via the TL).** The finder is bound to `<M-Space>` (Alt+Space), not `<M-u>`. Nothing in pair's zellij config, Couch or parley binds it, Alfred uses Cmd+Space, and Ghostty sends Option as Alt. `:ParleyAttention` stays. A spec registers the global keymaps and calls the `<M-Space>` mapping in Normal and Insert mode. pair#619 (Couch's key help) should name Alt+Space.
- **2026-10-16, a second key (the operator, via the TL).** `<C-y><Space>` joins `<M-Space>` on the same registry entry, in the `<C-y>` family's modes (n, i, like `<C-y>f`). In Insert mode, accepting a completion with `<C-y>` and then typing a space must stay exactly that, so the entry is `pum_passthrough`: while `pumvisible()`, the key is fed noremap at the front of the typeahead and keeps its literal meaning. The spec drives a real keyword-completion popup (`<C-n>`): it checks that the popup is accepted, the space is typed and the finder doesn't open, and that without a popup the same keys open the finder. Removing the passthrough fails it. Spell's own `<C-y>` is fed noremap, so it never reaches these maps.
- **2026-10-16, seen however the operator looks (an operator-found gap, via the TL).** A session file, or any file kept open, would stay answered for good, because the operator reads the answer where the file is already open and never opens it from the finder. Seen now means the operator looked:
  - the pure event `viewed(path, at)` makes an answered entry seen only if `at` is after `answered_at`. A view before or at the answer, or of a waiting, seen or unknown path, changes nothing;
  - `attention.setup()` (called from parley's setup) installs one augroup on WinEnter, BufEnter, CursorMoved(I), and WinScrolled for the current window only. Each event checks an in-memory set of the paths this editor last saw answered (refreshed by every store change through the module's one `apply`), so a cursor move costs a table lookup; a hit applies `viewed` once. Opening from the finder still counts;
  - the finder leaves out the file shown in the current window;
  - `answered_at` is when this editor observed the answer (at a finder refresh). The current window's file is hidden then, so the next focus or cursor move in it counts.
