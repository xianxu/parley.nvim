---
gate: boundary-review
issue: 287
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-27T11:27:08-07:00"
      agent: claude
      findings:
        - id: BR-1
          severity: Important
          title: Adding keys to the telescope spec makes it lazy-loaded, so :Telescope is gone at startup
          detail: 'lazy.nvim treats any spec that has keys/cmd/event/ft as lazy unless it sets lazy = false. Telescope was loaded at startup before this change; now :Telescope is undefined, and missing from blink''s : menu, until the user presses <C-g>:. Fix: add cmd = "Telescope" (or lazy = false) at packaging/starter-config/init.lua:147 and assert it in tests/packaging/bootstrap_lazy.lua. Family enumeration for this window: telescope is the only spec whose loading changed; lualine and blink set lazy = false, and markdown-preview already uses cmd/ft on purpose.'
          family: lazy-spec-trigger-implies-lazy
          round: 1
        - id: BR-2
          severity: Minor
          title: bootstrap_lazy restores package.loaded telescope.builtin only if the handler returns normally
          detail: tests/packaging/bootstrap_lazy.lua:23-26. Wrap the call in pcall, restore, then re-raise.
          family: test-global-restore-not-error-safe
          round: 1
        - id: BR-3
          severity: Minor
          title: completion_compatibility.lua is not run by any test runner or release script
          detail: Same as statusline_compatibility.lua. Record the manual command (PARLEY_BLINK_RUNTIME) as a release step so the real-blink ranking check doesn't go stale.
          family: release-check-not-wired
          round: 1
      recipe: small-diff-review
      blocked: true
    - "n": 2
      timestamp: "2026-09-27T11:30:25-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: init.lua sets telescope lazy = false. bootstrap_lazy.lua:30-36 fails any spec with a trigger that lacks lazy = false (MarkdownPreview excepted). Removing the fix fails the test. Starter specs pass.
          round: 2
        - id: BR-2
          disposition: addressed
          note: bootstrap_lazy.lua:25-27 now calls through pcall, restores the global, then raises call_error.
          round: 2
        - id: BR-3
          disposition: addressed
          note: packaging/README.md:34-37 documents the PARLEY_BLINK_RUNTIME completion_compatibility run as a release step for blink bumps, matching the existing theme check.
          round: 2
      recipe: small-diff-review
      blocked: false
---

# Gate ledger — parley.nvim#287 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-27T11:27:08-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `lazy-spec-trigger-implies-lazy` Adding keys to the telescope spec makes it lazy-loaded, so :Telescope is gone at startup
  lazy.nvim treats any spec that has keys/cmd/event/ft as lazy unless it sets lazy = false. Telescope was loaded at startup before this change; now :Telescope is undefined, and missing from blink's : menu, until the user presses <C-g>:. Fix: add cmd = "Telescope" (or lazy = false) at packaging/starter-config/init.lua:147 and assert it in tests/packaging/bootstrap_lazy.lua. Family enumeration for this window: telescope is the only spec whose loading changed; lualine and blink set lazy = false, and markdown-preview already uses cmd/ft on purpose.
- **BR-2** [Minor] `test-global-restore-not-error-safe` bootstrap_lazy restores package.loaded telescope.builtin only if the handler returns normally
  tests/packaging/bootstrap_lazy.lua:23-26. Wrap the call in pcall, restore, then re-raise.
- **BR-3** [Minor] `release-check-not-wired` completion_compatibility.lua is not run by any test runner or release script
  Same as statusline_compatibility.lua. Record the manual command (PARLEY_BLINK_RUNTIME) as a release step so the real-blink ranking check doesn't go stale.

## Round 2 — 2026-09-27T11:30:25-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — init.lua sets telescope lazy = false. bootstrap_lazy.lua:30-36 fails any spec with a trigger that lacks lazy = false (MarkdownPreview excepted). Removing the fix fails the test. Starter specs pass.
- BR-2 — addressed — bootstrap_lazy.lua:25-27 now calls through pcall, restores the global, then raises call_error.
- BR-3 — addressed — packaging/README.md:34-37 documents the PARLEY_BLINK_RUNTIME completion_compatibility run as a release step for blink bumps, matching the existing theme check.

## Open findings

(none — every finding has been disposed)
