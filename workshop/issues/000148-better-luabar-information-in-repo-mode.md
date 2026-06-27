---
id: 000148
status: working
deps: []
created: 2026-06-27
updated: 2026-06-27
started: 2026-06-27T11:51:31-07:00
estimate_hours: 1.0
---

# better luabar information in repo mode

Repo mode supports development and we can have more compact information display on the luabar. basically whenever parley is in repo mode we use display those information:

[mode][repo][branch][repo-status]          [file-type]|[repo-mode][line-percent][line-location]
INSERT parley.nvim:main[*]                 ...


## Done when

- The luabar branch label renders `000149...` for `000149-harden-chat-history-search-shell-out-inputs`.
- Branch labels with no separator and at most 10 characters render unchanged.
- Branch labels longer than 10 characters render the first 10 characters plus `...`.
- The full branch name remains available to Git and every non-luabar code path.

## Spec

Repo-mode luabar should keep the current compact orientation shape while making
long SDLC branch names visually unambiguous. Only the displayed branch label is
shortened; the git branch name, issue filename, and any internal state remain
unchanged.

Branch labels are formatted by one pure helper in `lua/parley/lualine.lua`
(ARCH-PURE, ARCH-DRY):

- Split on the first word separator: space, `-`, or `_`.
- Take the first token if a separator exists; otherwise use the whole branch.
- Cap the selected text at 10 characters.
- Append `...` only when the display text is shorter than the original branch.

Examples: `main` -> `main`, `000149-harden-chat-history-search-shell-out-inputs`
-> `000149...`, `release_candidate` -> `release...`, and
`abcdefghijklmno` -> `abcdefghij...`.

## Estimate

```estimate
model: estimate-logic-v2
familiarity: 1.0
item: lua-neovim        design=0.2 impl=0.5
item: milestone-review  design=0.0 impl=0.2
design-buffer: 0.30
total: 1.0
```

Produced via `brain/data/life/42shots/velocity/estimate-logic-v2.md` against
`baseline-v2.md`. Method A only.

## Plan

- [x] Add failing unit coverage for the luabar branch-label formatter.
- [x] Implement the pure formatter and wire repo-mode branch display through it.
- [x] Run focused tests, then the relevant broader suite/lint gate.
- [ ] Close through `sdlc close` with verification evidence.

## Log

### 2026-06-27

- Claimed #148 after #149 branch display made the long SDLC branch slug look like
  an issue filename. Design keeps shortening strictly at the luabar display layer.
- TDD red: direct Plenary run of `tests/unit/super_repo_spec.lua` failed on
  missing `format_branch_label` / `create_branch_component`. The planned
  `make test-spec SPEC=super_repo` key is not mapped in `atlas/traceability.yaml`.
- TDD green: direct Plenary run of `tests/unit/super_repo_spec.lua` passed after
  adding the pure formatter and lualine branch-component wrapper.
- Verification: `make test` passed, including lint with 0 warnings / 0 errors,
  unit tests, integration tests, and arch tests. `make test-spec SPEC=ui/lualine`
  also passed after adding the traceability mapping for the lualine formatter
  coverage.
