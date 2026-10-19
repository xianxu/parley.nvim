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

---

## Re-review — 2026-10-19T02:18:45-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 392 — attention finder opens on the oldest unread entry |
| repo | parley.nvim |
| issue file | workshop/issues/000392-attention-finder-opens-on-the-oldest-unread-entry.md |
| boundary | whole-issue close |
| milestone | — |
| window | 1d4abae2f61a377d6dfbc17357c8f0250f0cce79..2302826c8848bb0eac245f1009d759112adb9d5d |
| command | sdlc close --issue 392 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-19T02:18:45-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The implementation selects the oldest unread entry without changing tree order and keeps it visible when background probes repaint. BR-1 is addressed with regression evidence; no new findings remain.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      float_picker.lua:1743 captures the viewport before reflow/refilter and reuses it through identity restoration. Native regressions cover successful/failed probes with below-fold targets in both scopes. Replacing the picker with its pre-fix version produces 32 passing tests and two visibility failures at attention_finder_spec.lua:145; pinned head passes all 34.
```

Done-when: current — the revision preserves the documented visible opening behavior through automatic refresh; the acceptance clauses still cover the scoped choice, no-unread fallback, and nested side-doc selection.

1. **Strengths**
   - `attention_rows.lua:85–90` computes the preference during row generation, preserving forest order and stable ties.
   - `attention.lua:285–293` distinguishes explicit scope retargeting from background selection preservation.
   - `attention_finder_spec.lua:106` exercises native viewport behavior for both probe outcomes and scopes.
   - Atlas documents the behavior. No new command, binding, flag, or configuration key requires a README update.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage notes**
   - `make test-spec SPEC=ui/attention_finder` passed at pinned head, including 34 finder and 18 row cases.
   - Removing the viewport fix made both new probe regressions fail.
   - `git diff --check` passed. Test cleanup reported no surviving processes; the disposable copy was removed and the checkout remains clean.
   - The full repository suite was not rerun during this review.

6. **Architectural notes**
   - **ARCH-DRY: pass** — reuses row generation and shared picker selection machinery.
   - **ARCH-PURE: pass** — selection policy remains in the row builder with an injected clock; UI effects remain in the picker.
   - **ARCH-PURPOSE: pass** — visible focus survives automatic refresh across the enumerated scope and probe paths.
   - **ARCH-EVOLVE: pass** — no persisted format or rewrite behavior changes.

7. **Plan revision recommendations:** None. The existing revision matches the implementation and verified regression coverage.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"5b2ecc25-7a1d-4e02-b7c6-83677796b85a","repository":"github.com/xianxu/parley.nvim","issue_id":"000392","recipe":"small-diff-review","round":2,"attempt":1,"agent":"codex","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/b48656dd771f1716","reviewed_head":"2302826c8848bb0eac245f1009d759112adb9d5d","slot":"parley.nvim:2","requested_at":"2026-10-19T09:16:37.015591Z"},"phase":"finished","pid":89025,"started_at":"2026-10-19T09:16:37.109582Z","finished_at":"2026-10-19T09:18:41.170409Z","session_id":"01a15372-d66c-7851-bdbc-ef1eeca2d693","outcome":"returned"}] -->
