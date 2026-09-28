---
gate: boundary-review
issue: 295
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-28T15:06:15-07:00"
      agent: codex
      findings:
        - id: BR-1
          severity: Critical
          title: Existing comment leaders can strip the configured private prefix
          detail: 'lua/parley/init.lua:2676-2679 appends the private leader after existing definitions. Production prep_chat with Markdown comments and chat_local_prefix=">PRIVATE:" turns Return into ">second", classified as text rather than private. Native probes also reproduce collisions with //PRIVATE:, %PRIVATE:, XCOMMPRIVATE:, and /*PRIVATE: under default comments. This window has one composition site; sweep shorter single-line, nested, block, and user-defined leaders there. Give the private leader precedence while preserving other definitions, and add keyboard regressions asserting continued lines remain private. ARCH-PURPOSE.'
          family: private-continuation-preserves-classification
          round: 1
        - id: BR-2
          severity: Important
          title: README update is missing for private-note Return continuation
          detail: README.md:57-61 documents private-note insertion and configuration but remains unchanged in this range. The sole new user-facing surface is Insert-mode Return continuation. Document continuation, deleting the prefix to exit, and regular-chat scope alongside the existing private-note instructions.
          family: user-surface-readme-coverage
          round: 1
        - id: BR-3
          severity: Important
          title: Acceptance tests omit custom-prefix boundary cases and prompt submission
          detail: tests/integration/private_note_prefix_spec.lua:78-96 exercises repeated empty lines and mid-line splits only with the default prefix; custom cases cover only end-of-line Return. Lines 119-123 assert prompt options without pressing Return or observing submission. These are the missing cases in the stated Done-when matrix. Parameterize split/repeated-line cases across default and custom prefixes, and drive prompt Return through its real callback with an observable submission boundary.
          family: acceptance-matrix-behavioral-coverage
          round: 1
      recipe: small-diff-review
      blocked: true
    - "n": 2
      timestamp: "2026-09-28T15:12:44-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: addressed
          note: lua/parley/init.lua:2678 prepends the private leader. Tests at tests/integration/private_note_prefix_spec.lua:79-109 cover shorter single-line, nested, block, and user-defined leaders; reverting precedence in a scratch copy causes 19 failures.
          round: 2
        - id: BR-2
          disposition: addressed
          note: README.md:62-64 now documents Return continuation, deleting the prefix to exit, and regular-chat versus prompt scope, consistent with prep_chat and the passing keyboard tests.
          round: 2
        - id: BR-3
          disposition: addressed
          note: tests/integration/private_note_prefix_spec.lua:79-103 parameterizes repeated-empty-line and split cases across nine prefixes; lines 132-143 drive actual Return through prompt submission. Removing the production submission callback in a scratch copy makes that test fail.
          round: 2
      recipe: small-diff-review
      blocked: false
---

# Gate ledger — parley.nvim#295 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-28T15:06:15-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `private-continuation-preserves-classification` Existing comment leaders can strip the configured private prefix
  lua/parley/init.lua:2676-2679 appends the private leader after existing definitions. Production prep_chat with Markdown comments and chat_local_prefix=">PRIVATE:" turns Return into ">second", classified as text rather than private. Native probes also reproduce collisions with //PRIVATE:, %PRIVATE:, XCOMMPRIVATE:, and /*PRIVATE: under default comments. This window has one composition site; sweep shorter single-line, nested, block, and user-defined leaders there. Give the private leader precedence while preserving other definitions, and add keyboard regressions asserting continued lines remain private. ARCH-PURPOSE.
- **BR-2** [Important] `user-surface-readme-coverage` README update is missing for private-note Return continuation
  README.md:57-61 documents private-note insertion and configuration but remains unchanged in this range. The sole new user-facing surface is Insert-mode Return continuation. Document continuation, deleting the prefix to exit, and regular-chat scope alongside the existing private-note instructions.
- **BR-3** [Important] `acceptance-matrix-behavioral-coverage` Acceptance tests omit custom-prefix boundary cases and prompt submission
  tests/integration/private_note_prefix_spec.lua:78-96 exercises repeated empty lines and mid-line splits only with the default prefix; custom cases cover only end-of-line Return. Lines 119-123 assert prompt options without pressing Return or observing submission. These are the missing cases in the stated Done-when matrix. Parameterize split/repeated-line cases across default and custom prefixes, and drive prompt Return through its real callback with an observable submission boundary.

## Round 2 — 2026-09-28T15:12:44-07:00 (codex) — passed

### Disposed

- BR-1 — addressed — lua/parley/init.lua:2678 prepends the private leader. Tests at tests/integration/private_note_prefix_spec.lua:79-109 cover shorter single-line, nested, block, and user-defined leaders; reverting precedence in a scratch copy causes 19 failures.
- BR-2 — addressed — README.md:62-64 now documents Return continuation, deleting the prefix to exit, and regular-chat versus prompt scope, consistent with prep_chat and the passing keyboard tests.
- BR-3 — addressed — tests/integration/private_note_prefix_spec.lua:79-103 parameterizes repeated-empty-line and split cases across nine prefixes; lines 132-143 drive actual Return through prompt submission. Removing the production submission callback in a scratch copy makes that test fail.

## Open findings

(none — every finding has been disposed)
