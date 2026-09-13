---
gate: boundary-review
issue: 231
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-12T23:24:30-07:00"
      agent: codex
      findings:
        - id: BR-1
          severity: Critical
          title: Path-keyed inclusion bypasses per-request image limits.
          detail: lua/parley/assets.lua:301 budgets occurrences but authorizes emission by path; 21 references to one image emitted 21 blocks under the 20-image cap. Preserve occurrence identity through planning and emission, and test duplicate references within and across questions. ARCH-CONSTRAINTS.
          family: budget-emission-identity
          round: 1
        - id: BR-2
          severity: Critical
          title: Initial and continuation builders apply different retention inputs.
          detail: lua/parley/chat_respond.lua:585 uses target_idx as the total and disables file-reference pinning. Probes reproduced both resurrection of an initially omitted image and loss of a pinned image; pass identical retention metadata and add differential tests. ARCH-DRY, ARCH-PURPOSE.
          family: retention-consumer-parity
          round: 1
        - id: BR-3
          severity: Critical
          title: Clipboard launch and insertion failures leave incomplete paste transactions.
          detail: lua/parley/clipboard_image.lua:203 lets spawn errors escape, leaving paste inflight permanently; lua/parley/paste_image.lua:82 saves before insertion and leaves an orphan when insertion fails. Route launch errors through completion and roll back saved bytes after insertion failure, with retry and residue assertions. ARCH-ORDER, ARCH-FUNERAL.
          family: async-operation-terminal-cleanup
          round: 1
        - id: BR-4
          severity: Critical
          title: Read errors and invalid image bytes are submitted as image content.
          detail: lua/parley/assets.lua:501 discards read errors and returns empty bytes; question_content also accepts plain text as PNG. Preserve IO errors, reject nonregular and invalid image inputs with visible notes, and cover these cases against the real read adapter. ARCH-SECURE.
          family: persisted-input-validation
          round: 1
        - id: BR-5
          severity: Critical
          title: The Core concepts table labels IO-dependent functions PURE.
          detail: workshop/plans/000231-chat-image-attachments-plan.md:299 onward includes filesystem probes, host_env, reader-driven question_content, and buffer/filesystem-dependent builders under the no-IO contract. Reclassify integration functions or extract pure transformations, expose injected dependencies, and append a plan revision. ARCH-PURE.
          family: core-concept-classification
          round: 1
        - id: BR-6
          severity: Important
          title: README documentation is missing for the new paste surface.
          detail: lua/parley/config.lua:412 introduces the M-v binding, and this range introduces assets.clipboard_cmd without updating README.md. Document the binding, override, and tool requirements at M1 instead of deferring them to M2.
          family: user-surface-documentation
          round: 1
      boundary: M1
      blocked: true
    - "n": 2
      timestamp: "2026-09-12T23:43:19-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: addressed
          note: Both builders assign occurrence IDs through attach_question_images. Duplicate-reference tests cover within/across questions; an in-memory path-keyed planner mutation caused 12 failures.
          round: 2
        - id: BR-2
          disposition: addressed
          note: Continuation now uses the full exchange count and shared file-reference extraction. Differential regressions at tests/unit/build_messages_spec.lua:2139 and :2169 exercise both reported failures.
          round: 2
        - id: BR-3
          disposition: addressed
          note: Launch exceptions reach scheduled completion exactly once; insertion failures roll back saved assets. Tests cover launch errors, retries, removal of newly created folders, and preservation of existing assets.
          round: 2
        - id: BR-4
          disposition: not-addressed
          note: lua/parley/assets.lua:171 accepts signatures without valid image bodies. A read-only probe submitted the eight-byte PNG signature through question_content and obtained an image block. Tests explicitly accept signature-plus-"body" fixtures, so they cannot catch this remaining invalid-input case.
          round: 2
        - id: BR-5
          disposition: not-addressed
          note: workshop/plans/000231-chat-image-attachments-plan.md:290 still labels unique_name PURE despite its filesystem-backed exists callback; :302 likewise labels select PURE despite env.executable calling vim.fn.executable. The named reclassifications landed, but the classification rule was not swept across the table.
          round: 2
        - id: BR-6
          disposition: addressed
          note: README.md now documents M-v, platform tools, assets.clipboard_cmd, its output-token contract, and setup table replacement.
          round: 2
      boundary: M1
      blocked: true
    - "n": 3
      timestamp: "2026-09-12T23:52:43-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: addressed
          note: Existing disposition retained; occurrence-keyed budgeting remains shared by both builders.
          round: 3
        - id: BR-2
          disposition: addressed
          note: Existing disposition retained; continuation uses total exchanges and extracted file references.
          round: 3
        - id: BR-3
          disposition: addressed
          note: Existing disposition retained; launch failure and insertion rollback paths remain present.
          round: 3
        - id: BR-4
          disposition: not-addressed
          note: lua/parley/assets.lua:185–213 still accepts image-less containers in all four formats, and question_content emits them. Error propagation is repaired, but structural image validation remains incomplete.
          round: 3
        - id: BR-5
          disposition: addressed
          note: Core-concepts tables now classify the named effectful callback consumers as integration points and record the classification rule and revision.
          round: 3
        - id: BR-6
          disposition: addressed
          note: Existing disposition retained; README documents the paste binding, dependencies, and clipboard override.
          round: 3
      findings:
        - id: BR-7
          severity: Important
          title: Full image payloads accumulate in the persistent request cache.
          detail: lua/parley/dispatcher.lua:652–654 writes complete image-bearing payloads into query_dir without terminal cleanup. The setup-only count sweep at lines 69–78 leaves long-running sessions unbounded; 100 near-limit requests retain roughly 2 GiB. Delete transport files after subprocess completion on every terminal path, or enforce a writer-side retention budget, with lifecycle documentation and regression coverage. ARCH-FUNERAL.
          family: request-artifact-retention
          round: 3
      boundary: M1
      blocked: true
    - "n": 4
      timestamp: "2026-09-13T00:02:21-07:00"
      agent: codex
      dispose:
        - id: BR-4
          disposition: not-addressed
          note: 'Read-error handling improved, but invalid image bytes still pass: an empty PNG IDAT, JPEG with empty SOF/SOS headers, and GIF with empty image sub-blocks all return true from looks_like. The PNG becomes an outbound image block. Sweep all four validators under persisted-input-validation; require structurally meaningful headers and image data, with rejecting regressions through read_bounded and question_content.'
          round: 4
        - id: BR-7
          disposition: addressed
          note: dispatcher.lua invokes discard_transport before the terminal query-registry guard and on start failure. query_cache_spec.lua asserts removal after success, provider error, cancellation, and spawn failure; removing cleanup leaves files that violate those assertions. Integration execution and mutation verification were unavailable under read-only permissions.
          round: 4
        - id: BR-1
          disposition: addressed
          note: Occurrence identifiers govern budgeting and emission; duplicate-path regression coverage remains.
          round: 4
        - id: BR-2
          disposition: addressed
          note: Continuations use the full exchange count and shared file-reference extraction, with parity regressions.
          round: 4
        - id: BR-3
          disposition: addressed
          note: Launch failures settle once, insertion prerequisites precede saving, and failed insertion rolls back the asset.
          round: 4
        - id: BR-5
          disposition: addressed
          note: The Core concepts tables classify effectful callback consumers as integration points.
          round: 4
        - id: BR-6
          disposition: addressed
          note: README documents M-v, asset storage, platform tools, and the clipboard override.
          round: 4
      boundary: M1
      blocked: true
    - "n": 5
      timestamp: "2026-09-13T00:14:26-07:00"
      agent: codex
      dispose:
        - id: BR-4
          disposition: not-addressed
          note: assets.lua:468 and :474 accept exactly 5-byte VP8L and 10-byte VP8 headers without any image data. Executed probes returned looks_like=true and question_content emitted type=image for both. Existing tests reject shorter headers but omit these exact-length cases. ARCH-SECURE; existing persisted-input-validation family.
          round: 5
        - id: BR-1
          disposition: addressed
          note: 'Prior disposition retained: occurrence-keyed budgeting and repeated-path regression coverage are present.'
          round: 5
        - id: BR-2
          disposition: addressed
          note: 'Prior disposition retained: continuation uses total exchange count and the shared file-reference parser.'
          round: 5
        - id: BR-3
          disposition: addressed
          note: 'Prior disposition retained: launch settlement, insertion rollback, and retry regression coverage are present.'
          round: 5
        - id: BR-5
          disposition: addressed
          note: 'Prior disposition retained: effectful callbacks are classified as integration points in the Core concepts tables.'
          round: 5
        - id: BR-6
          disposition: addressed
          note: 'Prior disposition retained: README documents the keybinding, clipboard tools, and configuration override.'
          round: 5
        - id: BR-7
          disposition: addressed
          note: 'Prior disposition retained: image transport cleanup covers completion and spawn failure, with cancellation and error regression coverage.'
          round: 5
      boundary: M1
      blocked: true
    - "n": 6
      timestamp: "2026-09-13T00:19:49-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: addressed
          note: Shared builder assigns budget identity per attachment occurrence.
          round: 6
        - id: BR-2
          disposition: addressed
          note: Both builders share retention inputs, including total exchanges and file references.
          round: 6
        - id: BR-3
          disposition: addressed
          note: Launch failures settle the operation; insertion failures roll back saved assets.
          round: 6
        - id: BR-4
          disposition: addressed
          note: Real-adapter probes passed; removing WebP minimum-length fixes in memory caused validator and outbound-content regression tests to fail.
          round: 6
        - id: BR-5
          disposition: addressed
          note: Core-concept tables classify effectful callback consumers as integration points.
          round: 6
        - id: BR-6
          disposition: addressed
          note: README documents the paste binding, override, and clipboard requirements.
          round: 6
        - id: BR-7
          disposition: addressed
          note: Dispatcher removes image-bearing transport files on terminal paths.
          round: 6
      boundary: M1
      blocked: false
    - "n": 7
      timestamp: "2026-09-13T00:34:12-07:00"
      agent: codex
      findings:
        - id: BR-8
          severity: Critical
          title: Failed chat deletion silently destroys its assets
          detail: 'lua/parley/init.lua:3567 removes assets before helper.lua:94 attempts chat removal and ignores its failure. Production-code failure injection left the chat present, assets absent, and no notification. ARCH-ORDER / ARCH-FUNERAL: confirm owner deletion before irreversible cleanup; sweep all deletion callers and test filesystem refusal plus buffer-deletion exceptions.'
          family: deletion-commit-before-cleanup
          round: 7
        - id: BR-9
          severity: Critical
          title: Recursive placeholder restoration permits HTML event-handler injection
          detail: 'lua/parley/exporter.lua:457-464 rescans restored tags. Input ![XIMGX2XIMGX](missing.png) ![](onerror=alert`1`//) produces an onerror attribute on the first image, verified by parsing the generated HTML. ARCH-SECURE: use collision-free placeholders with non-recursive restoration and regression tests for literal tokens and tokens inside attributes.'
          family: html-placeholder-isolation
          round: 7
      boundary: M2
      blocked: true
    - "n": 8
      timestamp: "2026-09-13T00:49:01-07:00"
      agent: codex
      dispose:
        - id: BR-8
          disposition: addressed
          note: helper.lua:102-114 checks buffer deletion and os.remove; init.lua:3588-3598 removes assets only after success. Regression tests cover filesystem refusal and buffer exceptions. Read-only production-function probes passed; restoring asset-first ordering failed the preservation assertion.
          round: 8
        - id: BR-9
          disposition: not-addressed
          note: exporter.lua:284 retains forgeable branch tokens, and :807 restores them after image HTML is emitted. Rendering ![XBRANCHX1XBRANCHX](missing.png) alongside a branch substitutes its navigation div inside the image alt attribute. The original image-to-image attack is fixed, but cross-family restoration still violates attribute isolation. Fix html-placeholder-isolation across both families and test their full composition.
          round: 8
      findings:
        - id: BR-10
          severity: Important
          title: Live conformance overwrites clipboard contents it cannot restore
          detail: 'tests/integration/clipboard_live_spec.lua:21-27 saves only a text representation, but :40-48 overwrites the clipboard even when that read failed. An image-only clipboard is therefore replaced permanently with test text. ARCH-SECURE / ARCH-ORDER: skip before mutation when preservation is unavailable, or snapshot and restore all supported clipboard representations; check restoration failures and test this path with a stateful fake.'
          family: external-state-restoration
          round: 8
      boundary: M2
      blocked: true
    - "n": 9
      timestamp: "2026-09-13T00:57:08-07:00"
      agent: codex
      dispose:
        - id: BR-9
          disposition: addressed
          note: Export restores both placeholder families together without rescanning emitted records. Regression tests pass; sequential-family restoration makes the cross-family isolation test fail.
          round: 9
        - id: BR-10
          disposition: addressed
          note: Clipboard preservation failure skips before mutation; restoration verifies read-back. All three fake tests pass, and removing the preservation precondition makes its regression fail.
          round: 9
        - id: BR-8
          disposition: addressed
          note: 'Prior disposition retained: asset cleanup follows successful transcript deletion, with filesystem-refusal and buffer-exception regression coverage.'
          round: 9
      boundary: M2
      blocked: false
---

# Gate ledger — parley.nvim#231 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-12T23:24:30-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `budget-emission-identity` Path-keyed inclusion bypasses per-request image limits.
  lua/parley/assets.lua:301 budgets occurrences but authorizes emission by path; 21 references to one image emitted 21 blocks under the 20-image cap. Preserve occurrence identity through planning and emission, and test duplicate references within and across questions. ARCH-CONSTRAINTS.
- **BR-2** [Critical] `retention-consumer-parity` Initial and continuation builders apply different retention inputs.
  lua/parley/chat_respond.lua:585 uses target_idx as the total and disables file-reference pinning. Probes reproduced both resurrection of an initially omitted image and loss of a pinned image; pass identical retention metadata and add differential tests. ARCH-DRY, ARCH-PURPOSE.
- **BR-3** [Critical] `async-operation-terminal-cleanup` Clipboard launch and insertion failures leave incomplete paste transactions.
  lua/parley/clipboard_image.lua:203 lets spawn errors escape, leaving paste inflight permanently; lua/parley/paste_image.lua:82 saves before insertion and leaves an orphan when insertion fails. Route launch errors through completion and roll back saved bytes after insertion failure, with retry and residue assertions. ARCH-ORDER, ARCH-FUNERAL.
- **BR-4** [Critical] `persisted-input-validation` Read errors and invalid image bytes are submitted as image content.
  lua/parley/assets.lua:501 discards read errors and returns empty bytes; question_content also accepts plain text as PNG. Preserve IO errors, reject nonregular and invalid image inputs with visible notes, and cover these cases against the real read adapter. ARCH-SECURE.
- **BR-5** [Critical] `core-concept-classification` The Core concepts table labels IO-dependent functions PURE.
  workshop/plans/000231-chat-image-attachments-plan.md:299 onward includes filesystem probes, host_env, reader-driven question_content, and buffer/filesystem-dependent builders under the no-IO contract. Reclassify integration functions or extract pure transformations, expose injected dependencies, and append a plan revision. ARCH-PURE.
- **BR-6** [Important] `user-surface-documentation` README documentation is missing for the new paste surface.
  lua/parley/config.lua:412 introduces the M-v binding, and this range introduces assets.clipboard_cmd without updating README.md. Document the binding, override, and tool requirements at M1 instead of deferring them to M2.

## Round 2 — 2026-09-12T23:43:19-07:00 (codex) — BLOCKED

### Disposed

- BR-1 — addressed — Both builders assign occurrence IDs through attach_question_images. Duplicate-reference tests cover within/across questions; an in-memory path-keyed planner mutation caused 12 failures.
- BR-2 — addressed — Continuation now uses the full exchange count and shared file-reference extraction. Differential regressions at tests/unit/build_messages_spec.lua:2139 and :2169 exercise both reported failures.
- BR-3 — addressed — Launch exceptions reach scheduled completion exactly once; insertion failures roll back saved assets. Tests cover launch errors, retries, removal of newly created folders, and preservation of existing assets.
- BR-4 — not-addressed — lua/parley/assets.lua:171 accepts signatures without valid image bodies. A read-only probe submitted the eight-byte PNG signature through question_content and obtained an image block. Tests explicitly accept signature-plus-"body" fixtures, so they cannot catch this remaining invalid-input case.
- BR-5 — not-addressed — workshop/plans/000231-chat-image-attachments-plan.md:290 still labels unique_name PURE despite its filesystem-backed exists callback; :302 likewise labels select PURE despite env.executable calling vim.fn.executable. The named reclassifications landed, but the classification rule was not swept across the table.
- BR-6 — addressed — README.md now documents M-v, platform tools, assets.clipboard_cmd, its output-token contract, and setup table replacement.

## Round 3 — 2026-09-12T23:52:43-07:00 (codex) — BLOCKED

### Disposed

- BR-1 — addressed — Existing disposition retained; occurrence-keyed budgeting remains shared by both builders.
- BR-2 — addressed — Existing disposition retained; continuation uses total exchanges and extracted file references.
- BR-3 — addressed — Existing disposition retained; launch failure and insertion rollback paths remain present.
- BR-4 — not-addressed — lua/parley/assets.lua:185–213 still accepts image-less containers in all four formats, and question_content emits them. Error propagation is repaired, but structural image validation remains incomplete.
- BR-5 — addressed — Core-concepts tables now classify the named effectful callback consumers as integration points and record the classification rule and revision.
- BR-6 — addressed — Existing disposition retained; README documents the paste binding, dependencies, and clipboard override.

### Raised

- **BR-7** [Important] `request-artifact-retention` Full image payloads accumulate in the persistent request cache.
  lua/parley/dispatcher.lua:652–654 writes complete image-bearing payloads into query_dir without terminal cleanup. The setup-only count sweep at lines 69–78 leaves long-running sessions unbounded; 100 near-limit requests retain roughly 2 GiB. Delete transport files after subprocess completion on every terminal path, or enforce a writer-side retention budget, with lifecycle documentation and regression coverage. ARCH-FUNERAL.

## Round 4 — 2026-09-13T00:02:21-07:00 (codex) — BLOCKED

### Disposed

- BR-4 — not-addressed — Read-error handling improved, but invalid image bytes still pass: an empty PNG IDAT, JPEG with empty SOF/SOS headers, and GIF with empty image sub-blocks all return true from looks_like. The PNG becomes an outbound image block. Sweep all four validators under persisted-input-validation; require structurally meaningful headers and image data, with rejecting regressions through read_bounded and question_content.
- BR-7 — addressed — dispatcher.lua invokes discard_transport before the terminal query-registry guard and on start failure. query_cache_spec.lua asserts removal after success, provider error, cancellation, and spawn failure; removing cleanup leaves files that violate those assertions. Integration execution and mutation verification were unavailable under read-only permissions.
- BR-1 — addressed — Occurrence identifiers govern budgeting and emission; duplicate-path regression coverage remains.
- BR-2 — addressed — Continuations use the full exchange count and shared file-reference extraction, with parity regressions.
- BR-3 — addressed — Launch failures settle once, insertion prerequisites precede saving, and failed insertion rolls back the asset.
- BR-5 — addressed — The Core concepts tables classify effectful callback consumers as integration points.
- BR-6 — addressed — README documents M-v, asset storage, platform tools, and the clipboard override.

## Round 5 — 2026-09-13T00:14:26-07:00 (codex) — BLOCKED

### Disposed

- BR-4 — not-addressed — assets.lua:468 and :474 accept exactly 5-byte VP8L and 10-byte VP8 headers without any image data. Executed probes returned looks_like=true and question_content emitted type=image for both. Existing tests reject shorter headers but omit these exact-length cases. ARCH-SECURE; existing persisted-input-validation family.
- BR-1 — addressed — Prior disposition retained: occurrence-keyed budgeting and repeated-path regression coverage are present.
- BR-2 — addressed — Prior disposition retained: continuation uses total exchange count and the shared file-reference parser.
- BR-3 — addressed — Prior disposition retained: launch settlement, insertion rollback, and retry regression coverage are present.
- BR-5 — addressed — Prior disposition retained: effectful callbacks are classified as integration points in the Core concepts tables.
- BR-6 — addressed — Prior disposition retained: README documents the keybinding, clipboard tools, and configuration override.
- BR-7 — addressed — Prior disposition retained: image transport cleanup covers completion and spawn failure, with cancellation and error regression coverage.

## Round 6 — 2026-09-13T00:19:49-07:00 (codex) — passed

### Disposed

- BR-1 — addressed — Shared builder assigns budget identity per attachment occurrence.
- BR-2 — addressed — Both builders share retention inputs, including total exchanges and file references.
- BR-3 — addressed — Launch failures settle the operation; insertion failures roll back saved assets.
- BR-4 — addressed — Real-adapter probes passed; removing WebP minimum-length fixes in memory caused validator and outbound-content regression tests to fail.
- BR-5 — addressed — Core-concept tables classify effectful callback consumers as integration points.
- BR-6 — addressed — README documents the paste binding, override, and clipboard requirements.
- BR-7 — addressed — Dispatcher removes image-bearing transport files on terminal paths.

## Round 7 — 2026-09-13T00:34:12-07:00 (codex) — BLOCKED

### Raised

- **BR-8** [Critical] `deletion-commit-before-cleanup` Failed chat deletion silently destroys its assets
  lua/parley/init.lua:3567 removes assets before helper.lua:94 attempts chat removal and ignores its failure. Production-code failure injection left the chat present, assets absent, and no notification. ARCH-ORDER / ARCH-FUNERAL: confirm owner deletion before irreversible cleanup; sweep all deletion callers and test filesystem refusal plus buffer-deletion exceptions.
- **BR-9** [Critical] `html-placeholder-isolation` Recursive placeholder restoration permits HTML event-handler injection
  lua/parley/exporter.lua:457-464 rescans restored tags. Input ![XIMGX2XIMGX](missing.png) ![](onerror=alert`1`//) produces an onerror attribute on the first image, verified by parsing the generated HTML. ARCH-SECURE: use collision-free placeholders with non-recursive restoration and regression tests for literal tokens and tokens inside attributes.

## Round 8 — 2026-09-13T00:49:01-07:00 (codex) — BLOCKED

### Disposed

- BR-8 — addressed — helper.lua:102-114 checks buffer deletion and os.remove; init.lua:3588-3598 removes assets only after success. Regression tests cover filesystem refusal and buffer exceptions. Read-only production-function probes passed; restoring asset-first ordering failed the preservation assertion.
- BR-9 — not-addressed — exporter.lua:284 retains forgeable branch tokens, and :807 restores them after image HTML is emitted. Rendering ![XBRANCHX1XBRANCHX](missing.png) alongside a branch substitutes its navigation div inside the image alt attribute. The original image-to-image attack is fixed, but cross-family restoration still violates attribute isolation. Fix html-placeholder-isolation across both families and test their full composition.

### Raised

- **BR-10** [Important] `external-state-restoration` Live conformance overwrites clipboard contents it cannot restore
  tests/integration/clipboard_live_spec.lua:21-27 saves only a text representation, but :40-48 overwrites the clipboard even when that read failed. An image-only clipboard is therefore replaced permanently with test text. ARCH-SECURE / ARCH-ORDER: skip before mutation when preservation is unavailable, or snapshot and restore all supported clipboard representations; check restoration failures and test this path with a stateful fake.

## Round 9 — 2026-09-13T00:57:08-07:00 (codex) — passed

### Disposed

- BR-9 — addressed — Export restores both placeholder families together without rescanning emitted records. Regression tests pass; sequential-family restoration makes the cross-family isolation test fail.
- BR-10 — addressed — Clipboard preservation failure skips before mutation; restoration verifies read-back. All three fake tests pass, and removing the preservation precondition makes its regression fail.
- BR-8 — addressed — Prior disposition retained: asset cleanup follows successful transcript deletion, with filesystem-refusal and buffer-exception regression coverage.

## Open findings

(none — every finding has been disposed)
