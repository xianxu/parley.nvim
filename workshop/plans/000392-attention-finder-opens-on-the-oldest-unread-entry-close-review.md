# Boundary Review — parley.nvim#392 (whole-issue close)

| field | value |
|-------|-------|
| issue | 392 — attention finder opens on the oldest unread entry |
| repo | parley.nvim |
| issue file | workshop/issues/000392-attention-finder-opens-on-the-oldest-unread-entry.md |
| boundary | whole-issue close |
| milestone | — |
| window | 1d4abae2f61a377d6dfbc17357c8f0250f0cce79..9c8302396111b0e2904588ef2f172cf729b6929f |
| command | sdlc close --issue 392 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-18T21:48:39-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The oldest-unread choice, scope handling, and unchanged tree order work. One correctness bug blocks shipping: a background probe repaint scrolls the selected unread entry out of view. The mapped tests pass, but an additional native-picker regression reproduces this failure.

```findings
findings:
  - id: new
    severity: Critical
    kind: defect
    family: picker-repaint-preserves-viewport
    title: |
      Background refresh hides the initially selected unread entry
    detail: |
      At lua/parley/float_picker.lua:1771-1775, update calls apply_filter(false), whose set_selection(sel_idx) resets the top-anchored viewport to row 1; preserve_view then preserves that reset viewport. Reproduced in a disposable pinned-head copy by completing a held waiting probe immediately after attention_finder_spec.lua:149: child.md remains selected, but visible() fails. Family enumeration: successful and failed probe repaints share attention.lua:306; both current-slot and all-slot views, including views reached through scope toggles, use this path. Preserve the viewport across the complete update and test below-fold selection through probe completion in both scopes. ARCH-PURPOSE: opening focus must remain usable when the automatically started refresh lands.
```

1. **Strengths**
   - `attention_rows.lua:89` chooses by answer time during the existing row pass, preserving forest order and stable ties.
   - Pure tests cover legacy timestamps, nested children, empty lists, waiting-only and seen-only lists.
   - The native picker test verifies below-fold visibility, scope changes, and typed-filter retention.
   - Atlas documentation describes the new behavior; no new command, binding, or configuration surface requires a README update.

2. **Critical findings**
   - **Background repaint loses visibility**, as detailed above. Preserve the viewport before refiltering and restore it with the resolved selected identity.

3. **Important findings**
   - None.

4. **Minor findings**
   - None.

5. **Test coverage notes**
   - `make test-spec SPEC=ui/attention_finder` passed; whitespace checks passed.
   - The added probe-before-filter reproduction produced **32 passing cases and one failure** at `visible()`.
   - The shipped test completes its probe only after filtering to one row, masking this viewport failure.
   - Disposable test files were removed; the checkout remains clean.

6. **Architectural notes**
   - **ARCH-DRY: pass** — reuses row generation and picker selection machinery.
   - **ARCH-PURE: pass** — selection policy remains in the pure row builder; integration stays in the picker/glue.
   - **ARCH-PURPOSE: flag** — automatic refresh undermines the issue’s visible-focus behavior.

7. **Plan revision recommendations**
   - Add a `## Revisions` entry requiring viewport and selected-identity preservation through background probe completion before typing, in both scopes. Reopen the corresponding test checklist item until that regression passes.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"d992a290-aad6-4ed5-956c-575ce8691190","repository":"github.com/xianxu/parley.nvim","issue_id":"000392","recipe":"small-diff-review","round":1,"attempt":1,"agent":"codex","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/47c2a01792fb2823","reviewed_head":"9c8302396111b0e2904588ef2f172cf729b6929f","slot":"parley.nvim:2","requested_at":"2026-10-19T04:46:46.014017Z"},"phase":"finished","pid":59869,"started_at":"2026-10-19T04:46:46.285873Z","finished_at":"2026-10-19T04:48:36.602729Z","session_id":"01a1527b-cac9-7820-8b7a-76b211de471d","outcome":"returned"}] -->
