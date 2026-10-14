---
id: 000329
status: working
deps: []
github_issue:
created: 2026-10-14
updated: 2026-10-14
estimate_hours:
card_mirror: '93230e65b8801e0d9b081673ce1647d78283a24a' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-14T15:05:29-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:2
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "00ebca64", done: "aae9acc3"}
---

# Track generated TL skill ignore entries

## Problem

Refreshing Parley against ariadne#350 generates four missing .gitignore entries for the new TL skills. That leaves a tracked dirty file in every refreshed slot and obstructs clean workflow admission.

## Spec

Commit exactly the four weave-generated lines: /.agents/skills/xx-tl-lead, /.agents/skills/xx-tl-worker, /.claude/skills/xx-tl-lead, and /.claude/skills/xx-tl-worker. Preserve the generated block order and every other ignore entry. No runtime or local-gate configuration changes (ARCH-DRY).

## Core concepts

| Owner | Role |
| --- | --- |
| weave | Generates skill links and their ignore entries from the substrate |
| .gitignore | Carries generated skill ignores so compile keeps slots clean |

## Done when

- The non-process branch diff is exactly four added .gitignore lines, matching the four requested TL skill paths.
- All four generated paths are ignored; weave compile leaves the committed tree clean.
- Required suite, close review, and PR CI pass before landing.

## Plan

- [x] Restore the verified generated four-line diff on this issue branch and check exact scope/ignore behavior.
- [ ] Verify compile is idempotent and run the pushed-head full suite.

## Log

### 2026-10-14

- Hub unfroze only this essential chore; #319 remains frozen. Resting-branch weave refresh advanced Parley to 113d94f364db2a80876e614768ec17847e7f932c and private Ariadne to 7a7223628f1ec78a213ad4dd6ea4f0f9761c9f31. Confirmed the entire tracked diff was exactly 4 additions and 0 deletions in .gitignore, with the requested paths; preserved the generated file in /tmp, then restored the tracked file to allow issue branching. start-plan admitted the issue despite a docs-only catch-up warning caused by the four now-unignored generated links.
- This is generated ignore metadata only: no new runtime state, IO, dependencies, user flow, or artifact family. Verification uses the real generator and Git ignore engine; no implementation-mirroring test is needed for four reversible config entries.

- Applied only the captured generated entries after change-code. git check-ignore --no-index -v identifies the exact entry for all four skill links. weave compile completed and .gitignore remains byte-identical to the captured generator output; the only tracked implementation diff is 4 additions / 0 deletions in .gitignore. git diff --check passes.

- First full suite finished all remaining checks: only tests/integration/packaging_vm_spec.lua failed, in the guest fake chat's final current-buffer confinement assertion (guest chat file escaped isolated profile); all other files passed and the process census was clean. Suite exit 2, 3m16s, log prefix 534889349f49. The same spec passed all 17 cases against an isolated archive of main bb2ce85c3a4afb83efbfc97ca6f2420045eeb1aa. Checking the issue branch in isolation before a single justified full-suite retry; no packaging code changes are in scope.

- Main in a real detached Git worktree also passed all 17 packaging_vm cases. The unmodified spec failed once on the issue checkout, while a temporary diagnostic copy adding a confinement-state print passed without production changes. This is evidence of an intermittent/context-dependent failure, not a proven .gitignore defect or a repaired packaging issue. Retrying the required full suite once; if it recurs, report the blocking gate to the hub rather than broaden this chore under the freeze. Temporary diagnostics live outside the branch.
