---
id: 000172
status: working
deps: []
github_issue:
created: 2026-07-08
updated: 2026-07-08
estimate_hours: 0.94
started: 2026-07-08T11:38:22-07:00
---

# display markdown footnotes as diagnostics

## Problem

Define stores durable markdown footnotes such as `ASIN[^asin]` plus a final
managed footer line `[^asin]: Amazon Standard Identification Number.`. The
diagnostic displayed immediately after define is ephemeral Neovim state. After
leaving and reentering a chat buffer, or opening any markdown buffer containing
the same managed footnotes, the footnote remains in the file but no diagnostic
is recreated.

## Spec

- Markdown buffers should derive Parley diagnostics from persisted managed
  definition footnotes.
- Both chat markdown and non-chat markdown buffers should refresh these
  diagnostics on buffer entry, window entry, text changes, and writes.
- Diagnostics should anchor on each inline `[^id]` reference span and use the
  corresponding footer definition as the message, wrapped through the existing
  Parley diagnostic formatter.
- Parsing should remain conservative: use the existing final managed-footer
  shape, ignore ordinary horizontal rules, and ignore footnote definitions with
  no inline reference.
- Existing define behavior may still add the temporary highlight/projection
  snapshot for the just-created definition; rehydrated diagnostics do not need to
  recreate DiffChange highlights.

ARCH-PURE: parse persisted footnote diagnostics in `define.lua` as pure data.
ARCH-DRY: reuse the existing managed-footer rules and Parley diagnostic
formatter/namespace.
ARCH-PURPOSE: every markdown lifecycle path must refresh the diagnostics, not
only the immediate define render path.

## Done when

- Reopening or reentering a chat file with `term[^id]` and a managed footer
  displays the definition diagnostic.
- A non-chat markdown buffer with the same persisted footnote shape displays the
  diagnostic.
- Editing or writing a markdown buffer refreshes stale footnote diagnostics.
- Focused unit/integration tests and final verification pass.

## Estimate

Produced via `estimate-logic-v3.1` against the repo-local calibration source
reported by `sdlc start-plan` (stale but canonical for this repo). Method A
only.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec design=0.08 impl=0.00
item: lua-neovim design=0.15 impl=0.44
item: milestone-review design=0.00 impl=0.20
total: 0.94
```

## Plan

- [x] Add failing pure tests for persisted footnote diagnostic extraction.
- [x] Add failing integration coverage for markdown buffer refresh.
- [x] Implement pure extraction and a thin refresh integration.
- [x] Wire refresh into chat and markdown buffer lifecycle hooks.
- [x] Run focused and final verification.

## Log

### 2026-07-08
- Created after the operator reported that persisted define footnotes are not
  shown as diagnostics after reentering a chat buffer, and clarified that all
  markdown buffers should display footnotes as diagnostics.
- Red tests: `nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"`
  failed on missing `define.footnote_diagnostics`; `nvim --headless -c
  "PlenaryBustedFile tests/integration/highlighting_spec.lua"` failed on missing
  `skill_render.refresh_footnote_diagnostics` and missing lifecycle refresh.
- Implemented pure managed-footer footnote extraction, `parley-footnote`
  diagnostic refresh that preserves non-footnote diagnostics in the shared
  namespace, chat/markdown lifecycle refresh wiring, and immediate define render
  reuse of the same persisted-footnote diagnostic path.
- Focused green: `nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"`;
  `nvim --headless -c "PlenaryBustedFile tests/integration/highlighting_spec.lua"`;
  `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`.
- Final green: `git diff --check -- lua/parley/define.lua
  lua/parley/skill_render.lua lua/parley/highlighter.lua lua/parley/init.lua
  tests/unit/define_spec.lua tests/integration/highlighting_spec.lua
  tests/integration/define_spec.lua atlas/index.md atlas/chat/inline_define.md
  workshop/issues/000172-markdown-footnote-diagnostics.md
  workshop/plans/000172-markdown-footnote-diagnostics-plan.md`; `make test`.
