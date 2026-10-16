---
id: 000352
status: working
deps: []
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
severity: low
card_mirror: '2d7ee6aaf166d700c31d09eb6ceebc4e50fe1b16' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-16T08:11:54-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "515272bf", done: "d09468a6"}
---

# Send side chats off the path to the root as their summary lines

## Problem

## Spec

Follow-up to #233 (operator request, 2026-10-16). #233 sends the whole chat tree in depth-first order, cut at the submitted exchange, and renders every exchange the same way, so a side chat's exchanges go out in full (or under the memory rule) like any other.

Asides are usually side conversations: the model needs to know they happened, not their full transcript. Add a config flag that sends side chats NOT on the path from the current file to the root as their summary lines only (the exchange's summary line, the same one memory uses for an omitted exchange). Exchanges in files on the path to the root (the current file and its ancestors) keep the memory rule as today.

- The flag's name and its default are decided in the plan, with the request-size numbers from #233's measured tree (before and after, both values of the flag).
- An off-path exchange without a summary line: the plan decides (skip it, or send it under the memory rule).
- Nested asides off an off-path aside are off-path too.

## Done when

- A config flag controls how off-path side chats are rendered; with it on, every off-path exchange is sent as its summary line only, and on-path exchanges are unchanged.
- Tests cover: an aside off the root seen from a later root question, a nested aside, an on-path ancestor (unchanged), the flag off (#233 behaviour), and an off-path exchange without a summary.
- The atlas and the config docs describe the flag and its default.

## Plan

Design (quick flow, about 40 code lines):

- **The flag:** `chat_memory.side_chats`, `"summary"` (proposed default) or `"full"` (#233's behaviour). It applies whether or not `chat_memory.enable` is on: it is about which exchanges are side conversations, not about the window. Default `"summary"`, because the operator's reason (asides are side conversations, the model needs awareness) holds for the common case, and it brings memory-off requests back near their pre-#233 size while keeping the aside visible. The close gives the measured before and after for both values.
- **Off-path is a fact of the walk (ARCH-PURE):** `chat_tree.linearize` marks every item it emits from `subtree()` as `off_path = true`. These are the asides and everything nested under them, whether they hang off the current file or off an ancestor before the path's branch. The path's files (ancestors and the current file) are never off-path. A unit case in `chat_tree_spec` pins this.
- **One renderer (ARCH-DRY):** `build_messages` renders an off-path item through the existing summarized branch: the `omit_user_text` placeholder, then the `📝:` summary as the assistant message. No new message shape. Under `"summary"`, an off-path item:
  - is never preserved in full: neither the window nor `@@` file references pin it, so its references are not inlined;
  - with no `📝:` summary, is sent as its question text alone (see Revisions): the question, truncated, marked as an aside with no summary, and an assistant note that the answer is omitted, so the roles still alternate;
  - does not count toward the memory window. The window counts on-path exchanges from the end of the current file, as it did for a single file plus ancestors, so an aside does not push a path exchange out of full retention.
- **Remote resolution derives from the same rule (ARCH-PURPOSE):** `resolve_remote_references` skips off-path items under `"summary"`, so a reference that won't be sent is not fetched. Both builders read one predicate, `chat_respond.renders_full_off_path(config)` or similar, so they cannot disagree.
- **Out of scope:** `build_messages_from_model` has no production caller, is single-file, and sees no tree.
- ARCH-CONSTRAINTS: the walk is unchanged; rendering gets cheaper. ARCH-MOCK, SECURE, ORDER, FUNERAL: N/A. No external IO, no new input boundary, no state held between events (the flag is read per request), nothing durable created.

Steps:

- [ ] `linearize` marks `off_path`; chat_tree_spec case
- [ ] config `chat_memory.side_chats = "summary"`, with a comment in config.lua
- [ ] build_messages: off-path summary rendering, skip when there is no summary, on-path-only window count
- [ ] resolve_remote_references skips off-path under `"summary"`
- [ ] tests (chat_tree_context_spec): an aside off the root seen from a later root question; a nested aside; an on-path ancestor unchanged; `"full"` keeps #233 behaviour; an off-path exchange without a summary sends its truncated, marked question; an off-path `@@` reference is neither fetched nor inlined; the window ignores off-path items
- [ ] atlas (chat/memory.md, chat/lifecycle.md) and the README config docs
- [ ] re-measure #233's tree under both values, with memory off and on

## Revisions

- 2026-10-16, TL review of plan 3cd110c6: approved with the default `"summary"`. Decision 5 changed: an off-path exchange without a summary sends its question text alone (truncated, marked as an aside with no summary) instead of nothing. The goal is awareness that the side discussion happened; dropping it silently defeats that, and its full answer would defeat the flag.

## Log

### 2026-10-16
