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
- [x] Verify compile is idempotent and run the pushed-head full suite.

## Log

### 2026-10-14
- 2026-10-14: closed — BR-1 measured host proof in issue Log: pinned code/substrate Git hashes, weave compile exit 0, .gitignore SHA256 identical before/after, empty porcelain status before/after, unchanged HEAD. Exact config diff remains four generated ignore additions and all four match Git rules. Full suite passed all 427 spec files on the code-equivalent 4d893eaba7b8310f887810369cc3ead3e5bd7b6c; preserved log checksum was independently verified in round 1. GitHub success recording retry remains pending and merge must wait. No new architectural surface: generated ignore metadata only.; review verdict: SHIP

- Hub unfroze only this essential chore; #319 remains frozen. Resting-branch weave refresh advanced Parley to 113d94f364db2a80876e614768ec17847e7f932c and private Ariadne to 7a7223628f1ec78a213ad4dd6ea4f0f9761c9f31. Confirmed the entire tracked diff was exactly 4 additions and 0 deletions in .gitignore, with the requested paths; preserved the generated file in /tmp, then restored the tracked file to allow issue branching. start-plan admitted the issue despite a docs-only catch-up warning caused by the four now-unignored generated links.
- This is generated ignore metadata only: no new runtime state, IO, dependencies, user flow, or artifact family. Verification uses the real generator and Git ignore engine; no implementation-mirroring test is needed for four reversible config entries.

- Applied only the captured generated entries after change-code. git check-ignore --no-index -v identifies the exact entry for all four skill links. weave compile completed and .gitignore remains byte-identical to the captured generator output; the only tracked implementation diff is 4 additions / 0 deletions in .gitignore. git diff --check passes.

- First full suite finished all remaining checks: only tests/integration/packaging_vm_spec.lua failed, in the guest fake chat's final current-buffer confinement assertion (guest chat file escaped isolated profile); all other files passed and the process census was clean. Suite exit 2, 3m16s, log prefix 534889349f49. The same spec passed all 17 cases against an isolated archive of main bb2ce85c3a4afb83efbfc97ca6f2420045eeb1aa. Checking the issue branch in isolation before a single justified full-suite retry; no packaging code changes are in scope.

- Main in a real detached Git worktree also passed all 17 packaging_vm cases. The unmodified spec failed once on the issue checkout, while a temporary diagnostic copy adding a confinement-state print passed without production changes. This is evidence of an intermittent/context-dependent failure, not a proven .gitignore defect or a repaired packaging issue. Retrying the required full suite once; if it recurs, report the blocking gate to the hub rather than broaden this chore under the freeze. Temporary diagnostics live outside the branch.

- The retry on 4d893eaba7b8310f887810369cc3ead3e5bd7b6c passed every test, including packaging_vm_spec.lua, with a clean process census. SDLC then failed to upload its success because api.github.com was unreachable. Preserved the passing log at /tmp/parley329-suite-pass-unrecorded.log (sha256 b0c84626368dcec928cf7644b257a458b5ee08cef5890eecbe546a4e7eb156e5). The binary has no record-only recovery verb, so an unrestricted-network rerun is queued on that same code head. Close review can use the executed passing suite; landing must still wait for recorded success. No packaging patch or scope expansion was made.

### BR-1 — measured host compile evidence

Measured on parley.nvim:2 with a clean tree and the intended private substrate. Captured Git HEAD and substrate HEAD using git rev-parse, captured git status --porcelain and .gitignore SHA256, ran weave compile, then repeated all observations. The command exited 0 and reported applied 115 actions. No bootstrap workaround or reviewer-environment configuration was changed.

```json
{
  "head": "1369357e7e9c478eb1a93056a70934148775eb3a",
  "substrate_head": "7a7223628f1ec78a213ad4dd6ea4f0f9761c9f31",
  "compile_exit": 0,
  "ignore_sha256_before": "a5aaf9187de66c1e5146ee6545bd019af269c3ea7e5c88ac0da64b69fe3f0d40",
  "ignore_sha256_after": "a5aaf9187de66c1e5146ee6545bd019af269c3ea7e5c88ac0da64b69fe3f0d40",
  "status_porcelain_before": "",
  "status_porcelain_after": "",
  "head_after": "1369357e7e9c478eb1a93056a70934148775eb3a"
}
```

The measured head adds only review metadata beyond the first review pin; .gitignore is identical at both heads. This supplies the requested proof for all four generated entries without expanding the implementation. Compiler stdout is preserved at /tmp/parley329-compile-evidence.log.
