# Boundary Review — parley.nvim#231 (milestone M2)

| field | value |
|-------|-------|
| issue | 231 — Attach images to questions: paste from clipboard, send to every wire, render in preview |
| repo | parley.nvim |
| issue file | workshop/issues/000231-attach-images-to-questions-paste-from-clipboard-send-to-every-wire-render-in-preview.md |
| boundary | milestone M2 |
| milestone | M2 |
| window | f03ef6dbb7ae007360e3069f7b5a27ec1db45935..a80c447017cc47fcf8c2cf5fe9b9fd847e16e0cd |
| command | sdlc milestone-close --issue 231 --milestone M2 |
| reviewer | codex |
| timestamp | 2026-09-13T00:34:12-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

M2 connects both movers, all five deletion paths, and tree export to the shared asset helpers. Two reproduced defects block shipping: failed chat deletion can silently destroy its images, and HTML placeholder restoration can turn transcript text into an executable event-handler attribute.

1. **Strengths**

   - Both movers preflight asset-folder conflicts before moving chat files.
   - All five deletion paths use one shared door; the architectural sweep confirms that consolidation.
   - Export reports copy failures while preserving completed exports.
   - The three new HTML unit cases pass in an isolated, read-only runner.

2. **Critical findings**

   - **Asset cleanup precedes successful chat deletion** — [init.lua:3567](/Users/xianxu/workspace/parley.nvim/lua/parley/init.lua:3567), [helper.lua:94](/Users/xianxu/workspace/parley.nvim/lua/parley/helper.lua:94). The wrapper removes assets first, then calls a helper that ignores `os.remove` failure. Injecting `Permission denied` into the real helper produced: `chat exists=true, assets exist=false, notices=0`. A surviving chat silently loses its images. Return and check deletion outcomes, and remove assets only after confirmed chat removal. Cover filesystem refusal and buffer-deletion exceptions. **ARCH-ORDER, ARCH-FUNERAL.**

   - **HTML restoration reinterprets user text as placeholders** — [exporter.lua:457](/Users/xianxu/workspace/parley.nvim/lua/parley/exporter.lua:457). Each restoration pass scans previously inserted tags. This input:
     ```
     ![XIMGX2XIMGX](missing.png) ![](onerror=alert`1`//)
     ```
     inserts the second tag into the first tag’s `alt` attribute. Parsing the generated HTML yields an `onerror` attribute with value ``alert`1`//"`` on the missing image. Attribute escaping is thereby bypassed. Use collision-free placeholders and a single restoration pass that never rescans replacement output; test literal tokens and tokens inside attributes. **ARCH-SECURE.**

3. **Important findings**

   None additional.

4. **Minor findings**

   None.

5. **Test coverage notes**

   Both required range inspections succeeded, HEAD matches the pinned commit, and `git diff --check` passed. The three appended HTML tests passed, but miss placeholder collisions. The deletion tests exercise asset-removal failure, not chat-removal failure.

   Filesystem integration tests and live clipboard conformance were not run under read-only permissions. The deletion reproduction used the production wrapper and helper with in-memory failure injection. HTML attribute injection was verified with an HTML parser; no browser execution was performed.

6. **Architectural notes**

   - **ARCH-DRY — pass:** shared asset helpers and deletion door replace scattered behavior.
   - **ARCH-PURE — pass:** changed HTML conversion remains computational; filesystem orchestration stays in integration entities.
   - **ARCH-PURPOSE — pass:** the M2 movers, deleters, export, and documentation surfaces are delivered; defects above prevent reliable completion.
   - **ARCH-MOCK — pass:** existing filesystem seams support failure injection; live clipboard conformance uses the production recipe.
   - **ARCH-CONSTRAINTS — pass:** no new asynchronous fan-out; folder operations follow the existing tree traversal.
   - **ARCH-SECURE — flag:** placeholder restoration defeats attribute escaping.
   - **ARCH-ORDER — flag:** irreversible cleanup precedes confirmation of owner deletion.
   - **ARCH-FUNERAL — flag:** assets can be destroyed while their owning chat survives.

   M2 concept-table entities exist at their stated paths. Atlas updates cover the new behavior. README already documents attachments in the base revision; this range adds no new command, keybinding, or configuration key requiring another entry.

7. **Plan revision recommendations**

   Append `## Revisions` entries replacing the assets-first deletion contract with checked owner deletion followed by cleanup, and strengthening HTML restoration to require collision-free, non-recursive substitution. Add corresponding regression-test requirements.

```findings
findings:
  - id: new
    severity: Critical
    family: deletion-commit-before-cleanup
    title: |
      Failed chat deletion silently destroys its assets
    detail: |
      lua/parley/init.lua:3567 removes assets before helper.lua:94 attempts chat removal and ignores its failure. Production-code failure injection left the chat present, assets absent, and no notification. ARCH-ORDER / ARCH-FUNERAL: confirm owner deletion before irreversible cleanup; sweep all deletion callers and test filesystem refusal plus buffer-deletion exceptions.
  - id: new
    severity: Critical
    family: html-placeholder-isolation
    title: |
      Recursive placeholder restoration permits HTML event-handler injection
    detail: |
      lua/parley/exporter.lua:457-464 rescans restored tags. Input ![XIMGX2XIMGX](missing.png) ![](onerror=alert`1`//) produces an onerror attribute on the first image, verified by parsing the generated HTML. ARCH-SECURE: use collision-free placeholders with non-recursive restoration and regression tests for literal tokens and tokens inside attributes.
```

---

## Re-review — 2026-09-13T00:49:01-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 231 — Attach images to questions: paste from clipboard, send to every wire, render in preview |
| repo | parley.nvim |
| issue file | workshop/issues/000231-attach-images-to-questions-paste-from-clipboard-send-to-every-wire-render-in-preview.md |
| boundary | milestone M2 |
| milestone | M2 |
| window | f03ef6dbb7ae007360e3069f7b5a27ec1db45935..dc57bbd7f5ae11a7ad6e2a0dd61edc450f985954 |
| command | sdlc milestone-close --issue 231 --milestone M2 |
| reviewer | codex |
| timestamp | 2026-09-13T00:49:01-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

BR-8 is addressed: failed chat deletion preserves assets and reports the failure. BR-9 remains open because the later branch-placeholder pass still substitutes HTML inside restored image attributes. The live clipboard test also fails to preserve non-text clipboard contents.

```findings
dispose:
  - id: BR-8
    disposition: addressed
    note: |
      helper.lua:102-114 checks buffer deletion and os.remove; init.lua:3588-3598 removes assets only after success. Regression tests cover filesystem refusal and buffer exceptions. Read-only production-function probes passed; restoring asset-first ordering failed the preservation assertion.
  - id: BR-9
    disposition: not-addressed
    note: |
      exporter.lua:284 retains forgeable branch tokens, and :807 restores them after image HTML is emitted. Rendering ![XBRANCHX1XBRANCHX](missing.png) alongside a branch substitutes its navigation div inside the image alt attribute. The original image-to-image attack is fixed, but cross-family restoration still violates attribute isolation. Fix html-placeholder-isolation across both families and test their full composition.
findings:
  - id: new
    severity: Important
    family: external-state-restoration
    title: |
      Live conformance overwrites clipboard contents it cannot restore
    detail: |
      tests/integration/clipboard_live_spec.lua:21-27 saves only a text representation, but :40-48 overwrites the clipboard even when that read failed. An image-only clipboard is therefore replaced permanently with test text. ARCH-SECURE / ARCH-ORDER: skip before mutation when preservation is unavailable, or snapshot and restore all supported clipboard representations; check restoration failures and test this path with a stateful fake.
```

1. **Strengths**

   - One checked deletion entry point now protects assets across the chat deletion callers (`init.lua:3588`).
   - Both movers reuse the existing asset conflict check before moving transcripts.
   - Export copy failures are reported while preserving successful exports.
   - Atlas and traceability updates cover M2. README already documents the attachment binding and configuration from M1.

2. **Critical findings**

   **BR-9 remains open** at `exporter.lua:272-284,807`. The production conversion pipeline produced:

   ```html
   <img src="missing.png" alt="<div class="branch-nav child-link">…
   ```

   This reproduces malformed attributes, not a newly demonstrated executable event handler. Use collision-free tokens across the complete pipeline and ensure no restoration pass scans another pass’s emitted HTML. Cover both token families in `alt`, `src`, topics and ordinary text, including unmatched literal tokens.

3. **Important findings**

   The opt-in clipboard test destroys non-text clipboard contents. The preservation check must precede its first write; opting into conformance does not satisfy the plan’s restoration promise.

4. **Minor findings**

   None.

5. **Test coverage notes**

   - Ran nine added exporter cases through a read-only in-memory harness: nine passed.
   - Restoring recursive image substitution in ascending token order made the original attack’s attribute-residue assertion fail.
   - Production deletion-function probes passed for filesystem refusal, buffer exception and success; asset-first mutation failed preservation.
   - The cross-family reproduction fails despite the existing regression cases passing.
   - `git diff --check` passed. Full filesystem integration tests and live clipboard conformance were not run under read-only permissions.

6. **Architectural notes**

   - **ARCH-DRY — pass:** shared asset operations and deletion entry point.
   - **ARCH-PURE — pass:** image conversion remains a value transformation; filesystem operations use the asset adapter.
   - **ARCH-PURPOSE — flag:** BR-9 fixes image-family recursion but leaves cross-family substitution.
   - **ARCH-MOCK — pass:** production clipboard capture retains its fake-compatible seam.
   - **ARCH-CONSTRAINTS — pass:** no additional concurrency introduced; existing asset limits remain.
   - **ARCH-SECURE — flag:** restored HTML crosses attribute boundaries; clipboard preservation is incomplete.
   - **ARCH-ORDER — flag:** deletion ordering is corrected, but live-test mutation precedes assured restoration.
   - **ARCH-FUNERAL — pass:** successful chat deletion owns asset cleanup; cleanup failures are visible.

7. **Plan revision recommendations**

   Append a timestamped `## Revisions` entry requiring placeholder isolation across the **whole pipeline**, with the cross-family test matrix. Clarify Task 12’s preservation precondition and behavior when clipboard snapshot or restoration fails.
