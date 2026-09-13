# Boundary Review — parley.nvim#231 (whole-issue close)

| field | value |
|-------|-------|
| issue | 231 — Attach images to questions: paste from clipboard, send to every wire, render in preview |
| repo | parley.nvim |
| issue file | workshop/issues/000231-attach-images-to-questions-paste-from-clipboard-send-to-every-wire-render-in-preview.md |
| boundary | whole-issue close |
| milestone | — |
| window | 80fb39110267a500b8645d71196ac39955815757..f43062bcbeec344d282bd220793690d758aeecba |
| command | sdlc close --issue 231 |
| reviewer | codex |
| timestamp | 2026-09-13T00:59:59-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: medium
```

The pinned range delivers the documented capture, sending, retention, move/delete, and export behavior. All ten prior findings have reachable fixes and supporting regression coverage; no new blockers were found. Confidence is medium because this read-only review could run lint and targeted probes, but not filesystem integration tests or scratch-copy mutation tests.

1. **Strengths**
   - Both builders share retention and occurrence-based budgeting in `chat_respond.lua`.
   - Asset reads are bounded and validate image structure; malformed-input matrices cover all four formats.
   - Chat deletion checks transcript removal before deleting assets.
   - HTML export restores both placeholder families together without rescanning emitted markup.
   - README and atlas document the new keybinding, configuration, wire shapes, and lifecycle.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage notes**
   - Required stat/name-status inspections and targeted patches completed against the pinned objects.
   - `make lint`: **0 warnings / 0 errors in 384 files**.
   - Read-only probes passed for retention, OpenAI image translation, repeated-path budgeting, valid/truncated fixtures, and 20,000 arbitrary validator inputs.
   - Regression tests were inspected for actual failing counterexamples and production reachability. Full integration and live-provider tests were not rerun.

6. **Architectural notes**
   - **ARCH-DRY — pass:** shared attachment grammar, retention, budget, storage, and deletion helpers.
   - **ARCH-PURE — pass:** current concept tables distinguish value transformations from effectful callbacks.
   - **ARCH-PURPOSE — pass:** documented consumers and lifecycle operations are covered.
   - **ARCH-MOCK — pass:** injected filesystem and clipboard seams have stateful doubles; live conformance exists.
   - **ARCH-CONSTRAINTS — pass:** bounded reads, image/count budgets, timeout, and final payload refusal.
   - **ARCH-SECURE — pass:** constrained attachment paths, byte validation, argv boundaries, and isolated HTML restoration.
   - **ARCH-ORDER — pass:** controlled clipboard completion, rollback/retry coverage, and checked deletion ordering.
   - **ARCH-FUNERAL — pass:** sidecar ownership, temporary-file cleanup, request-file cleanup, and accepted residue are documented.

7. **Plan revision recommendations:** None.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Occurrence-keyed budgeting is exercised by repeated-path regression tests and a passing 21-reference probe.
  - id: BR-2
    disposition: addressed
    note: |
      Differential builder tests cover total-exchange retention and old exchanges pinned by file references.
  - id: BR-3
    disposition: addressed
    note: |
      Tests cover launch failure, nonmodifiable buffers, insertion rollback, existing-folder preservation, and retry.
  - id: BR-4
    disposition: addressed
    note: |
      Malformed-container matrices exercise validation, bounded reading, and content emission for all four formats.
  - id: BR-5
    disposition: addressed
    note: |
      The current concept tables classify effectful readers and existence callbacks as integration entities.
  - id: BR-6
    disposition: addressed
    note: |
      README documents the paste keybinding, platform tools, clipboard override, storage, and retention.
  - id: BR-7
    disposition: addressed
    note: |
      Request-cache tests cover image-body removal on success, provider error, cancellation, and spawn failure.
  - id: BR-8
    disposition: addressed
    note: |
      Deletion regressions verify filesystem refusal and buffer exceptions preserve the transcript and assets.
  - id: BR-9
    disposition: addressed
    note: |
      Pure isolation tests and real-export E4/E5 exercise same-family and cross-family placeholder attacks.
  - id: BR-10
    disposition: addressed
    note: |
      Stateful policy tests cover skipping before mutation, exact text restoration, and failed readback.
```
