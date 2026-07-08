---
id: 000169
status: codecomplete
deps: []
github_issue:
created: 2026-07-08
updated: 2026-07-08
estimate_hours: 0.76
started: 2026-07-08T10:31:04-07:00
actual_hours: 0.37
---

# diagnostic display should soft-wrap words

## Problem

Parley diagnostics display in `virtual_lines`, which does not soft-wrap long
messages reliably. Review diagnostics already hard-wrap their messages through
`skill_render.wrap`, but the width policy is private to `attach_diagnostics` and
define diagnostics compute their own fixed-ish width in `render_definition`.
Long definitions or explanations can still appear as over-wide diagnostic text
instead of word-wrapped rows.

## Spec

- Parley diagnostics shown through the shared `parley_skill` namespace are
  word-wrapped before they are passed to Neovim diagnostics.
- Review/edit diagnostics and define diagnostics use the same wrapping boundary
  so display behavior does not drift.
- Wrapping uses the current window's usable text width when available and keeps a
  conservative fallback for headless/tests.
- The display toggle remains responsible only for `virtual_lines` visibility,
  not message formatting.

ARCH-DRY: all Parley diagnostic messages derive from one wrap helper.
ARCH-PURE: word wrapping stays pure and unit-tested; the current-window width
lookup remains a thin IO helper.
ARCH-PURPOSE: the fix is not complete if define diagnostics can bypass the
shared wrapping path.

## Done when

- A long define diagnostic message is stored with word-wrapped newline breaks.
- Review diagnostics still wrap long explanations.
- Existing diagnostic toggling and undo/redo projection behavior continue to
  pass.
- Focused unit/integration tests and final verification pass.

## Estimate

Produced via `estimate-logic-v3.1` against the repo-local calibration source
reported by `sdlc start-plan` (stale but canonical for this repo). Method A
only.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec design=0.08 impl=0.00
item: lua-neovim design=0.12 impl=0.35
item: milestone-review design=0.00 impl=0.15
total: 0.76
```

## Plan

- [x] Add failing coverage for shared diagnostic message wrapping and define diagnostics.
- [x] Add a shared `skill_render` diagnostic-message helper using the existing wrap width logic.
- [x] Route review and define diagnostics through that helper.
- [x] Run focused and final verification.

## Log

### 2026-07-08
- 2026-07-08: closed — Implemented shared Parley diagnostic message wrapping via skill_render.format_diagnostic_message and diagnostic_wrap_width; routed review and define diagnostics through it; verified red/green focused specs, git diff --check on touched files, isolated rerun of tests/unit/tools_builtin_find_spec.lua after one transient full-suite failure, and final make test pass.; review verdict: FIX-THEN-SHIP
- Created after the operator clarified that diagnostic display should word
  soft-wrap. Design: keep Neovim `virtual_lines` configuration separate from
  message formatting; normalize messages before `vim.diagnostic.set`.
- Red tests confirmed the gap: `tests/unit/skill_render_spec.lua` failed because
  `format_diagnostic_message` did not exist, and
  `tests/integration/define_spec.lua` failed because a long define diagnostic
  exceeded the narrow diagnostic display width.
- Implemented `skill_render.format_diagnostic_message` and
  `diagnostic_wrap_width`, routed `attach_diagnostics` through the formatter,
  and routed define diagnostics through `define.format_definition` →
  `skill_render.format_diagnostic_message`.
- Focused verification passed:
  `nvim --headless -c "PlenaryBustedFile tests/unit/skill_render_spec.lua"` and
  `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`.
- Final `git diff --check` passed on touched code/test/docs/issue/plan files.
  First `make test` run failed in unrelated
  `tests/unit/tools_builtin_find_spec.lua`; isolated rerun of that spec passed.
  A second full `make test` run passed.
- Boundary review returned FIX-THEN-SHIP for a small ARCH-DRY/API leak:
  `define.format_definition` still had an `80` fallback when width was omitted.
  Added a red unit test, removed the fallback so nil passes through to
  `skill_render.format_diagnostic_message`, and verified
  `tests/unit/define_spec.lua`, `tests/unit/skill_render_spec.lua`, and
  `tests/integration/define_spec.lua`.
- Model-Revision: close reported the last five trusted estimates were all more
  than 2x over actual. For similarly small Lua/Neovim display fixes, reduce the
  default implementation/review padding unless the test setup has unknown
  integration risk.
