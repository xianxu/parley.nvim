---
id: 000268
status: open
deps: []
github_issue:
target: transcript-is-the-whole-truth
created: 2026-09-18
updated: 2026-09-18
estimate_hours:
---

# Round-trip provenance: a chat file should reproduce its answers

## Problem

Split out of parley#261's audit (2026-09-17 Revisions, "Deferred to a new
issue"). #261 is about state outside the file *blocking* work on it. This issue
covers the other half of the same target: hand the file to someone else, or
reopen it later, and the same submission should get the same answer. The audit
found four ways that fails today (line numbers as of `ee0c5f6d`; re-verify
before planning):

- **Stock config records no model, provider or system prompt in the file.**
  `config.lua` selects `short_chat_template`, which (`defaults.lua`) has no
  `{{optional_headers}}` placeholder. So the values computed in `init.lua`'s
  `new_chat` are substituted into nothing. Behavior comes from `_state.agent`
  in `state.json`, and `_state.web_search` silently swaps the model
  (`providers.lua`). The on-screen badge shows `_state.agent`, not the header
  (`highlighter.lua`).
- **With the long template, `new_chat` writes a header its own parser cannot
  read.** `new_chat` runs `template:gsub("_","\\_")` over the rendered
  template, while `chat_parser.lua` requires `[%w_%.%+]+` for header keys. So
  `system\_prompt:` parses to `nil`, and a pinned prompt shown in the file is
  not in effect. `get_default_template` does not escape: three creators, three
  behaviors.
- **Copying a chat cross-contaminates sidecars keyed on `(timestamp, dir)`.**
  Deleting the copy `remove_tree`s the shared asset folder and destroys the
  original's images (`assets.lua`).
- **No external-change detection.** `checktime`/`FileChangedShell` appear only
  in `tools/file_refresh.lua`. Combined with `noswapfile` and the 1 s debounced
  `silent! write`, a `git checkout` under a live buffer leaves only Neovim
  core's mtime guard, which surfaces as a modal prompt from a background timer.

## Spec

To be brainstormed. The target's open question "How far does provenance belong
in the file?" is this issue's first decision.

## Done when

- A chat created under any shipped template records, in headers its own parser
  reads, what the next submission will use: model, provider and system prompt.
  A test round-trips each creator.
- The header shown and the header in effect cannot disagree: the badge derives
  from the file.
- Copying and then deleting a chat never removes the original's sidecar data.
- An external change to a loaded chat file is detected and reconciled without a
  modal prompt from a timer.

## Plan

- [ ] Brainstorm how much provenance belongs in the file (target open question).
- [ ] Design and implement per the Spec once settled.

## Log

### 2026-09-18

Filed from parley#261's deferred round-trip findings (#261 Log, 2026-09-17
"Round-trip: the transcript is not sufficient to reproduce a chat").
