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
