# Boundary Review — parley.nvim#280 (whole-issue close)

| field | value |
|-------|-------|
| issue | 280 — Seed selection branches with a quoted follow-up question |
| repo | parley.nvim |
| issue file | workshop/issues/000280-selection-branch-followup.md |
| boundary | whole-issue close |
| milestone | — |
| window | c231e52d3bfaab13eaec73983c1aa20ae2a4f8e3..cc802969438d02da32ab68b5081c57caf9c774ab |
| command | sdlc close --issue 280 |
| reviewer | codex |
| timestamp | 2026-09-26T00:14:01-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The #280 selection draft matches its contract, with 18 formatter tests and 63 branch-child tests passing. The wider pinned range has two blockers: launcher cleanup can delete a running editor’s profile, and the new starter shortcuts fail an existing architecture test.

1. **Strengths**

   - Selection creation shares the seed formatter with lazy inline-link creation.
   - Integration tests assert exact draft contents, insertion position, saved parent anchors, and unchanged plain/gathered branches.
   - Onboarding uses the existing proxy lifecycle owner and tests account/model changes through a stateful process fake.
   - README and atlas describe the new user-facing behavior.

2. **Critical findings**

   - [parley_app:38](/Users/xianxu/workspace/parley.nvim/parley_app:38): PID validation and launch/reset are not atomic. A controlled interleaving let launch and `--nuke` read the same stale PID, then start the editor before cleanup deleted its profile. Observed: `nuke_exit=0`, `editor_still_running=True`, `demo_exists=False`. Serialize ownership acquisition and deletion; test competing launches and launch/reset deterministically. **ARCH-ORDER**.

3. **Important findings**

   - [starter_config.lua:61](/Users/xianxu/workspace/parley.nvim/lua/parley/starter_config.lua:61): all three new `.shortcut` accesses fail the existing single-source architecture guard. With an indexed snapshot, the suite reports **24 passed, 1 failed**; removing those three lines yields **25 passed**. These configure options rather than bypass runtime key resolution, so use the guard’s explicit, justified exemption or integrate the overrides into the existing option-construction loop. Preserve the guard.

4. **Minor findings**

   None.

5. **Test coverage notes**

   - Passed: branch-submit **18**, branch-child **63**, launcher **6**, and the mapped inline-link suite.
   - Launcher tests cover sequential live-PID rejection but miss competing operations.
   - Architecture failure was reproduced after supplying the archive’s missing Git index.
   - Process-census verification was unavailable because the sandbox denied `ps`. Real Lualine compatibility was inspected but not rerun.

6. **Architectural notes**

   - **ARCH-DRY — pass:** shared seed formatting and existing command callbacks reused; architecture guard needs reconciliation above.
   - **ARCH-PURE — pass:** formatting remains pure; editor effects remain in the existing integration layer.
   - **ARCH-PURPOSE — pass for #280:** requested layout, cursor placement, and preservation requirements delivered.
   - **ARCH-MOCK — pass:** proxy regression uses the existing stateful fake.
   - **ARCH-CONSTRAINTS — pass:** selection remains single-line; no new unbounded fan-out.
   - **ARCH-SECURE — pass with the ordering finding:** profile/path checks exist; destructive authorization must remain valid until deletion.
   - **ARCH-ORDER — flag:** launcher ownership observation becomes stale before its effect.
   - **ARCH-FUNERAL — pass:** reusable profile has an explicit removal path; its concurrency safety needs repair.

7. **Plan revision recommendations**

   Append a dated `## Revisions` entry to #276 specifying atomic ownership across launch/reset and deterministic competing-operation tests. #280’s plan still matches its implementation.

```findings
findings:
  - id: new
    severity: Critical
    family: atomic-profile-ownership
    title: |
      Concurrent reset can delete a running editor's profile
    detail: |
      parley_app:38-51 checks the recorded PID separately from publishing launch ownership or deleting the demo. A deterministic launch/reset interleaving produced nuke_exit=0, editor_still_running=True, demo_exists=False. Serialize ownership validation, acquisition and reset, and add controlled competing-launch/reset regressions (ARCH-ORDER).
  - id: new
    severity: Important
    family: preserve-architecture-guards
    title: |
      Starter shortcut overrides fail the existing architecture suite
    detail: |
      lua/parley/starter_config.lua:61-63 introduces three accesses rejected by tests/arch/single_source_sweeps_spec.lua:662. The indexed pinned snapshot reports 24 passed and 1 failed; removing those accesses yields 25 passed. Integrate the overrides into option construction or explicitly justify the guard's supported exemption for configuration assembly, preserving runtime registry enforcement.
```
