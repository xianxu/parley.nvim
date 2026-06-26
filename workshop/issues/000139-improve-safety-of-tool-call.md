---
id: 000139
status: done
deps: []
created: 2026-06-25
updated: 2026-06-26
started: 2026-06-25T22:56:23-07:00
estimate_hours: 2
actual_hours: 2
---

# improve safety of tool call

for example, ls call may return 1M files under a directory, we should have some upper limit, by doing some summarization, maybe when there are too many files, for each directory we should three files, then a ... on the next line. LLM would understand it. we may well add one summary line at the end: there are 9999999 files, we only showed 100 examples. if you need more, pass this flag and do paging etc. 

makes sense? 

## Done when

- A tool returning huge output (e.g. `ls` over 1M files) is line-windowed, not a
  raw dump; a footer states the **true total** + how to page / narrow.
- Every read tool accepts `offset`/`limit` (a uniform output pager); `read_file`
  keeps its native paging (opts out of the dispatcher slice).
- Default page = 200 lines (configurable), max requestable = 2000; 100KB byte-cap
  stays as the backstop for pathological single lines.
- Covered by tests.

## Spec

Scoped to **output** safety (input/injection split to #144). Design (confirmed
with operator): a **horizontal output pager** at the dispatcher — *every tool's
output is a paged stream; pass `(offset, limit)` to page it.* `read_file`'s
`offset`/`limit` becomes the one tool that implements the contract natively
(efficient seek); the dispatcher implements it for the rest by slicing output.

- Pure `dispatcher.page_lines(content, offset, limit) → (text, start, end, total)`.
- `execute_call`: for a non-`self_paginates` tool, read `offset`(1-idx, default 1)
  / `limit`(default 200, clamp ≤ 2000) from input, **strip them** so the handler
  never sees them, run the handler, window the result, append a footer:
  `[lines 1–200 of 1,240,118 — pass offset=201 for the next page, or narrow your query]`.
  Keep the byte-cap backstop. Deep paging re-runs the tool (run+slice, no cache — v1).
- Registry `register()` injects `offset`/`limit` into every non-write, non-
  `self_paginates` tool's `input_schema` (horizontal; one place). The param
  descriptions + the footer self-advertise — no per-tool prose, no system-prompt edit.
- `read_file` sets `self_paginates = true` (its native `offset`/`limit` already
  fulfill the contract; dispatcher skips slicing it).
- Default page size configurable (`tool_result_page_lines = 200`), threaded via
  `tool_loop` + `skill_invoke` (same path as #140 `read_roots`).

Orthogonal to #144 (pure output-side, slices *after* the handler).

## Plan

- [x] `page_lines` pure helper + `execute_call` pager (strip in, window out, footer, byte backstop).
- [x] `read_file` `self_paginates = true` (+ allow the field in `types`).
- [x] Registry `register()` injects `offset`/`limit` into non-write, non-self-paginating schemas.
- [x] Config `tool_result_page_lines = 200`; thread via `tool_loop` + `skill_invoke`; clamp ≤ 2000.
- [x] Tests (`tools_dispatcher_spec` + registry): paging, offset/limit strip, self_paginates opt-out, footer, byte backstop.
- [x] Atlas (`providers/tool_use.md`): document the horizontal pager.
- [x] Verify: full `make test` (44/44 dispatcher; golden 7/7 re-captured; exit 0).

## Revisions

### 2026-06-26 — boundary review (FIX-THEN-SHIP) addressed
- ARCH-DRY + latent hazard: the dispatcher pager gate keyed on `not self_paginates`
  alone, so it also windowed **write** tools (the registry's injection gate already
  excluded `kind=="write"`) — two predicates for "is pageable." Harmless today (write
  results are single-line), but a multi-line write result would get a "re-run to page"
  footer whose remedy re-applies a destructive write. Extracted
  `types.is_pageable(def) = kind ~= "write" and not self_paginates`, now used by both
  `register()` and `execute_call`. Added a test asserting a write tool's >200-line
  output is not windowed (`tools_dispatcher_spec` 45/45).
- Return-signature note: `page_lines` returns `(text, total)`, not the Spec's
  `(text, start, end, total)` — start/end are encoded in the footer; callers/tests
  use two values. Spec line is illustrative; code is the contract.


- 2026-06-26: closed — tools_dispatcher_spec 44/44 (12 new #139: page_lines windowing/footer/edge cases, execute_call offset/limit strip + window, default + max(2000) clamp, self_paginates opt-out, registry injection skips write/self-paginating); full make test green (exit 0); golden 7/7 re-captured — structural diff confirmed the ONLY payload change is offset/limit added to ls/find/grep/chat_history_search schemas (read_file unchanged via self_paginates); luacheck clean. Horizontal pager: registry injects offset/limit, dispatcher windows non-self_paginates output + footer, byte-cap backstop. Orthogonal to #144. Atlas: tool_use.md Output pager bullet. Actual labeled — active-time found no window.; review verdict: FIX-THEN-SHIP
### 2026-06-25

