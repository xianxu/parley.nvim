---
id: 000171
status: codecomplete
deps: []
github_issue:
created: 2026-07-08
updated: 2026-07-08
estimate_hours: 0.43
started: 2026-07-08T17:14:54-07:00
actual_hours: 0.16
---

# footnote coloring

footnote should have dedicated color. right now it uses the color of last exchange. for example, if last exchange only has open question, footnote is displayed with question color.

## Problem

Managed definition footnotes are appended as a final markdown footer, but chat
highlighting treats an unanswered question as continuing to EOF. When the last
exchange is an open question, the footer inherits `ParleyQuestion`, so footnotes
take on the color of the last exchange instead of having a stable dedicated
appearance.

## Spec

Managed definition footnote footer lines render with a dedicated
`ParleyFootnote` highlight group in both chat and markdown buffers.

The managed-footer grammar remains single-sourced with the definition feature
(ARCH-DRY): highlighter code should consume a pure footer-range helper rather
than duplicate the `---` + `[^id]: ...` parser.

The dedicated footnote highlight must override chat block fallback coloring for
footer rows while leaving open issue/question highlighting unchanged for ordinary
question body lines.

## Done when

- A regression test covers an open question followed by a managed footnote footer.
- Footer divider and footnote definition rows receive `ParleyFootnote`.
- Footer rows no longer receive `ParleyQuestion` from an unanswered question block.
- Markdown buffers can use the same dedicated footnote group.

## Plan

- [x] Expose a pure managed-footnote footer range helper from `parley.define`.
- [x] Add unit coverage for the footer range helper.
- [x] Add highlighter regression coverage for an open question followed by a managed footer.
- [x] Apply `ParleyFootnote` in chat and markdown highlight computation.
- [x] Update atlas highlight docs and run focused plus repo verification.

## Estimate

Derived via `estimate-logic-v3.1` against the repo-local calibration source from
`sdlc estimate-source` (stale but canonical for this repo).

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec design=0.04 impl=0.00
item: lua-neovim design=0.09 impl=0.22
item: atlas-docs design=0.00 impl=0.02
item: milestone-review design=0.00 impl=0.02
total: 0.43
```

## Log

### 2026-07-08
- 2026-07-08: closed — Focused verification passed after review fix: make lint; nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"; nvim --headless -c "PlenaryBustedFile tests/integration/highlighting_spec.lua"; scoped git diff --check over #171 files. Full make test still fails in unrelated tests/unit/tools_builtin_find_spec.lua only under the parallel full-suite runner; that spec passes when run directly.; review verdict: FIX-THEN-SHIP
- 2026-07-08: closed — Focused verification passed: nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"; nvim --headless -c "PlenaryBustedFile tests/integration/highlighting_spec.lua"; scoped git diff --check over the #171 files. make test linted lua/tests successfully but fails in unrelated tests/unit/tools_builtin_find_spec.lua only under the parallel full-suite runner; that spec passes when run directly.; review verdict: FIX-THEN-SHIP

- Claimed the issue and inspected the chat/markdown highlighter paths. Root
  cause: open-question chat highlighting continues to EOF, so the final managed
  footnote footer is colored as `ParleyQuestion`.
- Added `define.managed_footnote_footer_range` so the footer grammar remains
  single-sourced with the definition feature (ARCH-DRY).
- Implemented `ParleyFootnote` for managed footer rows in both chat and markdown
  highlight computation; chat footers now terminate open-question color fallback.
- Verification: `nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"`
  passed; `nvim --headless -c "PlenaryBustedFile tests/integration/highlighting_spec.lua"`
  passed; scoped `git diff --check -- atlas/ui/highlights.md lua/parley/define.lua
  lua/parley/highlighter.lua tests/integration/highlighting_spec.lua
  tests/unit/define_spec.lua workshop/issues/000171-footnote-coloring.md`
  passed.
- Full `make test` linted `lua` and `tests` successfully but failed in unrelated
  `tests/unit/tools_builtin_find_spec.lua` under the parallel unit runner; that
  same spec passed when run directly with
  `nvim --headless -c "PlenaryBustedFile tests/unit/tools_builtin_find_spec.lua"`.
- Close review returned `FIX-THEN-SHIP` for one docs/config-surface gap:
  `config.highlight.footnote` was supported by highlighter code but missing from
  the default config reference. Added the default key and captured a lesson.
- Second close review returned `FIX-THEN-SHIP` for trailing whitespace in the
  generated review sidecar. Stripped the sidecar whitespace and captured a
  lesson.
