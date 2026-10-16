# Boundary Review — parley.nvim#236 (whole-issue close)

| field | value |
|-------|-------|
| issue | 236 — delete unreachable modules and dead config |
| repo | parley.nvim |
| issue file | workshop/issues/000236-dead-code-sweep.md |
| boundary | whole-issue close |
| milestone | — |
| window | 5abad04737d396828eb9614b28c20dbec43d7486..d1daab0afe2a00a881424d67f54759925983f252 |
| command | sdlc close --issue 236 |
| reviewer | claude |
| isolation | checkout |
| timestamp | 2026-10-16T05:53:35-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Review in progress: I've found some stale docs and am now running the affected specs.

Issue-vocabulary content is covered elsewhere. Running the specs now.

Specs printed no output, so I'm debugging the test harness invocation.

Specs pass. Next I'll plant an orphan module to confirm the reachability check actually fails on one.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

**Verdict: fix then ship.** The code is right, but one Done-when clause isn't met. Each deletion holds up against the code at the base commit. The new reachability check is real: both its specs pass on the tree, and when I planted `lua/parley/zz_planted.lua` (then removed it) it failed and named `parley.zz_planted`. `review_spec.lua`, repointed at `parley.skills.review`, passes in `make test-spec SPEC=modes/review`. Keeping azure and deleting discovery are both recorded in the Log as TL decisions, and #115 has a restore note naming `5abad047…`. The gap is this clause: "`rg` over `atlas/` finds no reference to a deleted module". `atlas/skills/skill-system.md` still documents the deleted virtual provider and the removed `default_stack` generator seams. A few code comments describe the same removed seams.

1. **Strengths**
   - `tests/arch/module_reachability_spec.lua:33-50`: the graph walk `unreached(sources, entries)` is a pure function with its own synthetic-graph test (an orphan that requires other modules is still unreached). The IO stays in `tree()`, which follows ARCH-PURE.
   - The entry list is taken from the live `tools.BUILTIN_NAMES` / `OPTIONAL_NAMES` rather than copied (ARCH-DRY), and the check asserts it read more than 100 modules, so a broken scan can't pass as an empty tree.
   - The check's limit (it can't see a module that is required but never used) is written down in the spec header, as the Spec asked.
   - The check found one more real orphan, `tools/version.lua`, and it was deleted.
   - The cleanup is thorough: the spawn_seam allowlist entry, the traceability blocks and the `get_agent()` docstring all went with the code they described.

2. **Critical:** none.

3. **Important**
   - `atlas/skills/skill-system.md:40-42` still says "`skill_registry.default_stack` also accepts explicit repo/virtual generator providers", and line 68 says "Load disk/virtual providers". Both the seams and `providers.virtual` are deleted, so this breaks the atlas clause of Done when.
     - **Every stale mention of the removed virtual/repo seams:**
       - `atlas/skills/skill-system.md:40-42`
       - `atlas/skills/skill-system.md:68`
       - `lua/parley/init.lua:107`: "(plugin-disk ∪ user-disk ∪ repo/virtual seams)"
       - `lua/parley/skill_manifest.lua:4`: "(disk / user / repo / virtual)"
       - `lua/parley/skill_manifest.lua:14`: "unified disk/virtual"
     - **Fix:** delete the paragraph at lines 40-42, change line 68 to "disk providers", and update the three code comments.

4. **Minor**
   - `atlas/index.md:96`: the `## 10. Discovery Registry` heading is still there with nothing under it. Remove it and renumber the sections that follow.
   - `lua/parley/skill_registry.lua:66-67` and `atlas/modes/review.md:164`: comments about removed things. The registry one could go; the review.md one is useful to readers.
   - The deleted `atlas/discovery/registry.md` had an "Issue vocabulary" section. I checked: the same content lives in `atlas/issues/issue-management.md` and `atlas/infra/workflow.md`, so nothing was lost.

5. **Test coverage**
   - The reachability check is covered both ways: green on the tree and red on a planted orphan (verified above).
   - `review_spec` now runs against the real module.
   - Deleting the 3-case `providers.virtual` block was correct: the code it tested is gone.
   - I did not run the full `make test`. The Log reports 6397 → 6319 `it()` cases, which fits the specs that were deleted.

6. **Architecture**
   - **ARCH-DRY: pass.** The new spec adds no duplicated logic. The six-pattern `EDGES` set is local to the spec, and that's fine.
   - **ARCH-PURE: pass.** The pure graph walk is separate from the filesystem and git reads.
   - **ARCH-PURPOSE: flag, low severity.** The deletion is done in code, but its documentation leftovers are not, which is the Important finding above. The check's blind spot for "required but never used" modules is documented as the Spec required. A reader-based check is a separate extension, not a deferral of this issue's purpose.

7. **Plan revisions:** none. The Plan and Log match the code. Recording azure as kept, with the reason, satisfies the "kept with the reason recorded in the Log" clause.

```findings
findings:
  - id: new
    severity: Important
    kind: defect
    family: deleted-surface-stale-reference
    title: |
      atlas/skills/skill-system.md still documents the deleted virtual provider and default_stack generator seams
    detail: |
      This breaks the Done-when clause that atlas/ must not reference a deleted module. Every stale mention of the removed virtual/repo seams: atlas/skills/skill-system.md:40-42 (says default_stack accepts repo/virtual generator providers); atlas/skills/skill-system.md:68 ("Load disk/virtual providers"); lua/parley/init.lua:107 ("repo/virtual seams"); lua/parley/skill_manifest.lua:4 ("disk / user / repo / virtual"); lua/parley/skill_manifest.lua:14 ("unified disk/virtual"). Fix: delete the paragraph at lines 40-42, change line 68 to "disk providers", and update the three code comments.
  - id: new
    severity: Minor
    kind: defect
    family: deleted-surface-stale-reference
    title: |
      atlas/index.md keeps an empty "10. Discovery Registry" section heading
    detail: |
      Its only entry was removed. Delete the heading and renumber the sections after it (Traceability becomes 10).
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"8aa21b78-3040-467b-8f7e-15f5335aa305","repository":"github.com/xianxu/parley.nvim","issue_id":"000236","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/c82aa16ba0e06af0","reviewed_head":"d1daab0afe2a00a881424d67f54759925983f252","slot":"parley.nvim:4","requested_at":"2026-10-16T12:50:34.838505Z"},"phase":"finished","pid":16814,"started_at":"2026-10-16T12:50:34.993561Z","finished_at":"2026-10-16T12:53:34.233717Z","session_id":"3d6f5382-07ef-49f7-9588-abb70e9bbacd","outcome":"returned"}] -->

---

## Re-review — 2026-10-16T05:56:06-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 236 — delete unreachable modules and dead config |
| repo | parley.nvim |
| issue file | workshop/issues/000236-dead-code-sweep.md |
| boundary | whole-issue close |
| milestone | — |
| window | 5abad04737d396828eb9614b28c20dbec43d7486..c1dbd49954e584805d1774b3a9958b030d244731 |
| command | sdlc close --issue 236 |
| reviewer | claude |
| isolation | checkout |
| timestamp | 2026-10-16T05:56:06-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Checking that the reachability spec runs, then I'll write up the verdict.

Still setting up the test environment to run the three touched specs.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

Round 2 fixed the atlas half of BR-1. `atlas/skills/skill-system.md` now describes the real two-provider stack (plugin, then user). BR-2 is also fixed: the empty Discovery heading is gone and Traceability is now section 10. The code half of BR-1 is still open. The finding named three Lua comments as part of its fix, and all three still describe the deleted repo/virtual seams. The Log says the re-sweep covered only "`atlas/` and README by concept name", so `lua/` was never re-checked. The Done-when clause about atlas now holds. Those three comment edits are the only thing left. I ran the three touched specs at head and all pass: reachability 2/2, review 48/48, skill_providers 7/7.

### 1. Strengths
- `tests/arch/module_reachability_spec.lua:33-50`: `unreached()` is a pure function, and its first test plants an orphan in a fake graph, so the checker's own logic is tested without reading the repo. The planted orphan also requires other modules, which catches the mistake of treating a requirer as reached. The size check (`> 100` modules) catches a scan that silently selects nothing.
- The test states its limit in its header (lines 17-19): it finds orphaned files, not modules that are required but never used. That limit is the ARCH-PURPOSE point the Spec asked to have stated.
- The check found a real orphan (`tools/version.lua`) and two gaps in its own entry list (`builtin.ack` and `editor_bundle`). Both are recorded in the Log.
- `review_spec.lua` was repointed at `parley.skills.review` and runs all 48 cases, so the marker-parsing coverage survived deleting the shim.
- `skill_registry.current()` lost its `opts` parameter cleanly, and the docstrings at `skill_registry.lua:55,72` match the new signature.

### 2. Critical findings
None.

### 3. Important findings
- **BR-1 (not addressed): the code comments still describe the deleted seams.** These are the three lines the finding named, plus nothing else found by grep over `lua/` for `repo/virtual|disk/virtual|virtual provider|repo_generators|virtual_generators|providers.virtual|repo_discovery`:
  - `lua/parley/init.lua:107`: "(plugin-disk ∪ user-disk ∪ repo/virtual seams)". Should say "(plugin-disk ∪ user-disk)".
  - `lua/parley/skill_manifest.lua:4`: "(disk / user / repo / virtual)". Should say "(plugin / user disk)".
  - `lua/parley/skill_manifest.lua:14`: "unified disk/virtual". Should say "closure over the provider's source", or simply "the body".
  - The rule for the fix: sweep each deleted concept name across `lua/` comments as well as `atlas/` and README. Round 2 ran the concept sweep only over the docs.

### 4. Minor findings
- `skill_registry.lua:66-67` adds a comment saying the seams "were removed in #236". A comment about code that no longer exists will go stale; git history already records this. Optional.

### 5. Test coverage notes
- Reachability check: red on a planted orphan (synthetic-graph test) and green on the tree. I confirmed both at head.
- The deleted `providers.virtual` spec block went with its code. The remaining `providers.disk` cases (7) still cover the only provider.
- The orphan-process check was skipped in this environment because `ps` is unavailable. That has no bearing on this diff.

### 6. Architectural notes
- **ARCH-DRY: pass.** The diff is almost entirely deletion. The reachability spec reuses `arch_helper.worktree_files`, and the `EDGES` patterns are shared between scanning `lua/` sources and the packaging/scripts entry points.
- **ARCH-PURE: pass.** The graph walk (`unreached`) is pure and tested directly. File IO stays in `tree()`.
- **ARCH-PURPOSE: pass, with the BR-1 remainder.** Every row is either deleted or kept with its reason in the Log: azure is kept because it is reachable, and the panvimdoc markers were already gone. The check enforces the "no orphans" rule rather than just documenting it. The leftover seam comments are the one part of the stale-reference cleanup still to finish.

### 7. Plan revision recommendations
None. The Core concepts rows (`current` changed, `virtual` deleted) match the code.

```findings
dispose:
  - id: BR-1
    disposition: not-addressed
    note: |
      atlas/skills/skill-system.md:40-42 and :68 are fixed, but the three code comments the finding named are unchanged: lua/parley/init.lua:107 (repo/virtual seams), lua/parley/skill_manifest.lua:4 (disk / user / repo / virtual) and :14 (unified disk/virtual). The round-2 concept sweep covered only atlas/ and README, not lua/ comments.
  - id: BR-2
    disposition: addressed
    note: |
      atlas/index.md: the empty "10. Discovery Registry" heading is deleted and Traceability is renumbered to "## 10."
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"cb16029b-eaf4-40ec-ba3c-c563fe688100","repository":"github.com/xianxu/parley.nvim","issue_id":"000236","recipe":"small-diff-review","round":2,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/880a7638b0d9ddb5","reviewed_head":"c1dbd49954e584805d1774b3a9958b030d244731","slot":"parley.nvim:4","requested_at":"2026-10-16T12:54:45.403943Z"},"phase":"finished","pid":25919,"started_at":"2026-10-16T12:54:45.54805Z","finished_at":"2026-10-16T12:56:05.96242Z","session_id":"a091b382-760b-45d7-b95a-c80c345e8dd5","outcome":"returned"}] -->
