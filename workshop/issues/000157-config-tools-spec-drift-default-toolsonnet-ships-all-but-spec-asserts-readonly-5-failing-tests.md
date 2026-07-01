---
id: 000157
status: open
deps: []
github_issue:
created: 2026-07-01
updated: 2026-07-01
estimate_hours:
---

# config_tools_spec drift: default ToolSonnet ships @all but spec asserts @readonly (5 failing tests)

## Problem

`tests/unit/config_tools_spec.lua` fails **5 tests** deterministically (in
isolation and in the full suite). The shipped default config
(`lua/parley/config.lua:222,246`) sets both `ToolSonnet*` and `ToolSonnet` to
`tools = { "@all" }` with the comment *"Swap @readonly → @all to also allow
edit/write"* — an intentional config change — but `config_tools_spec.lua` was
never refit. It still asserts:

- `get_agent("ToolSonnet").tools == { "@readonly" }` (`:149`, `:198`),
- and, in the full wiring chain, that `edit_file` / `write_file` are **absent**
  (read-only agent) in the resolved payload (`:232`, `:258`).

With the current `@all` default these expectations are wrong, so the suite is red
on a point unrelated to the feature under test. Discovered while landing #155
(verified unrelated to it via `git stash` — #155 touches only message emission).

## Spec

Two coupled decisions:

1. **Product decision (the real question):** should the *default* tool-enabled
   agent ship `@all` (read + edit/write) or `@readonly`? Shipping a default agent
   with write access is a notable permission posture (relates to the
   capability/permission model, #129). The `config.lua` comment says `@all` is
   intentional — if so, confirm; if it was an over-broad default, revert to
   `@readonly`.
2. **Refit the test to match the decision:**
   - If default stays `@all`: update `config_tools_spec.lua` expectations
     (`@readonly` → `@all`; the wiring-chain tests should assert `edit_file` /
     `write_file` are **present**), and refresh any goldens
     (cf. commit `ee7fdec` which last refit these).
   - If reverted to `@readonly`: change `config.lua:228,251` back and the tests
     pass as-is.

Keep a dedicated test that pins whatever the intended default is (so the next
swap can't silently drift the suite again).

## Done when

- `make test` has zero failures from `config_tools_spec.lua`.
- The default `ToolSonnet`/`ToolSonnet*` `tools` value and the spec's assertions
  agree, and a test documents the intended default explicitly.
- If the default is `@all`: a one-line rationale in `config.lua` (or atlas) notes
  why the default tool agent ships write access.

## Plan

- [ ]

## Log

### 2026-07-01

Filed from #155's landing (close + plan judges both flagged it as a pre-existing,
out-of-scope failure worth its own issue). Root cause is config↔test drift, not a
#155 regression. Needs a product call on the default permission posture before the
mechanical test refit.
