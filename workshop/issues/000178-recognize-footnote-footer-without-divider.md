---
id: 000178
status: working
deps: []
github_issue:
created: 2026-07-08
updated: 2026-07-08
estimate_hours: 0.27
started: 2026-07-08T23:33:32-07:00
---

# recognize footnote footer without divider

## Problem

The #171 footnote-coloring fix still defines a managed footnote footer as a final
`---` divider followed by `[^id]: ...` lines. The desired footer boundary is
simpler: the first markdown footnote definition line (`[^id]: ...`) starts the
footer, even when no divider is present.

## Spec

`parley.define.managed_footnote_footer_range(lines)` returns the range from the
first line that starts with a markdown footnote definition pattern (`[^id]:`) to
EOF. It no longer requires a preceding `---` divider.

All current consumers keep deriving from that helper (ARCH-DRY, ARCH-PURE):
footnote diagnostics, footer stripping, and chat/markdown highlighting should
adopt the new boundary without duplicating parser logic.

## Done when

- A buffer with `[^asin]: ...` and no preceding `---` is recognized as having a
  managed footnote footer starting at that line.
- Footnote diagnostics and `ParleyFootnote` highlighting work for dividerless
  footers.
- Existing divider-based footers remain supported, but the footer range starts at
  the first `[^id]:` line, not at `---`.

## Plan

- [x] Add failing pure tests for dividerless footer range and stripping.
- [x] Add/update integration coverage for diagnostics/highlighting with a
  dividerless footer.
- [x] Change the pure footer helper to scan for the first footnote definition
  line and let consumers derive from it.
- [x] Run focused unit/integration verification plus lint/diff checks.

## Estimate

Derived via `estimate-logic-v3.1` against the repo-local calibration source from
`sdlc estimate-source` (stale but canonical for this repo).

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec design=0.03 impl=0.00
item: lua-neovim design=0.05 impl=0.15
item: milestone-review design=0.00 impl=0.02
total: 0.27
```

## Log

### 2026-07-08

- User clarified the #171 footer check should be based on the first `[^id]:`
  footnote definition line instead of a `---` + footnote block. Design keeps the
  grammar in `parley.define.managed_footnote_footer_range` so diagnostics and
  highlighters remain derived consumers.
- TDD red: dividerless footer unit/integration tests failed because the detector
  still required a final divider block and consumers skipped the first footnote
  definition line.
- Implemented the pure detector as "first footnote definition line to EOF" and
  updated diagnostics/update/strip loops to consume from that returned boundary.
- Verification: `make lint` passed; `nvim --headless -c "PlenaryBustedFile
  tests/unit/define_spec.lua"` passed; `nvim --headless -c "PlenaryBustedFile
  tests/integration/highlighting_spec.lua"` passed; scoped `git diff --check`
  passed. Full `make test` still fails in unrelated
  `tests/unit/tools_builtin_find_spec.lua` only under the parallel full-suite
  runner; that spec passes directly.
