# Boundary Review — parley.nvim#248 (whole-issue close)

| field | value |
|-------|-------|
| issue | 248 — Open inserted branch chat consistently |
| repo | parley.nvim |
| issue file | workshop/issues/000248-branch-chat-landing.md |
| boundary | whole-issue close |
| milestone | — |
| window | d2d0295a6eb9133a4490fe27584f9a0820386670..004011cc93380216ff22cb00cd255a338c031f1b |
| command | sdlc close --issue 248 |
| reviewer | codex |
| timestamp | 2026-09-14T08:59:43-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The implementation matches the issue’s landing and save-failure requirements, and the targeted suite passes. One documentation gap blocks this boundary: README still promises that visual branching leaves the user in the parent.

1. **Strengths**
   - `lua/parley/init.lua:2300`: one navigation helper reuses the chat parser for all creation paths.
   - `lua/parley/init.lua:2525`: visual navigation now depends on successfully saving the parent.
   - `tests/integration/branch_child_spec.lua:991`: behavioral tests cover five branch variants, failed writes, and controlled window/buffer changes.
   - Atlas documents the new landing and cancellation behavior.

2. **Critical findings:** None.

3. **Important findings**
   - `README.md:213` — “You stay in the parent” contradicts the new visual-branch navigation. README is unchanged in the pinned range. Update this paragraph to describe opening the child at the end of its first question header in Insert mode, consistently across chat creation paths. **ARCH-PURPOSE / docs update gate.**

4. **Minor findings:** None.

5. **Test coverage notes**
   - Ran `make test-spec SPEC=ui/keybindings`; exit 0.
   - Existing foreign-buffer ownership and streaming-refusal cases pass.
   - New tests observe the Insert-mode command; they do not actually enter Insert mode. The separately claimed smoke test was not independently reproduced.
   - No prior findings require disposition.

6. **Architectural notes**
   - **ARCH-DRY — pass:** shared landing helper eliminates duplicated navigation.
   - **ARCH-PURE — pass:** existing parser supplies location; editor effects remain in UI glue.
   - **ARCH-PURPOSE — flag:** runtime delivers the requested behavior, but README contradicts it.
   - **ARCH-MOCK — pass:** no new external dependency; tests exercise real temporary files and editor navigation.
   - **ARCH-CONSTRAINTS — pass:** one deferred callback and one child parse per gesture.
   - **ARCH-SECURE — pass:** filenames remain escaped; no new credential surface.
   - **ARCH-ORDER — pass:** controlled scheduler tests exercise cancellation after buffer, focus, and window changes.
   - **ARCH-FUNERAL — pass:** no new durable artifact family or background worker.

7. **Plan revision recommendations:** None; implementation remains within the documented scope.

```findings
findings:
  - id: new
    severity: Important
    family: user-docs-match-behavior
    title: |
      README still promises visual branching stays in the parent
    detail: |
      README.md:213 says “You stay in the parent,” but lua/parley/init.lua:2527 now schedules opening the child after saving its anchor. Update the branch instructions to describe first-question Insert-mode landing across chat creation paths; README has no update in this range (ARCH-PURPOSE, docs update gate).
```

---

## Re-review — 2026-09-14T09:02:11-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 248 — Open inserted branch chat consistently |
| repo | parley.nvim |
| issue file | workshop/issues/000248-branch-chat-landing.md |
| boundary | whole-issue close |
| milestone | — |
| window | d2d0295a6eb9133a4490fe27584f9a0820386670..9f6d1fe54f23a9de495adc33f45c2eb2681419de |
| command | sdlc close --issue 248 |
| reviewer | codex |
| timestamp | 2026-09-14T09:02:11-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The pinned implementation matches issue #248’s Spec and Plan. All branch creation paths share parser-directed landing after saving the parent. BR-1’s README contradiction is corrected, and the mapped test suite passes. No new findings.

1. **Strengths**
   - `lua/parley/init.lua:2300`: shared navigation helper removes duplicated landing logic.
   - `lua/parley/init.lua:2525`: visual branching checks parent-save success before navigation.
   - `tests/integration/branch_child_spec.lua:991`: behavioral tests cover five branch variants, failed saves, and deferred window/buffer changes.
   - README and atlas describe the updated behavior.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage notes**
   - Ran `make test-spec SPEC=ui/keybindings TEST_ENV_ROOT=/tmp/parley248-boundary-review`; exit 0.
   - Tests exercise real temporary files and navigation, including existing foreign-buffer and streaming guards.
   - Insert-mode requests are observed through a command spy; actual typing and the claimed full-suite run were not independently reproduced.

6. **Architectural notes**
   - **ARCH-DRY — pass:** one helper serves all creation paths.
   - **ARCH-PURE — pass:** existing parser supplies location; editor effects remain in UI glue.
   - **ARCH-PURPOSE — pass:** all specified paths and documentation agree.
   - **ARCH-MOCK — pass:** no new external dependency; real editor/filesystem integration is exercised.
   - **ARCH-CONSTRAINTS — pass:** one scheduled callback and child parse per gesture.
   - **ARCH-SECURE — pass:** escaped filenames and isolated test storage remain intact.
   - **ARCH-ORDER — pass:** controlled scheduling tests cover invalid window, changed focus, and changed buffer.
   - **ARCH-FUNERAL — pass:** no new durable artifact family or background worker.

7. **Plan revision recommendations:** None.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      README.md:213 removes the parent-focus promise, and README.md:221–223 describes first-question Insert-mode landing across chat cases. This matches open_branch_question at lua/parley/init.lua:2300 and its three call sites. The pinned correction is prose-only; existing behavioral tests pass.
```
