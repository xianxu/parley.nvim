# Boundary Review — parley.nvim#353 (whole-issue close)

| field | value |
|-------|-------|
| issue | 353 — Breadcrumb winbar: the Alt+o / Alt+Shift+O file trail beside a fixed-width lock cell (one bar with #332's renderer) |
| repo | parley.nvim |
| issue file | workshop/issues/000353-breadcrumb-winbar-the-alt-o-alt-shift-o-file-trail-beside-a-fixed-width-lock-cell-one-bar-with-332-s-renderer.md |
| boundary | whole-issue close |
| milestone | — |
| window | 800e0d3e0ce074eb79f69c3de246822cfd893cd0..38ddd35b4e21b84e3e65a836210bf04508a7ab70 |
| command | sdlc close --issue 353 |
| reviewer | codex |
| isolation | fenced |
| timestamp | 2026-10-16T15:24:44-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The navigation model, snapshot seam, and shared composition largely match the plan. All three focused test mappings passed. Direct probes nevertheless exposed a renderer crash and two rendering-contract gaps that need regression coverage before close.

```findings
findings:
  - id: new
    severity: Critical
    kind: defect
    family: renderer-ownership-state
    title: |
      Rendering a plain root crashes and leaves a poisoned ownership record
    detail: |
      lua/parley/document_band.lua:132 retires a newly created record when compose returns no bar, but restore at line 57 dereferences its unset installed field. Calling new(current_buf).render({state="plain", hl="WinBar"}) raises "attempt to index field 'installed'"; subsequent BufWinLeave cleanup raises again. Handle never-installed records safely, or publish ownership only after installation, and add an adapter regression. ARCH-ORDER.
  - id: new
    severity: Important
    kind: defect
    family: window-option-ownership
    title: |
      Resize repaint overwrites user window-option overrides
    detail: |
      lua/parley/document_band.lua:133-141 replaces the ownership proof and writes both options unconditionally. On an ordinary README→TOOLING trail, setting custom winbar and winhighlight values and firing WinResized replaces both; later cleanup loses the custom bar. Preserve per-option overrides during refresh and test resize followed by cleanup for breadcrumb-only and state-owned views. ARCH-ORDER.
  - id: new
    severity: Important
    kind: defect
    family: protected-breadcrumb-segments
    title: |
      Width fallback drops the immediate parent before trying shortened labels
    detail: |
      lua/parley/breadcrumb_model.lua:140-145 always falls back to root, ellipsis and leaf once the compact trail is too wide. For root→extra-long-middle→verylongparent→leaf with budget 24, it emits "root › … › leaf" although "root › … › very… › leaf" fits in 23 columns. Allocate shortened labels across the protected root and final two segments before dropping the parent, as the rendering plan requires. ARCH-PURPOSE.
```

1. **Strengths**

   - `file_history_model.install_trail` centralizes ancestry reconstruction for follows and restores, keeping Back aligned with displayed history.
   - Snapshot validation returns detached values; restore distinguishes missing ancestors from uncertain filesystem errors.
   - Lock state and feedback remain separate composition inputs. Native tests cover overlays, independent window trails, and original-option restoration.
   - README, atlas, and traceability updates cover the new surface.

2. **Critical findings**

   The plain-root adapter crash above violates the composition contract. The pure model correctly returns no bar; its window adapter cannot safely consume that result.

3. **Important findings**

   Resize must preserve user-owned option values. Width fallback must attempt shortening the immediate parent before removing it.

4. **Minor findings**

   None.

5. **Test coverage notes**

   Passed:

   - `make -k test-spec SPEC=ui/keybindings`
   - `make -k test-spec SPEC=modes/session_sync`
   - `make -k test-spec SPEC=context/file_references` — 386 cases
   - Pinned-range `git diff --check`

   All harness runs reported no surviving processes. Existing tests miss the three reproduced cases: plain-root rendering through the adapter, override→resize→cleanup, and protected-segment retention through label shortening. No repository files were changed. The full suite and operator live check were not rerun.

6. **Architectural notes**

   - **ARCH-DRY — pass:** history reconstruction and rendering have shared owners.
   - **ARCH-PURE — pass:** transitions and composition are isolated from editor IO.
   - **ARCH-PURPOSE — flag:** shortening under-delivers the promised final-two-segment retention.
   - **ARCH-MOCK — pass:** changed integrations reuse existing stateful resolver/Couch seams.
   - **ARCH-CONSTRAINTS — pass:** cached paint performs no filesystem observation; history and snapshot bounds are explicit.
   - **ARCH-SECURE — pass:** restore validates inputs, distinguishes uncertainty, and display composition escapes percent expressions.
   - **ARCH-ORDER — flag:** ownership records permit a never-installed state that cleanup cannot handle; refresh also replaces ownership evidence without checking overrides.
   - **ARCH-FUNERAL — pass:** no new durable store or background process; existing window/buffer cleanup owns retained records, subject to the crash fix.

7. **Plan revision recommendations**

   Add a `## Revisions` entry defining never-installed versus installed renderer records, per-option override preservation across repaint, and shortening protected breadcrumb segments before removing them. Name the three regression sequences above explicitly.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"a06ca659-ff8e-4b07-b086-0ceeb0aa0668","repository":"github.com/xianxu/parley.nvim","issue_id":"000353","recipe":"milestone-review","round":1,"attempt":1,"agent":"codex","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/a2d870833d0ea36d","reviewed_head":"38ddd35b4e21b84e3e65a836210bf04508a7ab70","slot":"parley.nvim:2","requested_at":"2026-10-16T22:20:43.483905Z"},"phase":"finished","pid":86178,"started_at":"2026-10-16T22:20:43.628485Z","finished_at":"2026-10-16T22:24:43.347588Z","session_id":"01a146cd-a2b1-7ab2-842f-a24b3edd345b","outcome":"returned"}] -->

---

## Re-review — 2026-10-16T23:43:05-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 353 — Breadcrumb winbar: the Alt+o / Alt+Shift+O file trail beside a fixed-width lock cell (one bar with #332's renderer) |
| repo | parley.nvim |
| issue file | workshop/issues/000353-breadcrumb-winbar-the-alt-o-alt-shift-o-file-trail-beside-a-fixed-width-lock-cell-one-bar-with-332-s-renderer.md |
| boundary | whole-issue close |
| milestone | — |
| window | 800e0d3e0ce074eb79f69c3de246822cfd893cd0..f72a806cef695f5b7fcf3bfde1b682553ec812fd |
| command | sdlc close --issue 353 |
| reviewer | codex |
| isolation | fenced |
| timestamp | 2026-10-16T23:43:05-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

All three prior findings are addressed, with regression tests confirmed to fail against the pre-fix modules. Navigation, ownership restoration, and documentation are substantially complete. One remaining Unicode rendering defect should be fixed before shipping.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      document_band.lua:56 safely handles records without installed proofs. The never-installed plain-root regression passes at head and fails with the pre-fix renderer.
  - id: BR-2
    disposition: addressed
    note: |
      document_band.lua:56 preserves ownership independently for each option across refresh and cleanup. All six breadcrumb/state-owner override cases pass at head and fail with the pre-fix renderer.
  - id: BR-3
    disposition: addressed
    note: |
      breadcrumb_model.lua:123 allocates shortened protected labels before dropping ancestry. Parent, oversized-leaf and Unicode/context regressions pass at head and fail with the pre-fix model.
findings:
  - id: new
    severity: Important
    kind: defect
    family: display-unit-integrity
    title: |
      Breadcrumb shortening separates combining marks from their base characters
    detail: |
      lua/parley/document_band.lua:8-10 supplies individual codepoints as display units. With a 12-column window and trail /root → /éééé, the production renderer emits …́, attaching the leaf's accent to the ellipsis, although …é fits. Preserve base-plus-combining sequences using the semantics already implemented at float_picker.lua:537-542, preferably through a shared helper, and add a production-adapter regression asserting the exact shortened label. ARCH-PURPOSE, ARCH-DRY.
```

1. **Strengths**

   The centralized installation helper preserves independent window-option overrides. Follow navigation commits against the actual destination and rebuilds coherent Back history. Snapshot validation distinguishes missing ancestors from uncertain filesystem failures. README, atlas, and traceability updates cover the new surface.

2. **Critical findings**

   None.

3. **Important findings**

   The combining-character defect above originates at [document_band.lua:8](/Users/xianxu/Library/Caches/sdlc/review-checkouts/3f396b5b647cdb4c/lua/parley/document_band.lua:8). The existing float-picker implementation provides a concrete consolidation path.

4. **Minor findings**

   None.

5. **Test coverage notes**

   Sequential runs passed `ui/keybindings` (430 cases), `modes/session_sync` (431 cases), and `ui/breadcrumb` (6 cases). Changed-source lint and range whitespace checks passed. Counterfactual module substitution verified regression sensitivity for BR-1–BR-3.

   The generated Unicode assertions currently check width and UTF-8 validity; they do not detect detached combining marks. The full suite and operator live check were not independently rerun.

6. **Architectural notes**

   - **ARCH-DRY — flag:** consolidate display-unit handling as described above.
   - **ARCH-PURE — pass:** transition and composition models remain separate from editor/filesystem adapters.
   - **ARCH-PURPOSE — flag:** combining-character shortening remains incomplete.
   - **ARCH-MOCK — pass:** existing stateful resolver/Couch seams are retained.
   - **ARCH-CONSTRAINTS — pass:** repaint uses cached trails; bounds and width budgets have coverage.
   - **ARCH-SECURE — pass:** snapshot validation and statusline escaping protect the introduced boundaries.
   - **ARCH-ORDER — pass:** confirmed follow commits and per-option installation proofs have meaningful regression coverage.
   - **ARCH-FUNERAL — pass:** window/buffer cleanup paths exist; no new durable store or background process is introduced.

7. **Plan revision recommendations**

   Add a `## Revisions` entry documenting combining-safe display units shared with existing rendering code, plus an exact-output adapter regression at narrow widths. Retain the existing Unicode contract.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"48a5ab1c-53d6-40b8-aa6a-0bf2a0c16545","repository":"github.com/xianxu/parley.nvim","issue_id":"000353","recipe":"milestone-review","round":2,"attempt":1,"agent":"codex","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/3f396b5b647cdb4c","reviewed_head":"f72a806cef695f5b7fcf3bfde1b682553ec812fd","slot":"parley.nvim:2","requested_at":"2026-10-17T06:37:59.078843Z"},"phase":"finished","pid":30523,"started_at":"2026-10-17T06:37:59.317192Z","finished_at":"2026-10-17T06:43:04.925164Z","session_id":"01a14894-e4d5-75e2-bb62-3459d351cd31","outcome":"returned"}] -->
