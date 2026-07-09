---
id: 000179
status: working
deps: []
github_issue:
created: 2026-07-09
updated: 2026-07-09
estimate_hours: 0.31
started: 2026-07-09T10:52:37-07:00
---

# structured footnote anchor spans

## Problem

Reloaded definition footnotes can show the floating definition window, but the
span highlight is only reliable for the current single-token inference before
`[^id]`. Multi-word terms such as `Advertising Cost of Sales[^acos]` collapse to
`Sales[^acos]`, and users need a markup-light way to persist the intended anchor
span across reloads.

## Spec

Definition footnotes may carry a structured display term at the start of the
footer definition:

```markdown
Advertising Cost of Sales[^acos]

[^acos]: "Advertising Cost of Sales". Ratio of ad spend to sales revenue.
```

or:

```markdown
Advertising Cost of Sales[^acos]

[^acos]: `Advertising Cost of Sales`. Ratio of ad spend to sales revenue.
```

When `define.footnote_diagnostics` sees a leading quoted or backquoted phrase in
the matching footnote definition, it uses that phrase to locate the nearest exact
body text before `[^id]`, allowing only whitespace or closing quote/bracket
characters between the phrase and the reference. The span covers that phrase
through the footnote reference. If the phrase is absent before the reference,
diagnostics fall back to the existing contiguous-token inference. The diagnostic
message should still use the human phrase as the term label and the remaining
definition body as the definition text.

The persisted reload path must continue to derive the floating-window trigger and
inline highlight from the diagnostic span (ARCH-DRY, ARCH-PURE, ARCH-PURPOSE).
No additional inline body markup is required.

## Done when

- A footnote whose definition starts with `"Advertising Cost of Sales". ...`
  produces a diagnostic/highlight span covering
  `Advertising Cost of Sales[^acos]` on reload.
- A footnote whose definition starts with `` `Advertising Cost of Sales`. ... ``
  behaves the same way.
- If the structured phrase is not immediately before the reference, the old
  single-token fallback remains unchanged.
- Persisted footnote highlights use the same span as the floating-window trigger.

## Plan

- [x] Add failing pure diagnostics tests for leading quoted/backquoted structured
  terms and fallback behavior.
- [x] Add a reload highlight regression that asserts the multi-word structured
  span is highlighted.
- [x] Implement structured term extraction and nearest-before-reference matching
  in `lua/parley/define.lua`.
- [x] Update atlas docs for the structured footnote convention.
- [x] Run focused tests plus lint/diff checks.

## Estimate

Derived via `estimate-logic-v3.1` against the repo-local calibration source from
`sdlc estimate-source` (stale but canonical for this repo).

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec design=0.03 impl=0.00
item: lua-neovim design=0.05 impl=0.18
item: atlas-docs design=0.01 impl=0.02
item: milestone-review design=0.00 impl=0.02
total: 0.31
```

## Log

### 2026-07-09

- User clarified that multi-word definition anchors should be persisted without
  adding extra body markup. Scope uses a leading quoted/backquoted phrase in the
  footnote definition as the source of truth for reload spans while preserving
  the current single-token fallback (ARCH-DRY, ARCH-PURE, ARCH-PURPOSE).
- TDD red: new pure diagnostics tests and reload highlight regression failed
  because persisted footnotes still expanded only the contiguous token before
  `[^id]` and kept the structured quote in the definition text.
- Implemented structured leading quote/backquote parsing in `define.lua`; the
  parsed term now provides the diagnostic label and nearest matching pre-ref
  span, which `skill_render.refresh_footnote_diagnostics` already uses for both
  float trigger and reload highlight.
- Verification: `make lint` passed; `nvim --headless -c "PlenaryBustedFile
  tests/unit/define_spec.lua"` passed; `nvim --headless -c "PlenaryBustedFile
  tests/integration/highlighting_spec.lua"` passed; scoped `git diff --check`
  passed. Full `make test` still fails only at the known parallel-run
  `tests/unit/tools_builtin_find_spec.lua` case; that spec passes directly.
