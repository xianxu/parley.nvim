---
id: 000316
status: working
deps: []
github_issue:
created: 2026-10-11
updated: 2026-10-11
estimate_hours:
card_mirror: 'c9eac7420cea46878b5fb81a08e04e009848bbbf' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-11T11:32:36-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "d85b80a4", done: "ce096737"}
---

# Frontmatter-driven review: couch-owner sends to a slot; process-instruction replaces the review menu

## Problem

Two limits, both from the operator (10-11):
- **Only the session-sync file can reach a Couch slot.** A markdown file whose frontmatter names `owner: ops:0` gets Alt+Return-to-agent only when it is also `type: session-sync`. The operator wants the same gesture on any document: "I wrote something here; what do you think?", sent to the named slot as a review or a ping.
- **The review menu is too narrow.** Alt+Return on markdown opens `review_menu.lua`'s float: pick one of six modes (`lua/parley/skills/review/modes/*.md`), then type an instruction. Picking from a fixed list at every submit is strict, and the per-round instruction lives in a throwaway box instead of the document.

## Spec

Unify around frontmatter. Three independent keys:

- **`couch-owner: <repo:N>`**: where Alt+Return sends the document. Any markdown file with it gets the send: parley runs `couch --send-to <slot>` with the path, the `process-instruction`, and what changed since the last send (the shadow-diff idea from session-sync). `owner:` stays accepted as a legacy alias for one release; a file with both uses `couch-owner`.
- **`type: session-sync`**: layers the turn semantics on top (the operator's lock, the owed band, the ping; parley.nvim#315). Without it, a `couch-owner` file has no lock and no band: just send.
- **`process-instruction: [mode] free text`**: one line, the standing instruction. A leading `[name]` (one or more: `[copy-edit][fact-check]`) inserts that stock prompt; the free text after it is added to it. The stock prompts are the existing mode files, so a mode's knobs (`scope`, `deletions`, `frontier`) still apply when it's named. With no `[name]`, the free-form defaults apply. The operator edits this line per round; in-document `🤖[…]` markers stay as anchored comments.
- **Completion:** typing `[` in the `process-instruction:` value completes the stock prompt names (from the modes directory, so a new mode file is a new completion).
- **The review menu goes away:** Alt+Return in markdown reads the frontmatter and sends. With no `couch-owner`, it goes to the review path parley uses today (the pair-hosted workbench), carrying the same `process-instruction`. A file with neither key: Alt+Return prompts once to add `process-instruction:` (no float picker).
- **Parsing:**
  - the frontmatter key pattern must accept `-` (today's `^([%w_]+):` rejects `couch-owner` and `process-instruction`);
  - the `process-instruction` value is read raw, as the whole line after the colon;
  - `[copy-edit] text` is not valid YAML (a leading `[` starts a flow sequence). Check every fleet reader that parses markdown frontmatter strictly (sdlc's instance-conformance gate on `workshop/` files is the likely one). If any would fail, have completion write the value quoted, and make parley's reader strip the quotes.

## Done when

- Alt+Return in a markdown file with `couch-owner: ariadne:2` (no `type`) delivers a message to ariadne:2 naming the path, the instruction and the change since the last send (test with a fake couch).
- `process-instruction: [copy-edit] keep the voice` expands to the copy-editing mode text plus the addition, with the mode's knobs (test); `[` completes mode names from the modes directory (test).
- The review menu float is gone; Alt+Return with no `couch-owner` reaches today's review path with the instruction (test).
- `owner:` still works (test); a frontmatter with `process-instruction: [x] y` doesn't break any strict reader in the fleet (checked, or the value is written quoted).
- The ops status file is switched to `couch-owner:` by the TL after this and pair#443 land.

## Plan

Durable plan: [workshop/plans/000316-frontmatter-driven-review-plan.md](../plans/000316-frontmatter-driven-review-plan.md) (decisions, core concepts, tasks).

- [x] Frontmatter reader (`lua/parley/frontmatter.lua`): hyphenated keys, raw values, quote/unquote; session-sync uses it. YAML audit done: sdlc's yaml.v3 rejects `a: [copy-edit] keep the voice`, so parley writes the value quoted.
- [x] `[name]` grammar + expansion (`skills/review/instruction.lua`), shared by the couch message and the review prompt; knobs from the first named mode.
- [x] Couch seam extracted (`lua/parley/couch.lua`); own slot = the actor matching `COUCH_THREAD_SCOPE`/`TAG`.
- [x] Alt+Return dispatch (`review_send.lua`): own slot → send with path, instruction, diff since last send; no slot → today's review path; session-sync `owner:` is a check; `[` completion; review menu removed.
- [x] Atlas/docs; full suite + lint; manual e2e in a pair slot.

## Revisions

### 2026-10-11 11:4x — the send target is the slot's own actor; `couch-owner` dropped (operator)

- **Target:** Alt+Return sends to the actor (agent) in the slot this nvim runs in. No frontmatter names it. The `couch-owner:` key is dropped from this issue (pair#443 already reads it and stays harmless; nothing writes it).
- **No slot** (nvim outside pair): fall back to today's review path, with the same `process-instruction`.
- **Session-sync files keep `owner:`**, set to the actor that started the file. It is a check, not a route: if this nvim's slot isn't the owner, parley warns and doesn't send.
- Spec bullets and Done-when rows that name `couch-owner` read as "the slot's own actor" from here on; the first Done-when row becomes: Alt+Return in a markdown file opened in ariadne:2's pane (no frontmatter target) delivers to ariadne:2's actor. The TL no longer switches the status file to `couch-owner:`.

## Log

### 2026-10-11

- Claimed from parley.nvim:1 (TL dispatch). Durable plan: `workshop/plans/000316-frontmatter-driven-review-plan.md`.
- **Own slot:** pair sets `COUCH_THREAD_SCOPE`/`COUCH_THREAD_TAG` on every pane (checked on a live draft nvim via `ps eww`); `couch --actors --json` bindings carry `Scope`/`Tag`, so the slot is the actor matching both (the thread match couch's `LivenessForThread` uses), never an address string.
- **YAML audit:** ran sdlc's `go.yaml.in/yaml/v3` on `a: [copy-edit] keep the voice` → `did not find expected key`; the double-quoted form parses. sdlc parses issue/project frontmatter strictly (`internal/issue/card.go`, `project/metadata.go`), so parley writes the value quoted when `frontmatter.needs_quote` says so (completion, the add-prompt) and reads both.
- **Decisions:** `[copy-edit]` resolves by unique prefix (the Done-when's spelling; the file is `copy-editing.md`); several modes → every brief, the first one's knobs (ARCH-DRY: one `instruction.brief` for the slot message and the review prompt). Session-sync outside pair keeps sending to `owner:` (no slot to compare against); inside, a mismatch warns and changes nothing. In pair with no resolvable actor: error, never a silent fallback to an LLM round.
- **ARCH-FUNERAL:** the send baseline is in memory (one string per file sent this session); nothing is written beside the file.
- **Refactors:** `lua/parley/couch.lua` (send/query/find_actor moved out of session_sync, plus own-actor resolution); `lua/parley/frontmatter.lua` (session_sync's header reader rejected hyphenated keys); `tests/helpers/fake_couch.lua` (shared by both specs; logs one line per send, keeps the full last message).
- **Test note:** TextChangedI never fires mid-typeahead in a `feedkeys(..., "x")` run, so the completion spec drives the installed handler via a `<Cmd>` mapping in real insert mode and asserts the autocmd is installed.
