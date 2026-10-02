---
gate: boundary-review
issue: 294
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-10-01T17:43:43-07:00"
      agent: claude
      findings:
        - id: BR-1
          severity: Important
          title: New diag_display re-wrap test passes with the re-wrap fix removed
          detail: Reverting diag_display.lua:338-346 in a scratch copy on nvim 0.12.5 leaves "re-wraps once a sign column opened in the same update" green; only the pre-existing :239 test goes red (0.12 only). Rebuild the test so the signs handler opens the column in the same vim.diagnostic.set and confirm it fails without the fix. Only instance in this window.
          family: regression-test-must-fail-without-fix
          round: 1
        - id: BR-2
          severity: Important
          title: Chat buffers now unconditionally stop treesitter, a user-visible change with no opt-out or docs
          detail: init.lua:2684-2692 stops treesitter in every chat, so users with treesitter markdown on 0.11 lose fenced-code injection highlighting and conceal in chats; highlighter.lua (:741, :1187) was written to coexist with treesitter. Add a config key (documented in README) or stop only when the ftplugin started it, and record it in Revisions.
          family: user-facing-change-undeclared
          round: 1
        - id: BR-3
          severity: Minor
          title: Deferred re-wrap re-reads vim.diagnostic.get instead of the filtered diagnostics show received
          detail: diag_display.lua:344; the token already guarantees the captured list is current.
          family: rewrap-source-of-truth
          round: 1
        - id: BR-4
          severity: Minor
          title: PARLEY_TEST_NVIM and PARLEY_TEST_JITSTAT not in TOOLING.md; PARLEY_TEST_NVIM requires a binary named nvim
          family: dev-docs-missing-env
          round: 1
      recipe: small-diff-review
      blocked: true
    - "n": 2
      timestamp: "2026-10-01T17:51:15-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: Verified by scratch revert of diag_display.lua:335-346 - the re-wrap case fails on 0.11.7 and 0.12.5, passes with the fix; token-guard mutation also red on both.
          round: 2
        - id: BR-2
          disposition: addressed
          note: chat_treesitter config key (config.lua:315, default false) gates the stop at init.lua:2689; documented in atlas/ui/highlights.md (README defers config to atlas); opt-out case in chat_treesitter_spec passes.
          round: 2
        - id: BR-3
          disposition: addressed
          note: diag_display.lua:345 now renders the diagnostics show received, guarded by the token.
          round: 2
        - id: BR-4
          disposition: addressed
          note: TOOLING.md documents PARLEY_TEST_NVIM (including the binary-must-be-named-nvim constraint) and PARLEY_TEST_JITSTAT.
          round: 2
      findings:
        - id: BR-5
          severity: Minor
          title: PARLEY_TEST_NVIM override is not validated; a bad path silently falls back to the PATH nvim
          detail: scripts/test-nvim.sh:19-21 prints dirname without checking -x or basename=nvim; warn instead. Only instance in this window. Related to, not a repeat of, BR-4 (now documented); the rule is that an operator override is checked where it is read.
          family: dev-docs-missing-env
          round: 2
      recipe: small-diff-review
      blocked: false
---

# Gate ledger — parley.nvim#294 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-01T17:43:43-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `regression-test-must-fail-without-fix` New diag_display re-wrap test passes with the re-wrap fix removed
  Reverting diag_display.lua:338-346 in a scratch copy on nvim 0.12.5 leaves "re-wraps once a sign column opened in the same update" green; only the pre-existing :239 test goes red (0.12 only). Rebuild the test so the signs handler opens the column in the same vim.diagnostic.set and confirm it fails without the fix. Only instance in this window.
- **BR-2** [Important] `user-facing-change-undeclared` Chat buffers now unconditionally stop treesitter, a user-visible change with no opt-out or docs
  init.lua:2684-2692 stops treesitter in every chat, so users with treesitter markdown on 0.11 lose fenced-code injection highlighting and conceal in chats; highlighter.lua (:741, :1187) was written to coexist with treesitter. Add a config key (documented in README) or stop only when the ftplugin started it, and record it in Revisions.
- **BR-3** [Minor] `rewrap-source-of-truth` Deferred re-wrap re-reads vim.diagnostic.get instead of the filtered diagnostics show received
  diag_display.lua:344; the token already guarantees the captured list is current.
- **BR-4** [Minor] `dev-docs-missing-env` PARLEY_TEST_NVIM and PARLEY_TEST_JITSTAT not in TOOLING.md; PARLEY_TEST_NVIM requires a binary named nvim

## Round 2 — 2026-10-01T17:51:15-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — Verified by scratch revert of diag_display.lua:335-346 - the re-wrap case fails on 0.11.7 and 0.12.5, passes with the fix; token-guard mutation also red on both.
- BR-2 — addressed — chat_treesitter config key (config.lua:315, default false) gates the stop at init.lua:2689; documented in atlas/ui/highlights.md (README defers config to atlas); opt-out case in chat_treesitter_spec passes.
- BR-3 — addressed — diag_display.lua:345 now renders the diagnostics show received, guarded by the token.
- BR-4 — addressed — TOOLING.md documents PARLEY_TEST_NVIM (including the binary-must-be-named-nvim constraint) and PARLEY_TEST_JITSTAT.

### Raised

- **BR-5** [Minor] `dev-docs-missing-env` PARLEY_TEST_NVIM override is not validated; a bad path silently falls back to the PATH nvim
  scripts/test-nvim.sh:19-21 prints dirname without checking -x or basename=nvim; warn instead. Only instance in this window. Related to, not a repeat of, BR-4 (now documented); the rule is that an operator override is checked where it is read.

## Open findings

- **BR-5** [Minor] `dev-docs-missing-env` PARLEY_TEST_NVIM override is not validated; a bad path silently falls back to the PATH nvim
