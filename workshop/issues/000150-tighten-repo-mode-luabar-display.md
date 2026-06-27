---
id: 000150
status: working
deps: []
github_issue:
created: 2026-06-27
updated: 2026-06-27
started: 2026-06-27T12:17:27-07:00
estimate_hours: 0.85
---

# tighten repo-mode luabar display

## Problem

Repo-mode luabar still spends space on labels that are redundant in a repo
checkout: the full path/current file consumes width, and the shortened branch
label drops the separator that makes SDLC issue IDs read like a prefix.

## Spec

When Parley is in repo mode (`config.repo_root` is set), lualine should favor
compact orientation:

- A shortened branch label keeps the separator that caused shortening, so
  `000132-sdlc-repo-lock` renders as `000132-...` instead of `000132...`.
- The cwd/directory display returns an empty string in repo mode.
- Lualine `filename` components are replaced with an empty component in repo
  mode.
- Non-repo mode keeps the existing file/directory behavior.

Implementation stays in `lua/parley/lualine.lua`: one pure repo-mode predicate
and the existing branch formatter/wrapper own the display rules (ARCH-PURE,
ARCH-DRY). The setup loop is the only integration point that mutates lualine
components.

## Done when

- `format_branch_label("000132-sdlc-repo-lock")` returns `000132-...`.
- Repo-mode directory formatting returns `""`.
- Repo-mode lualine setup hides `filename` components while preserving
  non-repo-mode filename components.
- Focused lualine tests and the broader verification gate pass.

## Estimate

```estimate
model: estimate-logic-v2
familiarity: 1.0
item: lua-neovim        design=0.15 impl=0.45
item: milestone-review  design=0.0 impl=0.20
design-buffer: 0.30
total: 0.85
```

Produced via `brain/data/life/42shots/velocity/estimate-logic-v2.md` against
`baseline-v2.md`. Method A only.

## Plan

- [x] Add failing unit coverage for separator-preserving branch shortening.
- [x] Add failing unit coverage for repo-mode cwd/filename suppression and
  non-repo-mode preservation.
- [x] Implement the pure predicate/formatting changes and lualine filename
  wrapper.
- [x] Run focused lualine tests and the broader verification gate.
- [ ] Close through `sdlc close` with verification evidence.

## Log

### 2026-06-27

- Follow-up to #148 from live luabar use: keep the visible branch separator and
  reclaim statusline space in repo mode by hiding cwd and filename components.
- Plan-quality noted the existing interview display branch; implementation keeps
  interview mode visible while suppressing repo-mode cwd/default directory labels.
- TDD red: `make test-spec SPEC=ui/lualine` failed on the missing separator,
  repo-mode directory suppression, and missing filename wrapper.
- TDD green: `make test-spec SPEC=ui/lualine` passed after updating the branch
  formatter, repo-mode predicate/directory behavior, and filename component
  wrapper.
- Verification: `make test` passed, including lint with 0 warnings / 0 errors,
  unit tests, integration tests, and arch tests.
