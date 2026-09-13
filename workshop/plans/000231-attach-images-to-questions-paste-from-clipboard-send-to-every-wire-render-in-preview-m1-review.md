# Boundary Review — parley.nvim#231 (milestone M1)

| field | value |
|-------|-------|
| issue | 231 — Attach images to questions: paste from clipboard, send to every wire, render in preview |
| repo | parley.nvim |
| issue file | workshop/issues/000231-attach-images-to-questions-paste-from-clipboard-send-to-every-wire-render-in-preview.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | 80fb39110267a500b8645d71196ac39955815757..946752a8392befd4e606c159ce7cd2c9cd2115d4 |
| command | sdlc milestone-close --issue 231 --milestone M1 |
| reviewer | codex |
| timestamp | 2026-09-12T23:24:30-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

M1 has a coherent capture/send structure, but verified edge cases break the request budget, shared retention contract, clipboard cleanup, and invalid-file handling. The Core concepts table also misclassifies IO-dependent functions as PURE. `make lint` passed; read-only probes reproduced the runtime findings.

1. **Strengths**

   - Attachment parsing shares one closed grammar between the parser and continuation builder.
   - Wire tests inspect actual prepared payloads, including Gemini same-role merging and text-only compatibility.
   - Clipboard recipes pass output paths as arguments; held callbacks provide a useful ordering seam.
   - Image elision covers the newly identified dispatcher logging sites as well as response logging.

2. **Critical findings**

   - **C1 — Budget decisions lose attachment occurrence identity.** [assets.lua:301](/Users/xianxu/workspace/parley.nvim/lua/parley/assets.lua:301) stores inclusion by path, while `question_content` emits every occurrence. A probe with 21 references to one three-byte image emitted **21 images despite the 20-image cap**. The final guard checks bytes only. Budget individual occurrences, or explicitly deduplicate emission; test repeats within and across questions. **ARCH-CONSTRAINTS**

   - **C2 — Continuation uses different retention inputs.** [chat_respond.lua:585](/Users/xianxu/workspace/parley.nvim/lua/parley/chat_respond.lua:585) substitutes `target_idx` for total exchanges and hardcodes file-reference pinning to false. Both discrepancies reproduced: answering exchange 3 of 4 resurrected an image omitted initially; an old file-reference-pinned image disappeared on continuation. Pass the same total and pinning metadata through both builders, with differential tests for both cases. **ARCH-DRY, ARCH-PURPOSE**

   - **C3 — Paste failures leave inconsistent state or orphan assets.** [clipboard_image.lua:203](/Users/xianxu/workspace/parley.nvim/lua/parley/clipboard_image.lua:203) lets synchronous spawn errors escape after the paste marks itself in flight. A missing executable raised without notifying; retry then reported “already in progress.” Separately, [paste_image.lua:82](/Users/xianxu/workspace/parley.nvim/lua/parley/paste_image.lua:82) saves before confirming insertion can succeed: making the buffer nonmodifiable during capture produced one saved asset and no link. Normalize spawn failures through completion, validate insertion prerequisites, and remove the saved asset if insertion fails. Cover each terminal failure and retry. **ARCH-ORDER, ARCH-FUNERAL**

   - **C4 — Failed or invalid reads become image payloads.** [assets.lua:501](/Users/xianxu/workspace/parley.nvim/lua/parley/assets.lua:501) discards the read error and substitutes `""`; reading a directory reproduced `bytes=""`, `err=nil`. Content construction also encoded plain text as `image/png`, contradicting the plan’s promise that non-image persisted files become notes. Preserve read errors, reject nonregular files, and validate image bytes before constructing blocks. Test empty, non-image, truncated, and failed-read inputs. **ARCH-SECURE**

   - **C5 — Core concepts incorrectly classify IO as PURE.** [plan:299](/Users/xianxu/workspace/parley.nvim/workshop/plans/000231-chat-image-attachments-plan.md:299) places `move_conflict`, `removal_note`, `host_env`, `question_content`, and both builders under “all pure; unit-tested without IO.” These query filesystem/host/buffer state or invoke readers; builder tests create real files. Promote the orchestration functions to INTEGRATION, or extract transformations accepting already-read values, and expose injected IO dependencies explicitly. **ARCH-PURE**

3. **Important findings**

   - **I1 — README update is missing.** [config.lua:412](/Users/xianxu/workspace/parley.nvim/lua/parley/config.lua:412) introduces `<M-v>`, and the range also introduces `assets.clipboard_cmd`, without a README change. Task 11 defers documentation to M2, but this boundary’s explicit docs gate requires documentation when the surface appears. Add the keybinding, override, and clipboard-tool requirements now.

4. **Minor findings**

   None.

5. **Test coverage notes**

   `make lint`: **0 warnings / 0 errors across 381 files**. `git diff --check` passed. Read-only Neovim probes reproduced C1–C4 using in-memory buffers and injected dependencies where necessary. Existing coverage misses those cases. The full suite was not rerun because its harness requires writable scratch directories, unavailable in this review. No prior findings required disposition.

6. **Architectural notes for upcoming work**

   | Principle | Result |
   |---|---|
   | ARCH-DRY | **Flag:** shared retention predicate receives divergent inputs, C2. |
   | ARCH-PURE | **Flag:** Core concepts contradict actual IO, C5. |
   | ARCH-PURPOSE | **Flag:** both builders do not deliver the promised shared retention behavior, C2. |
   | ARCH-MOCK | **Pass for M1 structure:** injected filesystem fake and clipboard fixture use production seams; extend failure coverage. Automated live conformance remains M2 work. |
   | ARCH-CONSTRAINTS | **Flag:** repeated paths bypass image-count accounting, C1. |
   | ARCH-SECURE | **Flag:** invalid persisted content is treated as image data, C4. |
   | ARCH-ORDER | **Flag:** launch and insertion failures lack complete terminal transitions, C3. |
   | ARCH-FUNERAL | **Flag:** failed insertion leaves unreferenced saved bytes, C3. Keep the planned M2 deletion integration explicit. |

7. **Plan revision recommendations**

   Append timestamped `## Revisions` entries covering occurrence-based budgeting, identical retention inputs, paste launch/insertion failure transitions and rollback, and persisted-image validation. Correct the PURE/INTEGRATION table, distinguish pending M2 entity changes from delivered M1 changes, and move README surface documentation into M1.

```findings
findings:
  - id: new
    severity: Critical
    family: budget-emission-identity
    title: |
      Path-keyed inclusion bypasses per-request image limits.
    detail: |
      lua/parley/assets.lua:301 budgets occurrences but authorizes emission by path; 21 references to one image emitted 21 blocks under the 20-image cap. Preserve occurrence identity through planning and emission, and test duplicate references within and across questions. ARCH-CONSTRAINTS.
  - id: new
    severity: Critical
    family: retention-consumer-parity
    title: |
      Initial and continuation builders apply different retention inputs.
    detail: |
      lua/parley/chat_respond.lua:585 uses target_idx as the total and disables file-reference pinning. Probes reproduced both resurrection of an initially omitted image and loss of a pinned image; pass identical retention metadata and add differential tests. ARCH-DRY, ARCH-PURPOSE.
  - id: new
    severity: Critical
    family: async-operation-terminal-cleanup
    title: |
      Clipboard launch and insertion failures leave incomplete paste transactions.
    detail: |
      lua/parley/clipboard_image.lua:203 lets spawn errors escape, leaving paste inflight permanently; lua/parley/paste_image.lua:82 saves before insertion and leaves an orphan when insertion fails. Route launch errors through completion and roll back saved bytes after insertion failure, with retry and residue assertions. ARCH-ORDER, ARCH-FUNERAL.
  - id: new
    severity: Critical
    family: persisted-input-validation
    title: |
      Read errors and invalid image bytes are submitted as image content.
    detail: |
      lua/parley/assets.lua:501 discards read errors and returns empty bytes; question_content also accepts plain text as PNG. Preserve IO errors, reject nonregular and invalid image inputs with visible notes, and cover these cases against the real read adapter. ARCH-SECURE.
  - id: new
    severity: Critical
    family: core-concept-classification
    title: |
      The Core concepts table labels IO-dependent functions PURE.
    detail: |
      workshop/plans/000231-chat-image-attachments-plan.md:299 onward includes filesystem probes, host_env, reader-driven question_content, and buffer/filesystem-dependent builders under the no-IO contract. Reclassify integration functions or extract pure transformations, expose injected dependencies, and append a plan revision. ARCH-PURE.
  - id: new
    severity: Important
    family: user-surface-documentation
    title: |
      README documentation is missing for the new paste surface.
    detail: |
      lua/parley/config.lua:412 introduces the M-v binding, and this range introduces assets.clipboard_cmd without updating README.md. Document the binding, override, and tool requirements at M1 instead of deferring them to M2.
```

---

## Re-review — 2026-09-12T23:43:19-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 231 — Attach images to questions: paste from clipboard, send to every wire, render in preview |
| repo | parley.nvim |
| issue file | workshop/issues/000231-attach-images-to-questions-paste-from-clipboard-send-to-every-wire-render-in-preview.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | 80fb39110267a500b8645d71196ac39955815757..f234b4f56ce72d78cc48c1f336962eba3085fa50 |
| command | sdlc milestone-close --issue 231 --milestone M1 |
| reviewer | codex |
| timestamp | 2026-09-12T23:43:19-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The occurrence-budget, retention, clipboard-launch, insertion-rollback, and README fixes are present with relevant regression coverage. BR-4 remains incomplete because signature-only image validation accepts truncated files. BR-5 remains incomplete because the PURE classification still includes functions that invoke filesystem or executable probes.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Both builders assign occurrence IDs through attach_question_images. Duplicate-reference tests cover within/across questions; an in-memory path-keyed planner mutation caused 12 failures.
  - id: BR-2
    disposition: addressed
    note: |
      Continuation now uses the full exchange count and shared file-reference extraction. Differential regressions at tests/unit/build_messages_spec.lua:2139 and :2169 exercise both reported failures.
  - id: BR-3
    disposition: addressed
    note: |
      Launch exceptions reach scheduled completion exactly once; insertion failures roll back saved assets. Tests cover launch errors, retries, removal of newly created folders, and preservation of existing assets.
  - id: BR-4
    disposition: not-addressed
    note: |
      lua/parley/assets.lua:171 accepts signatures without valid image bodies. A read-only probe submitted the eight-byte PNG signature through question_content and obtained an image block. Tests explicitly accept signature-plus-"body" fixtures, so they cannot catch this remaining invalid-input case.
  - id: BR-5
    disposition: not-addressed
    note: |
      workshop/plans/000231-chat-image-attachments-plan.md:290 still labels unique_name PURE despite its filesystem-backed exists callback; :302 likewise labels select PURE despite env.executable calling vim.fn.executable. The named reclassifications landed, but the classification rule was not swept across the table.
  - id: BR-6
    disposition: addressed
    note: |
      README.md now documents M-v, platform tools, assets.clipboard_cmd, its output-token contract, and setup table replacement.
```

1. **Strengths**

   - Both builders share occurrence assignment and request budgeting in `lua/parley/chat_respond.lua:483`.
   - Retention regressions exercise the original reported scenarios, including answering an earlier exchange and preserving file-reference pinning.
   - Clipboard completion handles synchronous launch exceptions and duplicate settlement; rollback tests assert filesystem residue and subsequent retry behavior.
   - Atlas and README updates accompany the new surface.

2. **Critical findings**

   - **BR-4 — invalid image bodies still pass.** `lua/parley/assets.lua:171` checks only magic bytes. The eight-byte PNG signature alone passes and becomes outbound image content. `tests/unit/assets_spec.lua:636` actually asserts acceptance of fabricated bodies. **ARCH-SECURE:** validate sufficient image structure to reject truncated/corrupt inputs across all accepted formats; use valid fixtures plus truncation/corruption variants, including real-adapter coverage. Preserve visible rejection notes.

   - **BR-5 — PURE classification remains inconsistent.** `assets.unique_name` invokes `exists` at `lua/parley/assets.lua:146`; production supplies filesystem IO. `clipboard_image.select` invokes the executable probe at `lua/parley/clipboard_image.lua:137`. Both remain in the PURE table. **ARCH-PURE:** apply one rule across every row—either classify effectful callback consumers as integration points or supply already-collected data to pure transformations.

3. **Important findings**

   None newly raised.

4. **Minor findings**

   None newly raised.

5. **Test coverage notes**

   Executed 69 asset tests using pure logic or in-memory IO: **69 passed**. An in-memory mutation restoring path-keyed planner output produced **12 failures**, including duplicate-reference regressions. The signature-only PNG probe confirmed BR-4.

   Full integration tests and real-filesystem tests were not rerun under the read-only sandbox. Their assertions were inspected; prior execution claims were not treated as independently verified.

6. **Architectural notes for upcoming work**

   - **ARCH-DRY — pass:** shared budget, occurrence assignment, retention predicate, and reference grammar.
   - **ARCH-PURE — flag:** BR-5.
   - **ARCH-PURPOSE — pass for M1 scope:** capture and wire delivery implemented; lifecycle integration remains explicitly M2.
   - **ARCH-MOCK — pass for M1:** stateful clipboard fixture shares the configured production seam; automated live conformance remains M2.
   - **ARCH-CONSTRAINTS — pass:** occurrence counting, bounded reads, timeout, and final payload-size refusal.
   - **ARCH-SECURE — flag:** BR-4.
   - **ARCH-ORDER — pass:** held-runner coverage and explicit terminal completion handling.
   - **ARCH-FUNERAL — pass for M1 staging:** temporary-file and insertion-failure cleanup exist; verify every mover/deleter at M2 before issue close.

7. **Plan revision recommendations**

   Append timestamped `## Revisions` entries defining the image-validity contract and correcting the complete PURE/INTEGRATION classification sweep. Mark M2-only Core concepts rows as planned rather than already modified.

---

## Re-review — 2026-09-12T23:52:43-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 231 — Attach images to questions: paste from clipboard, send to every wire, render in preview |
| repo | parley.nvim |
| issue file | workshop/issues/000231-attach-images-to-questions-paste-from-clipboard-send-to-every-wire-render-in-preview.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | 80fb39110267a500b8645d71196ac39955815757..b5ae70bacc466225516d0ab6f1c46b54ed37b560 |
| command | sdlc milestone-close --issue 231 --milestone M1 |
| reviewer | codex |
| timestamp | 2026-09-12T23:52:43-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

M1’s shared budget, wire translations, and read-error handling are sound improvements. BR-5’s classification changes are addressed. BR-4 remains reproducible across all four formats: containers without image data become outbound image blocks. Request-cache retention also needs attention now that each persisted request can contain megabytes of image data.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Existing disposition retained; occurrence-keyed budgeting remains shared by both builders.
  - id: BR-2
    disposition: addressed
    note: |
      Existing disposition retained; continuation uses total exchanges and extracted file references.
  - id: BR-3
    disposition: addressed
    note: |
      Existing disposition retained; launch failure and insertion rollback paths remain present.
  - id: BR-4
    disposition: not-addressed
    note: |
      lua/parley/assets.lua:185–213 still accepts image-less containers in all four formats, and question_content emits them. Error propagation is repaired, but structural image validation remains incomplete.
  - id: BR-5
    disposition: addressed
    note: |
      Core-concepts tables now classify the named effectful callback consumers as integration points and record the classification rule and revision.
  - id: BR-6
    disposition: addressed
    note: |
      Existing disposition retained; README documents the paste binding, dependencies, and clipboard override.
findings:
  - id: new
    severity: Important
    family: request-artifact-retention
    title: |
      Full image payloads accumulate in the persistent request cache.
    detail: |
      lua/parley/dispatcher.lua:652–654 writes complete image-bearing payloads into query_dir without terminal cleanup. The setup-only count sweep at lines 69–78 leaves long-running sessions unbounded; 100 near-limit requests retain roughly 2 GiB. Delete transport files after subprocess completion on every terminal path, or enforce a writer-side retention budget, with lifecycle documentation and regression coverage. ARCH-FUNERAL.
```

1. **Strengths**

   - Both builders share attachment budgeting and occurrence identity.
   - OpenAI and GoogleAI transformations preserve image parts and existing text-only shapes.
   - Real-adapter probes confirmed directory rejection and preservation of an injected read error.
   - README and atlas updates cover the new M1 surface.

2. **Critical findings**

   **BR-4 — incomplete validation**, [assets.lua:185](/Users/xianxu/workspace/parley.nvim/lua/parley/assets.lua:185), **ARCH-SECURE / ARCH-PURPOSE**.

   Executed probes returned `looks_like=true` and emitted an image block for each:

   - PNG containing IHDR and IEND but no IDAT.
   - Four-byte JPEG `FF D8 FF D9`, with no frame or scan.
   - GIF containing only its header, screen descriptor, and trailer.
   - WebP containing a RIFF header and chunk name, without chunk length or data.

   This remains BR-4 in `persisted-input-validation`, not a new finding. Apply one rule across all four formats: require complete structural image records, including image-bearing data and valid record boundaries. Pixel decoding and CRC verification need not be added. Pin these cases through `read_bounded` and outbound content construction.

3. **Important findings**

   **Request-cache retention**, [dispatcher.lua:652](/Users/xianxu/workspace/parley.nvim/lua/parley/dispatcher.lua:652): described in the machine-readable finding above. Eliding logger output does not limit these full-payload files.

4. **Minor findings**

   None.

5. **Test coverage notes**

   - Executed 71 existing asset cases through a read-only harness, excluding the filesystem-writing `default_io` group: **71 passed**.
   - Replacing validation in memory with signature-only checks made **three existing tests fail**. The fix has meaningful regression coverage, but its oracle misses the four cases above.
   - Real-reader probes accepted all four fixtures and confirmed directory/read-error handling.
   - `git diff --check` passed. Full integration suites were not rerun under the read-only sandbox.

6. **Architectural notes**

   - **ARCH-DRY — pass:** shared grammar, retention, budget, and wire recognition.
   - **ARCH-PURE — pass:** named callback consumers are reclassified as integration points.
   - **ARCH-PURPOSE — flag:** BR-4’s invalid-input class remains incompletely addressed.
   - **ARCH-MOCK — pass:** injected IO and clipboard fake exist; live conformance is explicitly scheduled for M2.
   - **ARCH-CONSTRAINTS — pass:** bounded reads, request planning, and final payload refusal are present.
   - **ARCH-SECURE — flag:** incomplete image containers cross the outbound boundary.
   - **ARCH-ORDER — pass:** held completion tests and paste rollback cover relevant ordering.
   - **ARCH-FUNERAL — flag:** expanded request-cache residue lacks a writer-side bound.

7. **Plan revision recommendations**

   Append dated `## Revisions` entries that:

   - Strengthen the image-validation contract to require complete image-bearing structures across all four formats.
   - Enumerate request-cache files alongside assets and logs, naming their cleanup owner, terminal paths, retention bound, and test strategy.

---

## Re-review — 2026-09-13T00:02:21-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 231 — Attach images to questions: paste from clipboard, send to every wire, render in preview |
| repo | parley.nvim |
| issue file | workshop/issues/000231-attach-images-to-questions-paste-from-clipboard-send-to-every-wire-render-in-preview.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | 80fb39110267a500b8645d71196ac39955815757..255e34fd3981f11ddf7b71a40a64d2eeabbbb58d |
| command | sdlc milestone-close --issue 231 --milestone M1 |
| reviewer | codex |
| timestamp | 2026-09-13T00:02:21-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

M1 delivers the attachment flow, shared budgeting, wire conversion, and request-file cleanup. BR-4 still blocks this boundary: executed probes confirm that containers without usable image data pass validation and become outbound image blocks. BR-7 is addressed by reachable cleanup and targeted regression tests; those integration tests were inspected but not rerun under the read-only sandbox.

```findings
dispose:
  - id: BR-4
    disposition: not-addressed
    note: |
      Read-error handling improved, but invalid image bytes still pass: an empty PNG IDAT, JPEG with empty SOF/SOS headers, and GIF with empty image sub-blocks all return true from looks_like. The PNG becomes an outbound image block. Sweep all four validators under persisted-input-validation; require structurally meaningful headers and image data, with rejecting regressions through read_bounded and question_content.
  - id: BR-7
    disposition: addressed
    note: |
      dispatcher.lua invokes discard_transport before the terminal query-registry guard and on start failure. query_cache_spec.lua asserts removal after success, provider error, cancellation, and spawn failure; removing cleanup leaves files that violate those assertions. Integration execution and mutation verification were unavailable under read-only permissions.
  - id: BR-1
    disposition: addressed
    note: |
      Occurrence identifiers govern budgeting and emission; duplicate-path regression coverage remains.
  - id: BR-2
    disposition: addressed
    note: |
      Continuations use the full exchange count and shared file-reference extraction, with parity regressions.
  - id: BR-3
    disposition: addressed
    note: |
      Launch failures settle once, insertion prerequisites precede saving, and failed insertion rolls back the asset.
  - id: BR-5
    disposition: addressed
    note: |
      The Core concepts tables classify effectful callback consumers as integration points.
  - id: BR-6
    disposition: addressed
    note: |
      README documents M-v, asset storage, platform tools, and the clipboard override.
```

1. **Strengths**
   - Both builders share occurrence-based budgeting and attachment resolution.
   - Clipboard paths travel as arguments rather than interpolated shell code.
   - Transport cleanup precedes the missing-query early return in [dispatcher.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/dispatcher.lua:710).

2. **Critical findings**
   - **BR-4 — still open, ARCH-SECURE / ARCH-PURPOSE.** [assets.lua:222](/Users/xianxu/workspace/parley.nvim/lua/parley/assets.lua:222) treats zero-length IDAT as image data; [assets.lua:271](/Users/xianxu/workspace/parley.nvim/lua/parley/assets.lua:271) accepts empty JPEG frame/scan headers; [assets.lua:339](/Users/xianxu/workspace/parley.nvim/lua/parley/assets.lua:339) accepts GIF image sub-blocks containing only their terminator.
     
     Executed results: all three returned `true`; the empty-IDAT PNG produced `outbound block image`. This remains the existing `persisted-input-validation` finding. Fix the rule across all four formats: record names alone cannot establish image content. Validate mandatory header structure and actual data presence, without requiring pixel decoding or CRC verification.

3. **Important findings**
   - None newly raised.

4. **Minor findings**
   - None.

5. **Test coverage notes**
   - Required stat/name-status inspections and `git diff --check` succeeded.
   - Read-only Neovim probes reproduced BR-4.
   - Existing malformed-container tests cover absent records and overruns, but miss empty image records and mandatory header contents.
   - Full integration tests and scratch-copy mutation tests were not run because they require filesystem writes. No full-suite pass is claimed.

6. **Architectural notes**
   - **ARCH-DRY: pass** — shared grammar, retention, budget, and image recognition.
   - **ARCH-PURE: pass** — validation transforms bytes; IO consumers are classified separately.
   - **ARCH-PURPOSE: flag** — BR-4’s invalid-input class remains incompletely handled.
   - **ARCH-MOCK: pass for M1** — clipboard fake uses the production seam; live conformance remains explicitly scheduled for M2.
   - **ARCH-CONSTRAINTS: pass** — bounded reads, request limits, clipboard timeout, and per-buffer admission.
   - **ARCH-SECURE: flag** — malformed image structures become trusted outbound content.
   - **ARCH-ORDER: pass** — scheduled once-only settlement and explicit terminal cleanup.
   - **ARCH-FUNERAL: pass for M1** — transport cleanup is implemented; asset move/delete integration belongs to M2.

7. **Plan revision recommendations**
   - Append a `## Revisions` entry recording BR-4’s remaining class: empty image records and malformed mandatory headers. Specify a four-format regression matrix covering these cases through validation, bounded reads, and content emission.

---

## Re-review — 2026-09-13T00:14:26-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 231 — Attach images to questions: paste from clipboard, send to every wire, render in preview |
| repo | parley.nvim |
| issue file | workshop/issues/000231-attach-images-to-questions-paste-from-clipboard-send-to-every-wire-render-in-preview.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | 80fb39110267a500b8645d71196ac39955815757..c88da86cbfe9046d0a27a12c4879dfb3debba5fb |
| command | sdlc milestone-close --issue 231 --milestone M1 |
| reviewer | codex |
| timestamp | 2026-09-13T00:14:26-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

BR-4 remains open: header-only WebP files still become outbound image blocks. The read-error handling, shared budgeting, wire translations, and paste cleanup are substantially improved; the remaining validation gap blocks this boundary.

```findings
dispose:
  - id: BR-4
    disposition: not-addressed
    note: |
      assets.lua:468 and :474 accept exactly 5-byte VP8L and 10-byte VP8 headers without any image data. Executed probes returned looks_like=true and question_content emitted type=image for both. Existing tests reject shorter headers but omit these exact-length cases. ARCH-SECURE; existing persisted-input-validation family.
  - id: BR-1
    disposition: addressed
    note: |
      Prior disposition retained: occurrence-keyed budgeting and repeated-path regression coverage are present.
  - id: BR-2
    disposition: addressed
    note: |
      Prior disposition retained: continuation uses total exchange count and the shared file-reference parser.
  - id: BR-3
    disposition: addressed
    note: |
      Prior disposition retained: launch settlement, insertion rollback, and retry regression coverage are present.
  - id: BR-5
    disposition: addressed
    note: |
      Prior disposition retained: effectful callbacks are classified as integration points in the Core concepts tables.
  - id: BR-6
    disposition: addressed
    note: |
      Prior disposition retained: README documents the keybinding, clipboard tools, and configuration override.
  - id: BR-7
    disposition: addressed
    note: |
      Prior disposition retained: image transport cleanup covers completion and spawn failure, with cancellation and error regression coverage.
```

1. **Strengths**

   - Both message builders share occurrence-based budgeting and retention inputs.
   - Clipboard completion is scheduled and settled once; insertion failures roll back saved assets.
   - Executed real-reader checks accepted all four committed image fixtures and rejected a directory with a visible error.
   - README and atlas changes document the new attachment surface.

2. **Critical findings**

   **BR-4 — Header-only WebP content passes validation.** At [assets.lua:468](/Users/xianxu/workspace/parley.nvim/lua/parley/assets.lua:468) and [assets.lua:474](/Users/xianxu/workspace/parley.nvim/lua/parley/assets.lua:474), the length checks permit the header to consume the entire bitstream chunk. Correctly sized RIFF containers containing either of these payloads passed both validation and image-block construction:

   - `VP8L`: `2f 00 00 00 00` — five header bytes, no image data.
   - `VP8 `: `10 00 00 9d 01 2a 01 00 01 00` — ten header bytes, no image data.

   **ARCH-SECURE:** enforce the existing family rule: mandatory headers do not count as image data. Sweep every image-bearing format branch for this distinction, including WebP inside an extended container. Add rejection tests through `looks_like`, the real `read_bounded` adapter, and `question_content`. Those tests must fail on this HEAD.

3. **Important findings**

   None newly raised.

4. **Minor findings**

   None.

5. **Test coverage notes**

   [assets_spec.lua:1017](/Users/xianxu/workspace/parley.nvim/tests/unit/assets_spec.lua:1017) and [assets_spec.lua:1022](/Users/xianxu/workspace/parley.nvim/tests/unit/assets_spec.lua:1022) cover headers one byte too short, but omit headers of exactly the required length with zero remaining data.

   Read-only Neovim probes reproduced both failures. Full suites and filesystem-based mutation checks were not run because this environment prohibits writes. Existing test coverage was inspected; implementor-reported green runs were not treated as independent verification.

6. **Architectural notes for upcoming work**

   - **ARCH-DRY — pass:** shared attachment grammar, budgeting, retention, and image-payload recognition.
   - **ARCH-PURE — pass:** deterministic policies separated from identified integration points.
   - **ARCH-PURPOSE — flag:** BR-4’s promised invalid-input rejection remains incomplete.
   - **ARCH-MOCK — pass for M1:** clipboard fake uses the production configuration seam; automated live conformance remains scheduled for M2.
   - **ARCH-CONSTRAINTS — pass:** bounded reads, occurrence limits, final serialized-payload guard, and clipboard timeout.
   - **ARCH-SECURE — flag:** header-only WebP is trusted as image content.
   - **ARCH-ORDER — pass:** held completion seams exercise ordering; settlement and rollback paths are explicit.
   - **ARCH-FUNERAL — pass for M1 scope:** temporary request cleanup exists; chat-owned asset lifecycle integration remains an explicit M2 obligation.

7. **Plan revision recommendations**

   Append a `## Revisions` entry recording that round four’s non-emptiness check missed header-only WebP. State the header-versus-image-data invariant explicitly and extend the regression matrix to exact header lengths, including extended WebP containers.

---

## Re-review — 2026-09-13T00:19:49-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 231 — Attach images to questions: paste from clipboard, send to every wire, render in preview |
| repo | parley.nvim |
| issue file | workshop/issues/000231-attach-images-to-questions-paste-from-clipboard-send-to-every-wire-render-in-preview.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | 80fb39110267a500b8645d71196ac39955815757..741af97e4adeceaf6c466e113f3d46e63bf55376 |
| command | sdlc milestone-close --issue 231 --milestone M1 |
| reviewer | codex |
| timestamp | 2026-09-13T00:19:49-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: medium
```

The pinned M1 implementation matches its capture-and-send scope. BR-4 is addressed: bounded reads reject nonregular files, preserve errors, and validate image structure before emission. The latest WebP regression tests fail when the fix is removed in memory. No new blocking findings.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Shared builder assigns budget identity per attachment occurrence.
  - id: BR-2
    disposition: addressed
    note: |
      Both builders share retention inputs, including total exchanges and file references.
  - id: BR-3
    disposition: addressed
    note: |
      Launch failures settle the operation; insertion failures roll back saved assets.
  - id: BR-4
    disposition: addressed
    note: |
      Real-adapter probes passed; removing WebP minimum-length fixes in memory caused validator and outbound-content regression tests to fail.
  - id: BR-5
    disposition: addressed
    note: |
      Core-concept tables classify effectful callback consumers as integration points.
  - id: BR-6
    disposition: addressed
    note: |
      README documents the paste binding, override, and clipboard requirements.
  - id: BR-7
    disposition: addressed
    note: |
      Dispatcher removes image-bearing transport files on terminal paths.
```

1. **Strengths**

   - Shared attachment preparation keeps occurrence budgets and retention consistent across both builders.
   - Validation rejects malformed inputs before they become image blocks; rejection notes retain the reason.
   - Paste tests expose completion ordering and rollback through injected seams.
   - README and atlas cover the new M1 surface.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage notes**

   - Ran 12 read-only validator/content tests: **12 passed**.
   - Reverted both WebP length checks in memory: **two tests failed**, including outbound-content rejection at `tests/unit/assets_spec.lua:1098`.
   - Real-adapter probes passed for four fixtures, directory/missing/text rejection, and read-error preservation.
   - Independent OpenAI translation probe passed.
   - Scratch-writing integration tests and the full suite were inspected, not rerun under the read-only sandbox.

6. **Architectural notes**

   - **ARCH-DRY — pass:** shared budgets, retention, and payload recognition.
   - **ARCH-PURE — pass:** deterministic validators; effectful consumers classified separately.
   - **ARCH-PURPOSE — pass:** M1 capture/send delivered; lifecycle wiring remains explicitly M2.
   - **ARCH-MOCK — pass:** stateful filesystem/clipboard doubles use production seams.
   - **ARCH-CONSTRAINTS — pass:** bounded reads, request limits, and clipboard timeout.
   - **ARCH-SECURE — pass:** constrained attachment grammar and structural validation; pixel decoding and CRC checks explicitly excluded.
   - **ARCH-ORDER — pass:** held completions exercise interruption and rollback.
   - **ARCH-FUNERAL — pass:** temporary/request cleanup implemented; durable asset lifecycle assigned to M2.

7. **Plan revision recommendations:** None.
