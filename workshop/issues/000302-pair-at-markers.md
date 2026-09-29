---
id: 000302
status: working
deps: []
github_issue:
created: 2026-09-29
updated: 2026-09-29
estimate_hours:
card_mirror: 'e4526c79552e2b7e6c10403e6035e62873ff7c06' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-09-29T11:08:55-07:00
flow: {kind: quick, provenance: inferred, spec: "dbd4d9ad", done: "7f0c9902"}
---

# Auto-pair double-at markers while typing

## Problem

Typing paired double-at markers currently requires manually entering and positioning both delimiters.

## Spec

In chat Insert mode, the second @ creates @@|@@, with the cursor between delimiters. Typing the closing @@ moves across existing closers. Ordinary single @ remains literal. Preserve effective user mappings, respect default_keymaps=false, and keep repeated preparation idempotent.

ARCH-DRY: reuse native_map and its registry exemption. ARCH-PURE: isolate line/byte-column decisions in a stateless helper; the mapping reads the editor and returns keys. ARCH-CONSTRAINTS: scan only the current line on @, never the chat. ARCH-MOCK/SECURE/STATE/FUNERAL: no external service, secrets, inter-event state, or durable runtime artifacts. ARCH-PURPOSE: verify actual remappable typing and one-step undo.

### Core concepts

| Symbol | Status | Owner / purpose |
| --- | --- | --- |
| `keys` | new | `lua/parley/at_pair.lua`: pure line-local pairing decision |
| `is_local_tag`, `local_rows`, `project`, `context_text`, `content`, `outline_label` | inherited | `lua/parley/question_tags.lua`: stacked #301 outline/context helpers |

## Done when

- Real typing creates paired markers, skips closers, preserves existing pairs and single-at text, and undoes in one step.
- Existing global/buffer mappings and disabled defaults remain effective; non-chat buffers are unchanged.
- Keybinding and architecture tests pass; README and atlas describe the shortcut.

## Plan

- [x] Add failing production-key tests for pairing, cursor, skip, reuse, multiple pairs, mapping ownership, scope and undo.
- [x] Add pure pairing helper and minimal native insert mapping.
- [x] Document, run keybinding and single-source checks, and commit for integration before close.

## Log

### 2026-09-29

- Baseline keybinding behavior passed; two architecture checks initially attributed inherited #301 exports to this stacked branch. Added an explicitly inherited Core concepts row.
- RED: production typing tests failed with missing closers before implementation. Typeahead tracing then showed expression callbacks observing stale text, including ordinary text between at signs; a command callback queues nonremapped keys only after prior insertion. Cursor motions use <C-g>U to retain one undo step.

- GREEN: `make test-spec SPEC=ui/keybindings` passed 354 tests, zero failures/errors, including single-source architecture sweeps and 12 production typing tests (undo/redo, dot-repeat, rapid prose, email, scope, mappings). Focused luacheck passed. In-memory mutation runs through production mappings detected removal of pair, skip, reuse and fallback branches. `git diff --check` passed. Integration and close are owned by the parent session after #301 closes.

## Revisions

- 2026-09-29: Core concepts now explicitly records the inherited #301 helpers because architecture checks include the stacked branch diff. Runtime behavior remains line-local; production typeahead evidence selected a command callback rather than an expression callback.

- 2026-09-29: App coexistence inspection found starter disables default mappings. Parent clarified app delivery is required: replace native exemption with an explicit registry shortcut; starter opts it in while preserving master-switch semantics for unspecified defaults. Preserve effective mappings for each configured key.

- Final design supersedes the initial native-map exemption: ARCH-DRY uses the configurable registry entry `pair_at`, with `chat_shortcut_pair_at` and per-entry mapping preservation. Starter explicitly opts in; unspecified shortcuts still obey `default_keymaps=false`.
- App revision GREEN: ui/keybindings passed 357 tests (15 pairing integration cases). Real installed Blink with actual starter options passed pairing/skip, Ctrl-n candidate selection, Ctrl-y acceptance, and subsequent pairing. Temporary smoke: `/tmp/parley-302-blink-smoke.lua`; output: `/tmp/parley-302-blink-smoke.log`. Focused luacheck: zero warnings/errors.
- `make test-spec SPEC=infra/starter` passed 185 tests, zero failures/errors.
