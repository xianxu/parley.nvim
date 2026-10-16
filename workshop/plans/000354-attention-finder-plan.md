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

| Name | Lives in | Status |
|------|----------|--------|
| `attention_model` | `lua/parley/attention_model.lua` | new |
| `attention_rows` | `lua/parley/attention_rows.lua` | new |

- **attention_model:** the entries and their transitions.
  - State: `{version = 1, entries = {[path] = Entry}}`, with `Entry = {path, pending = {[message_id] = submitted_at}, submitted_at, answered_at?, seen_at?, breadcrumb?, unknown?}`.
  - The state of an entry is derived, never stored:
    - **waiting** when `pending` is non-empty;
    - **answered** when `pending` is empty and `seen_at` is nil, or when `seen_at < answered_at`;
    - **seen** when `pending` is empty and `seen_at >= answered_at`.
  - `transition(state, event, now) -> state'` handles these events:
    - `{type="submitted", path, id, breadcrumb}`: adds `id` to `pending` and replaces `submitted_at` and `breadcrumb`. A new submit resets the entry to waiting.
    - `{type="observed", path, owed_ids}`: removes from `pending` every ID not in `owed_ids`, and sets `answered_at = now` when `pending` becomes empty. It ignores a path with no entry, and leaves alone an entry that has no pending IDs.
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
| `attention_store` | `lua/parley/attention_store.lua` | new | the JSON file `state_dir/attention.json` |
| `attention` | `lua/parley/attention.lua` | new | the couch CLI, the editor, #353's seam |
| `agentic_document` send effect | `lua/parley/agentic_document.lua:247` | modified | records a submit |

- **attention_store:** `load()` and `apply(event)`.
  - `apply` loads the file, runs the transition, then writes it with `helper.table_to_file_atomic` under `document_lease` (several editors may submit at once).
  - **Input handling (ARCH-SECURE):** a missing, truncated or hand-edited file, or one written by a different version, is parsed into a typed state at the boundary. Anything that doesn't fit reads as empty and is reported once with a warning; it is never trusted as entries. The file joins `tests/helpers/sidecars.lua` for its corruption cases.
  - **Lifetime (ARCH-FUNERAL):** one file of at most 256 entries, each about 1 KB plus its breadcrumb. Entries leave by `sweep`, which runs on every `apply`, or by the bound.
- **attention (glue):**
  - `record(buf, send_result)` parses the message ID from the send's stdout, takes `file_history.snapshot(win)` (nil until #353 lands; a nil value is stored as no breadcrumb), and applies `submitted`. With no ID in the stdout it records nothing and logs why.
  - `refresh(on_done)` probes each waiting entry with `couch.query({"couch","--session-sync","status","--json",path})`, at most 4 at a time. It applies `observed` with the `Owed` IDs, or `observe_failed` with the Couch `Code`.
  - `open()` opens the picker from the stored state, starts a refresh, and calls `handle.update` as observations land. On select, it:
    1. opens the file in the current window, or reports a missing file and opens nothing;
    2. applies `opened`;
    3. calls `file_history.restore(win, entry.breadcrumb)` when #353 is present, keeping the file as a root if restore refuses.
  - **Injected:** the couch runner, the `file_history` seam and the clock, so the integration specs drive a stateful fake Couch.
- **The fake Couch (ARCH-MOCK):** `tests/helpers/fake_couch.lua`, new or extending the #332 helper if one exists.
  - It holds a per-file owed list.
  - A send appends an ID and returns `<ID> me -> owner queued`.
  - `fold(path, id)` removes an ID.
  - Status returns the JSON above, or a refusal `Code`.
  - Live conformance: the shape matches pair's `couchcmd/session_sync.go:234`. A live check is the operator's smoke in Couch's nvim.

### Interaction, constraints and ordering

- **ARCH-CONSTRAINTS:**
  - Opening the finder reads one file (≤ 256 entries) and renders at once.
  - Probes are asynchronous, bounded at 4 concurrent `couch` processes, and only for waiting entries. A finder with 50 waiting entries costs 50 short `couch` runs in the background, with no wait on the UI path.
  - Recording a submit is one atomic write, after the send has already succeeded.
- **ARCH-ORDER:** the events that cannot be blocked are:
  - two editors applying events at once: the lease serializes them, and each `apply` re-reads the file;
  - observations arriving after the finder closed: they apply to the store, and the update to the closed handle is skipped;
  - an observation for a submit that a newer submit superseded: `observed` removes only IDs absent from `Owed`, so the newer, still-owed ID keeps the entry waiting;
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

- [ ] **Step 1: write the failing tests.** Cover:
  - submitted → waiting;
  - observed with the ID still owed → still waiting;
  - observed with the ID gone → answered with `answered_at`;
  - opened while answered → seen; opened while waiting → unchanged;
  - a new submit after seen → waiting again;
  - sweep: seen past the grace → removed; seen inside the grace → kept; answered and never opened → kept for any age; waiting → kept;
  - `observe_failed` → state unchanged plus `unknown`; a later success clears it;
  - two pending IDs with one folded → still waiting;
  - an observation for an unknown path → no-op;
  - the bound: the 257th submit drops the oldest seen, and all-waiting refuses;
  - `list` order and `answered_unseen`.
- [ ] **Step 2:** run `make test-spec SPEC=scratch MAP_FILE=$TMPDIR/m.yaml` with the spec mapped. Expect it to fail, because the module doesn't exist yet.
- [ ] **Step 3:** implement `transition`, `state_of`, `list`, `answered_unseen` and `bound`, as pure functions with no `vim.api`.
- [ ] **Step 4:** run it. Expect a pass.
- [ ] **Step 5:** commit with `git commit -m "#354: attention model: one transition owns waiting, answered, seen and the sweep"`.

#### Task 2: attention_store

**Files:**
- Create: `lua/parley/attention_store.lua`
- Modify: `tests/helpers/sidecars.lua` (register `attention.json`)
- Test: `tests/unit/attention_store_spec.lua`

- [ ] **Step 1: write the failing tests.** Cover:
  - a round trip;
  - `apply` re-reads before writing, so two stores over one path both keep their events;
  - a missing file → empty;
  - truncated JSON, wrong version, or an entry missing its path → empty plus one warning;
  - the sweep runs on `apply`, with the grace taken from config.
- [ ] **Steps 2-5:** run it (fail), implement with `helper.table_to_file_atomic`, `fs.ensure_dir` and `document_lease.acquire("attention", ...)`, run it (pass), commit.

#### Task 3: recording a submit

**Files:**
- Create: `lua/parley/attention.lua` (`record`, `parse_message_id`)
- Modify: `lua/parley/agentic_document.lua:247-253` (after a successful send, call `require("parley.attention").record(s.buf, result)`)
- Modify: `lua/parley/config.lua` (`attention = { seen_grace_minutes = 60 }`)
- Test: `tests/integration/attention_record_spec.lua`, with `tests/helpers/fake_couch.lua`

- [ ] **Step 1: write the failing tests.**
  - An Alt+Return submit through the fake Couch creates one waiting entry with the fake's ID.
  - A failed send records nothing.
  - Stdout without an ID records nothing and logs it.
  - A second submit of the same file adds a second pending ID.
  - The breadcrumb is `snapshot(win)` when the seam exists, and nil without it.
- [ ] **Steps 2-5:** run it (fail), implement, run it (pass), commit.
- [ ] **M1 close:** run `sdlc milestone-close --issue 354 --milestone M1`.

### M2: the finder

#### Task 4: attention_rows

**Files:**
- Create: `lua/parley/attention_rows.lua`
- Modify: the highlight definitions (`ParleyAttention*`, linked to existing groups, with Seen dimmer)
- Test: `tests/unit/attention_rows_spec.lua`

- [ ] **Steps 1-5:** test-driven: the row text, the highlight ranges for each state, the `?` marker, `search_text` (basename plus dir), newest first.

#### Task 5: refresh and open

**Files:**
- Modify: `lua/parley/attention.lua` (`refresh`, `open`)
- Modify: `lua/parley/keybinding_registry.lua` and `config.lua` (`global_shortcut_attention = <M-u>`)
- Modify: `init.lua` (`:ParleyAttention`)
- Test: `tests/integration/attention_finder_spec.lua`

- [ ] **Step 1: write the failing tests.**
  - The finder lists waiting entries, then shows answered after the fake folds one, live through `update`.
  - Selecting an answered entry opens the file, marks it seen and calls `restore` with the stored value. Restore refusing leaves the file open as a root.
  - Selecting a waiting entry opens it and leaves it waiting.
  - A missing file is reported and nothing opens.
  - A refusal `Code` shows `?` and keeps the state.
  - At most 4 probes run at once.
  - Typeahead filters by name.
  - A seen entry past the grace is gone on the next open.
  - An observation landing after close doesn't error.
- [ ] **Steps 2-5:** run it (fail), implement, run it (pass), commit.

#### Task 6: docs

- [ ] Add `atlas/ui/attention_finder.md` and link it from `atlas/index.md`. Add the chord to `atlas/ui/keybindings.md` and the specs to `atlas/traceability.yaml`.
- [ ] **M2 close:** run `sdlc milestone-close`, then `sdlc close`, then the operator's live check in Couch's nvim (staged only with the hub's go).
