---
id: 000163
status: codecomplete
deps: []
github_issue:
created: 2026-07-07
updated: 2026-07-07
estimate_hours: 0.45
started: 2026-07-07T23:39:02-07:00
actual_hours: 0.23
---

# repo mode status bar improvements

Previously we simplified status bar when we are in repo mode. Though, it's
currently not very clear which repo we are in (the cwd). Let's display that
right beside the repo/super-repo symbol. I can't find the exact symbol, but
looks like ◉, and then we should display ◉-brain, for brain repo-ed cwd.

## Problem

In repo mode, the status bar indicates the mode but does not make the current
repo identity obvious enough. When working across repos, the user needs a compact
cwd/repo cue in the status bar itself.

## Spec

- Display the current repo name next to the repo/super-repo symbol in repo mode.
- Use the existing repo-mode symbol treatment and append the repo name compactly,
  e.g. `◉-brain` for the brain repo cwd.
- Keep the simplified status bar shape; this is a clarity tweak, not a new
  status area.

## Done when

- Repo mode status bar shows the current repo name beside the repo/super-repo
  symbol.
- The display is stable across at least the brain repo and a normal repo cwd.

## Plan

- [x] Update `lua/parley/lualine.lua` `format_mode(parley_instance)` so repo and
  super-repo states render the existing glyph plus `-<repo_label>`, using
  `require("parley.issues").repo_label(parley.config.repo_root)` as the only
  repo-name formatter (`ARCH-DRY`, `ARCH-PURE`).
- [x] Preserve global mode as the bare existing glyph (`○`) and preserve the
  existing repo/super-repo glyphs themselves (`⊚`, `⦿`); only append the compact
  repo label in repo-backed modes.
- [x] Update `tests/unit/super_repo_spec.lua` lualine coverage to assert exact
  outputs for global (`○`), normal repo (`⊚-parley.nvim`), brain repo
  (`⊚-brain`), and super-repo (`⦿-parley.nvim`) (`ARCH-PURPOSE`).
- [x] Update `atlas/ui/lualine.md` and `atlas/modes/super_repo.md` so the
  documented mode glyph output matches the new repo-label suffix behavior.

## Estimate

Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against
`baseline-v3.1.md`. Method A only.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: lua-neovim design=0.10 impl=0.20
item: atlas-docs design=0.05 impl=0.05
design-buffer: 0.30
total: 0.45
```

## Log

### 2026-07-07
- 2026-07-07: closed — Repo-mode lualine glyphs show repo labels for normal and brain cwd; direct super_repo spec red/green verified; full make test passed after known find-spec parallel flake passed in isolation and retry.; review verdict: SHIP

- Moved from `pair#102` to `parley.nvim#163`; this belongs with the parley repo
  mode/status bar implementation.
- Planning: reuse `issues.repo_label(repo_root)` for repo names (`ARCH-DRY`),
  keep the lualine change inside the existing formatter boundary (`ARCH-PURE`),
  and cover both brain and normal repo examples from the issue (`ARCH-PURPOSE`).
- Plan-quality gate first returned FAILURE for vague checklist items; refined
  the plan with exact files/functions/assertions, then `sdlc change-code` passed
  with INFO. Estimate-quality passed with INFO.
- TDD red: direct Plenary run of `tests/unit/super_repo_spec.lua` failed on
  `lualine.format_mode` returning bare `⊚` instead of `⊚-parley.nvim`.
- TDD green: `tests/unit/super_repo_spec.lua` passed after `format_mode` started
  suffixing repo-backed glyphs via `issues.repo_label(repo_root)`.
- Verification: `make test` initially hit the known parallel
  `tests/unit/tools_builtin_find_spec.lua` flake; that file passed in isolation,
  and a full `make test` retry passed with lint at 0 warnings / 0 errors and all
  unit/integration specs green.
