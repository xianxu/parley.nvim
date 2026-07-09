---
id: 000180
status: working
deps: []
github_issue:
created: 2026-07-09
updated: 2026-07-09
estimate_hours: 0.20
started: 2026-07-09T11:16:32-07:00
---

# recover footnote spans from slug ids

## Problem

After reopening a chat, persisted definition footnotes only recover multi-word
highlight spans when the footer starts with a structured quoted/backquoted term.
Existing generated footnotes often do not have that structured prefix; for
`serverless functions[^serverless-functions]`, reload falls back to the last
token and highlights only `functions[^serverless-functions]`.

## Spec

`define.footnote_diagnostics` should use the footnote id slug as a secondary
anchor hint when no structured footer term is present. For id
`serverless-functions`, derive the phrase `serverless functions` and look for the
nearest matching phrase before `[^serverless-functions]`, allowing the same
closing quote/bracket suffix as structured terms. Matching should be
case-insensitive but the diagnostic term should preserve the body text as typed.

Precedence:

1. Structured leading quoted/backquoted footer term from #179.
2. Slug-derived phrase from the footnote id.
3. Existing contiguous-token fallback.

The reload highlight and floating-window trigger continue to derive from the
same diagnostic span (ARCH-DRY, ARCH-PURE, ARCH-PURPOSE).

## Done when

- `serverless functions[^serverless-functions]` reloads with a diagnostic and
  highlight spanning `serverless functions[^serverless-functions]`, even when
  the footer is unstructured.
- Case mismatches such as `Serverless Functions[^serverless-functions]` still
  recover the full typed phrase.
- If the slug phrase is absent before the reference, the existing last-token
  fallback remains unchanged.

## Plan

- [x] Add failing pure diagnostics coverage for slug-derived multi-word anchors
  and case-insensitive typed-span preservation.
- [x] Add a reload highlight regression for an unstructured slug-derived
  multi-word anchor.
- [x] Implement slug-derived phrase matching in `lua/parley/define.lua` after
  structured terms and before token fallback.
- [x] Update atlas docs for slug-derived reload span fallback.
- [x] Run focused tests plus lint/diff checks.

## Estimate

Derived via `estimate-logic-v3.1` against the repo-local calibration source from
`sdlc estimate-source` (stale but canonical for this repo).

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec design=0.02 impl=0.00
item: lua-neovim design=0.04 impl=0.12
item: milestone-review design=0.00 impl=0.02
total: 0.20
```

## Log

### 2026-07-09

- User showed reload highlight recovering only `functions[^serverless-functions]`
  for `serverless functions[^serverless-functions]`. Root cause: #179 only
  handles structured footer terms; generated unstructured footnotes still use the
  old contiguous-token fallback.
- TDD red: `define_spec` reproduced `functions[^serverless-functions]` starting
  at column 23, and `highlighting_spec` reproduced the same reload highlight
  start. Implemented slug-derived phrase matching between structured footer terms
  and the final token fallback.
- Verification: `make lint` passed; `nvim --headless -c "PlenaryBustedFile
  tests/unit/define_spec.lua"` passed; `nvim --headless -c "PlenaryBustedFile
  tests/integration/highlighting_spec.lua"` passed; scoped `git diff --check`
  passed; full `make test` passed.
