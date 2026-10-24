# Boundary Review — parley.nvim#425 (whole-issue close)

| field | value |
|-------|-------|
| issue | 425 — Alt+o with no link under the cursor flashes the winbar instead of a raw gf error |
| repo | parley.nvim |
| issue file | workshop/issues/000425-alt-o-with-no-link-under-the-cursor-flashes-the-winbar-instead-of-a-raw-gf-error.md |
| boundary | whole-issue close |
| milestone | — |
| window | 5958d5f2aa7899ed3fb6b141ec4ca6a21aa8c32b..4a0a48cf59449683f1672a0062f57db6f28b4e2d |
| command | sdlc close --issue 425 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-23T12:49:33-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The intended no-target feedback works in the committed tests, and native error handling remains appropriately narrow. Independent probes found two correctness regressions: Insert-mode cursor movement and suppression of existing leave reminders. The README update gate is also incomplete.

```findings
findings:
  - id: new
    severity: Critical
    kind: defect
    family: preserve-edit-position-on-noop
    title: |
      No-target Alt+o moves the Insert-mode cursor left
    detail: |
      lua/parley/init.lua:5150–5152 restores Insert mode after stopinsert without restoring the insertion position. Native mapping probes starting at zero-based columns 1, 2 and 4 in "error" resume at columns 0, 1 and 3 respectively, so subsequent typing changes location. The sole new on_no_file callback is the affected site; sweep nonzero positions, including end-of-line, across absent/custom bars. Preserve the original insertion position through mode restoration and add native regressions; existing cases only exercise column zero. ARCH-PURPOSE: a no-target gesture must preserve editing position.
  - id: new
    severity: Critical
    kind: defect
    family: coalesce-only-equivalent-feedback
    title: |
      A no-target pulse suppresses the unsubmitted-turn leave reminder
    detail: |
      lua/parley/document_band.lua:233 coalesces requests solely by source buffer, so flash_notice and flash for the same source are treated as equivalent. All four interaction probes fail: queued/active notice crossed with buffer departure/WinLeave produces zero unsubmitted warnings instead of one, violating README.md:88–92. These are the two entry points sharing this guard. Distinguish pulse purpose and let leave feedback supersede a quiet notice while retaining duplicate leave-event coalescing; cover all four combinations. ARCH-PURPOSE: reuse must preserve the existing reminder contract.
  - id: new
    severity: Important
    kind: defect
    family: document-user-visible-behavior
    title: |
      README update appears missing for Alt+o no-target feedback
    detail: |
      README.md:252–266 documents Alt+o and its native fallback, but the pinned range contains no README change describing the new quiet flash and temporary-bar restoration. This is the only changed user-facing gesture in the window; atlas/context/file_references.md:61–64 already documents it. Add the corresponding README explanation to satisfy the requested docs gate.
```

1. **Strengths**

   - Only E446/E447 are handled, and only when Alt+o supplies the callback. Direct smart-gf errors, explicit missing-link diagnostics and E37 remain covered.
   - The implementation reuses the existing band owner and restoration machinery.
   - Native tests exercise Normal/Insert input, absent/custom bars, blank/missing-word cases and subsequent typing.

2. **Critical findings**

   Both behavioral findings above require fixes and regression tests before crossing the boundary.

3. **Important findings**

   Update the README’s Alt+o section with the new no-target behavior.

4. **Minor findings**

   None.

5. **Test coverage notes**

   - `make test-spec SPEC=context/file_references` passed, including all 14 new cases.
   - Shared renderer tests: 32 passed. Existing leave-reminder tests: 18 passed.
   - Additional probes failed at all three nonzero insertion positions and all four pulse-interaction combinations.
   - Evidence: [cursor probes](/Volumes/TestScratch/review425-akzdbmwm/position2.log), [pulse probes](/Volumes/TestScratch/review425-akzdbmwm/probe2.log).
   - Process censuses were clean; tracked files remain unchanged.

6. **Architectural notes**

   - **ARCH-DRY — pass:** shared pulse ownership avoids duplicated timer/restoration logic.
   - **ARCH-PURE — pass:** changes remain within the thin editor/UI boundary.
   - **ARCH-PURPOSE — flag:** position preservation and existing reminder behavior need correction.
   - **ARCH-EVOLVE — pass:** no persisted-format evolution.

7. **Plan revision recommendations**

   Add `## Revisions` entries covering insertion-position preservation, pulse-purpose coalescing with the four-case interaction matrix, and README completion. No Core concepts table is present to cross-check.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"ffacbe09-3a01-4c02-ad4e-e0624b39a0a6","repository":"github.com/xianxu/parley.nvim","issue_id":"000425","recipe":"small-diff-review","round":1,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/d334469990eddf55","reviewed_head":"4a0a48cf59449683f1672a0062f57db6f28b4e2d","slot":"parley.nvim:2","requested_at":"2026-10-23T19:45:35.900235Z"},"phase":"finished","pid":95105,"started_at":"2026-10-23T19:45:36.065997Z","finished_at":"2026-10-23T19:49:32.226935Z","session_id":"01a16a4c-21ad-7d00-b3bd-cefd09c15be0","outcome":"returned"}] -->
