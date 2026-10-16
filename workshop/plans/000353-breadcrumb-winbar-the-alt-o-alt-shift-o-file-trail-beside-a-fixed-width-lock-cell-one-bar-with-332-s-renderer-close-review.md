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
