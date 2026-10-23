# Boundary Review — parley.nvim#417 (whole-issue close)

| field | value |
|-------|-------|
| issue | 417 — Alt+i pastes a clipboard image without a confirmation prompt; error if no image |
| repo | parley.nvim |
| issue file | workshop/issues/000417-alt-i-pastes-a-clipboard-image-without-a-confirmation-prompt-error-if-no-image.md |
| boundary | whole-issue close |
| milestone | — |
| window | 6fd47fd82f6aeab218ff8cd0c6c989c6ffb7b412..ff795ebb314708b3901ef07ded0dba2b8826b571 |
| command | sdlc close --issue 417 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-22T18:13:23-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The default small-image paste and no-image error work as specified. However, successful pastes that retain shrink warnings still trigger hit-enter in both modes, leaving the issue’s central requirement incomplete.

Done-when: current — its image/no-image clauses still cover the revised notification behavior.

```findings
findings:
  - id: new
    severity: Critical
    kind: defect
    family: paste-completion-must-not-block-input
    title: |
      Shrink diagnostics still make successful image pastes require Enter
    detail: |
      lua/parley/paste_image.lua:164-167 appends an unbounded outcome suffix to the shortened success message. On pinned HEAD, an attached 80×24 UI on Neovim 0.11.7 entered mode "r" after Alt+i in both Normal and Insert modes with either fake_sips returning garbage or no shrink tool available; the attachment and link had already landed. ARCH-PURPOSE: shortening only the no-diagnostic outcome leaves the reported prompt unresolved for other successful pastes. The family has one emission site in this window, fed by all three note-producing paths in image_shrink.lua:240,245,258: conversion-limit refusal, tool/configuration resolution failure, and converter execution/output failure. Preserve diagnostics through a nonblocking presentation and add native UI regression cases for these outcomes. The changed recording-notifier assertions at paste_image_spec.lua:520,535 cannot detect hit-enter; atlas/chat/attachments.md:17-18 also overstates the resulting guarantee.
```

1. **Strengths**

   - Reuses the existing writer, naming, insertion and rollback paths.
   - No-image handling reports the exact error and tests unchanged buffer contents and absent asset folders.
   - Native UI tests retain builtin notifications and verify subsequent typing, providing useful coverage of the original failure.
   - README, atlas and traceability updates are present.

2. **Critical findings**

   - The finding above blocks shipping. Make diagnostic-bearing completion nonblocking while preserving access to the warning details.

3. **Important findings**

   None.

4. **Minor findings**

   None.

5. **Test coverage notes**

   `make test-spec SPEC=chat/attachments` passed with a clean process census on Neovim 0.11.7. Changed-file lint and diff whitespace checks passed. Additional native probes confirmed small-image success and unchanged no-image buffers in both modes, but reproduced the diagnostic-bearing prompt described above. No full-suite or second-version verification was performed during this review.

6. **Architectural notes**

   - **ARCH-DRY: pass** — existing attachment and shrink helpers remain authoritative.
   - **ARCH-PURE: pass** — this change stays within the existing integration boundary.
   - **ARCH-PURPOSE: flag** — warning-bearing successful pastes still block input.
   - **ARCH-EVOLVE: pass** — no persisted format changes.

7. **Plan revision recommendations**

   Add a `## Revisions` entry covering every diagnostic-bearing completion path and its native UI regression coverage. Reopen the completion-feedback and coverage checkboxes until those cases pass; correct the atlas guarantee alongside the fix.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"5ab14ae6-65ba-448f-bf86-eb592a911513","repository":"github.com/xianxu/parley.nvim","issue_id":"000417","recipe":"small-diff-review","round":1,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/768a9b9e436ceb93","reviewed_head":"ff795ebb314708b3901ef07ded0dba2b8826b571","slot":"parley.nvim:1","requested_at":"2026-10-23T01:11:02.410636Z"},"phase":"finished","pid":45127,"started_at":"2026-10-23T01:11:02.505382Z","finished_at":"2026-10-23T01:13:22.994027Z","session_id":"01a1664f-b77f-7430-a67e-b456ed618103","outcome":"returned"}] -->

---

## Re-review — 2026-10-22T18:28:15-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 417 — Alt+i pastes a clipboard image without a confirmation prompt; error if no image |
| repo | parley.nvim |
| issue file | workshop/issues/000417-alt-i-pastes-a-clipboard-image-without-a-confirmation-prompt-error-if-no-image.md |
| boundary | whole-issue close |
| milestone | — |
| window | 6fd47fd82f6aeab218ff8cd0c6c989c6ffb7b412..0761a9dcdd134c023fcdedb09e0d763e2c95c36f |
| command | sdlc close --issue 417 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-22T18:28:15-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

BR-1 is addressed: successful pastes now use one fixed notice, while full diagnostics remain in the existing log. Regression tests detect the original failure on both supported Neovim versions. One Important coverage gap remains: the no-image contract is not exercised through Alt+i in both modes.

Done-when: current — image insertion without a prompt and no-image refusal without mutation still cover the revised presentation policy.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      paste_image.lua:164-168 separates diagnostic logging from the fixed success notice. The permanent native tests pass on Neovim 0.12.5 and 0.11.7. Restoring the diagnostic-bearing notice in a disposable archive causes eight native mode assertions to fail on each version, covering every diagnostic producer in both modes. The archive was removed.
findings:
  - id: new
    severity: Important
    kind: defect
    family: mode-specific-contract-coverage
    title: |
      No-image refusal lacks Normal and Insert mapping coverage
    detail: |
      tests/integration/paste_image_native_spec.lua:37-46 exercises only image-present cases. The sole no-image assertion at tests/integration/paste_image_spec.lua:154-165 calls parley.paste_image directly with a recording notifier. The complete missing family is no-image Alt+i in Normal mode and Insert mode: neither verifies the builtin one-line error, unchanged buffer/assets, and retained input mode. Add both native cases on the supported versions to fulfill the checked Plan item at the issue's line 45.
```

1. **Strengths**

   - One shared completion site enforces the fixed success notice.
   - Existing naming, writer, shrink, insertion and rollback paths are reused.
   - Native regressions cover all diagnostic producers, saved bytes, logged details and subsequent typing.
   - README, atlas and traceability updates describe the implemented log policy.

2. **Critical findings**

   None remaining.

3. **Important findings**

   Add the two no-image mapping cases identified above. This closes the gap between the checked Plan and delivered coverage.

4. **Minor findings**

   None.

5. **Test coverage notes**

   Attachment checks passed on Neovim 0.12.5 and 0.11.7; the latter reported 502 successes, zero failures and zero errors. Both completed with clean process censuses. The mutation check produced eight expected failures per version. Changed-file lint and diff whitespace checks passed. No full-suite run was performed.

6. **Architectural notes**

   - **ARCH-DRY: pass** — existing helpers and logger remain authoritative.
   - **ARCH-PURE: pass** — the change stays within the thin integration boundary.
   - **ARCH-PURPOSE: pass** — the shared presentation rule covers every successful outcome; the remaining finding concerns verification.
   - **ARCH-EVOLVE: pass** — no persisted format changes.

7. **Plan revision recommendations**

   No design revision is needed. Reopen the coverage checkbox until both no-image native cases pass, then record their verification under `## Revisions`.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"1adb542a-91a2-4ade-befa-5a1efa04622c","repository":"github.com/xianxu/parley.nvim","issue_id":"000417","recipe":"small-diff-review","round":2,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/511a606f6340ce3b","reviewed_head":"0761a9dcdd134c023fcdedb09e0d763e2c95c36f","slot":"parley.nvim:1","requested_at":"2026-10-23T01:26:07.54984Z"},"phase":"finished","pid":42433,"started_at":"2026-10-23T01:26:07.645826Z","finished_at":"2026-10-23T01:28:14.404591Z","session_id":"01a1665d-8734-7b70-8aaf-99240af719e9","outcome":"returned"}] -->
