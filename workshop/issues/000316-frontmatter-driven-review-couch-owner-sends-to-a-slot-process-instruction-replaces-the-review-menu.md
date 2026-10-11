---
id: 000316
status: open
deps: []
github_issue:
created: 2026-10-11
updated: 2026-10-11
estimate_hours:
card_mirror: 'ac79950472d75c3b8bbb059cab19429cd4b48795' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-11T11:32:36-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:0
    worktree: /Users/xianxu/workspace/parley.nvim
    repository: github.com/xianxu/parley.nvim
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

- [ ] Frontmatter reader: hyphenated keys, raw `process-instruction`, `couch-owner` with the `owner` alias; audit strict readers for the `[`-leading value.
- [ ] Alt+Return dispatch: `couch-owner` → generic couch send (path, instruction, diff since last send); else today's review path with the instruction.
- [ ] `[name]` expansion from the mode files (knobs included); `[` completion in the value.
- [ ] Remove `review_menu.lua` and its wiring; tests for the Done-when rows; update the parley docs/atlas.

## Revisions

### 2026-10-11 11:4x — the send target is the slot's own actor; `couch-owner` dropped (operator)

- **Target:** Alt+Return sends to the actor (agent) in the slot this nvim runs in. No frontmatter names it. The `couch-owner:` key is dropped from this issue (pair#443 already reads it and stays harmless; nothing writes it).
- **No slot** (nvim outside pair): fall back to today's review path, with the same `process-instruction`.
- **Session-sync files keep `owner:`**, set to the actor that started the file. It is a check, not a route: if this nvim's slot isn't the owner, parley warns and doesn't send.
- Spec bullets and Done-when rows that name `couch-owner` read as "the slot's own actor" from here on; the first Done-when row becomes: Alt+Return in a markdown file opened in ariadne:2's pane (no frontmatter target) delivers to ariadne:2's actor. The TL no longer switches the status file to `couch-owner:`.

## Log

### 2026-10-11
