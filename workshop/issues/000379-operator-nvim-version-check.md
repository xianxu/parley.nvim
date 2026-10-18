---
id: 000379
status: open
deps: []
github_issue:
created: 2026-10-17
updated: 2026-10-17
estimate_hours:
collaboration-mode: collaboration
card_mirror: '32744fdcbe9a6b09a09c56dd9ce7fc59410b2758' # card fields mirrored from issue-cards; edit via sdlc
---

# Check operator Neovim compatibility

## Problem

The operator's PATH Neovim is 0.11.7, but scripts/test-nvim.sh selects 0.12.5 for its newer LuaJIT mcode fix. Our full suite can therefore pass while the installed operator editor is broken.

During #373's real-profile live check, all full-suite tests passed on 0.12.5, then a registered move failed immediately on PATH Neovim 0.11.7 with E976: Using a Blob as a String. document_move's journal-budget namespace contains a NUL; vim.fn.sha256 accepts its binary representation on 0.12 but refuses it on 0.11. The lease-boundary defect is fixed under #373; this issue owns preventing the wider version-coverage gap.

## Spec

Make the editor-version support contract explicit and enforce it. Either exercise the operator's Neovim version with the suite or a meaningful smoke subset in addition to the preferred test runtime, or declare and check a minimum version so an unsupported installed editor cannot silently start. Preserve the existing newer-LuaJIT test selection and its performance rationale unless the chosen policy supersedes it deliberately.

Any local-gate configuration change requires operator verification under local-gates-guard; do not apply that label as an agent.

## Done when

- Document the supported Neovim versions and how the operator's installed version is checked.
- Automated verification detects a version-specific compatibility regression such as the binary SHA-256 failure on 0.11; selecting 0.12 for performance cannot hide it.
- If 0.11 remains supported, run a meaningful suite or smoke subset on it. If it is unsupported, startup or installation gives a clear minimum-version diagnostic and the supported runtime is exercised.
- Keep the local-gate change and any required operator verification explicit.

## Plan

- [ ]

## Log

### 2026-10-17

Filed unclaimed on TL instruction (receipt 4b20a07a-3975-44a4-8087-b941a0d31569). Evidence: PATH /opt/homebrew/bin/nvim reports NVIM v0.11.7; the selected suite runtime /opt/homebrew/opt/neovim/bin/nvim is 0.12.5. Recorded #373 suite eea1accf42a3e8bb2066abb9742ce90a3b5d2c0f passed, exit 0 in 2m20s, log SHA256 prefix b0d48b081b89. Real profile /Users/xianxu/.config/parley with staged runtime failed at document_lease.lua:106 hashing the NUL-delimited budget namespace. Stage cleared, disposable registry entry forgotten, scratch removed. No credential changes or real-document edits.
