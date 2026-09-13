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
