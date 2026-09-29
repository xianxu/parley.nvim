---
gate: boundary-review
issue: 303
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-29T12:07:02-07:00"
      agent: codex
      findings:
        - id: BR-1
          severity: Minor
          title: Remove trailing whitespace from the committed review transcript
          detail: workshop/plans/000300-app-labels-buffer-completion-close-review.md:45 contains trailing whitespace reported by git diff --check across the pinned range. Remove the whitespace; runtime behavior is unaffected.
          family: diff-hygiene
          round: 1
      recipe: milestone-review
      blocked: false
    - "n": 2
      timestamp: "2026-09-29T12:23:53-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: addressed
          note: The committed review transcript at line 45 no longer contains trailing whitespace; the pinned-range check reports only demo/REHEARSAL.md.
          round: 2
      findings:
        - id: BR-2
          severity: Critical
          title: An older file read can replace the newly selected recording
          detail: 'demo/viewer.html:87-89 awaits f.text() without checking whether that selection is still current. Executing the production handler with controlled promises, selecting A then B and completing B before A leaves A displayed. ARCH-ORDER: guard completion with a selection generation, ignore superseded results, and add a regression covering both completion orders.'
          family: latest-selection-owns-async-result
          round: 2
        - id: BR-3
          severity: Important
          title: Browser drafts accumulate without cleanup and failed saves remain invisible
          detail: 'demo/viewer.html:56,95-97 creates a persistent key for each cast URL with no removal or retention bound. Storage exceptions are swallowed while the UI promises retained notes. A stateful storage probe retained 100 keys for 100 casts; an injected quota failure silently discarded the revision on reload. ARCH-FUNERAL/ARCH-CONSTRAINTS: define bounded retention and visibly report unsaved changes; cover retention and storage failure with regression tests.'
          family: durable-drafts-have-bounded-retention
          round: 2
        - id: BR-4
          severity: Important
          title: Atlas update appears missing for the recording viewer and caption-drafting workflow
          detail: demo/README.md:82 introduces viewer.html, URL/file loading, Alt+T stamps, browser persistence and caption downloads, but the atlas changes in this range describe completion and chat tags only. Document the viewer, its storage lifecycle and verification entry point in atlas/infra/starter.md or a linked atlas page.
          family: new-workflows-reach-atlas
          round: 2
        - id: BR-5
          severity: Minor
          title: Pinned-range whitespace validation still fails in the rehearsal script
          detail: 'demo/REHEARSAL.md:10,12,14,18,22,24,26 contains trailing whitespace. This is the 2nd finding in family diff-hygiene. Earlier rounds fixed instances: apply the rule that every added line across the entire pinned range passes git diff --check, and sweep all seven occurrences rather than fixing one line.'
          family: diff-hygiene
          round: 2
      recipe: milestone-review
      blocked: true
    - "n": 3
      timestamp: "2026-09-29T12:30:56-07:00"
      agent: codex
      dispose:
        - id: BR-2
          disposition: addressed
          note: demo/viewer.html:96-105 guards successful and failed reads by selection generation. Both completion-order regressions pass and fail when the success guard is removed in memory.
          round: 3
        - id: BR-3
          disposition: addressed
          note: demo/viewer.html:112-158 bounds persisted drafts to 20, migrates legacy keys after successful persistence, and visibly reports storage failures. Retention and warning mutations independently make the corresponding regressions fail.
          round: 3
        - id: BR-4
          disposition: addressed
          note: atlas/infra/starter.md now documents viewer loading, timestamp insertion, downloads, selection ownership, bounded storage, legacy cleanup, and the production-script verification command; these match demo/viewer.html.
          round: 3
        - id: BR-5
          disposition: addressed
          note: git diff --check across the complete pinned range exits successfully, including demo/REHEARSAL.md.
          round: 3
      recipe: milestone-review
      blocked: false
---

# Gate ledger — parley.nvim#303 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-29T12:07:02-07:00 (codex) — passed

### Raised

- **BR-1** [Minor] `diff-hygiene` Remove trailing whitespace from the committed review transcript
  workshop/plans/000300-app-labels-buffer-completion-close-review.md:45 contains trailing whitespace reported by git diff --check across the pinned range. Remove the whitespace; runtime behavior is unaffected.

## Round 2 — 2026-09-29T12:23:53-07:00 (codex) — BLOCKED

### Disposed

- BR-1 — addressed — The committed review transcript at line 45 no longer contains trailing whitespace; the pinned-range check reports only demo/REHEARSAL.md.

### Raised

- **BR-2** [Critical] `latest-selection-owns-async-result` An older file read can replace the newly selected recording
  demo/viewer.html:87-89 awaits f.text() without checking whether that selection is still current. Executing the production handler with controlled promises, selecting A then B and completing B before A leaves A displayed. ARCH-ORDER: guard completion with a selection generation, ignore superseded results, and add a regression covering both completion orders.
- **BR-3** [Important] `durable-drafts-have-bounded-retention` Browser drafts accumulate without cleanup and failed saves remain invisible
  demo/viewer.html:56,95-97 creates a persistent key for each cast URL with no removal or retention bound. Storage exceptions are swallowed while the UI promises retained notes. A stateful storage probe retained 100 keys for 100 casts; an injected quota failure silently discarded the revision on reload. ARCH-FUNERAL/ARCH-CONSTRAINTS: define bounded retention and visibly report unsaved changes; cover retention and storage failure with regression tests.
- **BR-4** [Important] `new-workflows-reach-atlas` Atlas update appears missing for the recording viewer and caption-drafting workflow
  demo/README.md:82 introduces viewer.html, URL/file loading, Alt+T stamps, browser persistence and caption downloads, but the atlas changes in this range describe completion and chat tags only. Document the viewer, its storage lifecycle and verification entry point in atlas/infra/starter.md or a linked atlas page.
- **BR-5** [Minor] `diff-hygiene` Pinned-range whitespace validation still fails in the rehearsal script
  demo/REHEARSAL.md:10,12,14,18,22,24,26 contains trailing whitespace. This is the 2nd finding in family diff-hygiene. Earlier rounds fixed instances: apply the rule that every added line across the entire pinned range passes git diff --check, and sweep all seven occurrences rather than fixing one line.

## Round 3 — 2026-09-29T12:30:56-07:00 (codex) — passed

### Disposed

- BR-2 — addressed — demo/viewer.html:96-105 guards successful and failed reads by selection generation. Both completion-order regressions pass and fail when the success guard is removed in memory.
- BR-3 — addressed — demo/viewer.html:112-158 bounds persisted drafts to 20, migrates legacy keys after successful persistence, and visibly reports storage failures. Retention and warning mutations independently make the corresponding regressions fail.
- BR-4 — addressed — atlas/infra/starter.md now documents viewer loading, timestamp insertion, downloads, selection ownership, bounded storage, legacy cleanup, and the production-script verification command; these match demo/viewer.html.
- BR-5 — addressed — git diff --check across the complete pinned range exits successfully, including demo/REHEARSAL.md.

## Open findings

(none — every finding has been disposed)
