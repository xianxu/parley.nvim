---
id: 000096
status: wontfix
deps: [000090]
created: 2026-04-10
closed: 2026-04-12
---

# Migrate remaining nvim_buf_set_lines callers to buffer_edit

## Summary

The #90 arch test allows several UI/picker modules to still call `nvim_buf_set_lines` directly. Migrate them to `buffer_edit` for consistency, then tighten the arch test allow list.

## Resolution: wontfix

Closed after analysis showed this migration adds no value:

1. **Non-chat buffer callers** (pickers, config display, issue YAML, float windows) operate on scratch buffers with no concurrent mutation. Wrapping `nvim_buf_set_lines` in `buffer_edit` is indirection for indirection's sake.

2. **`buffer_edit.lua` itself is mostly unnecessary.** The exchange model is the real source of truth for chat buffer positions — it tracks sizes and computes positions on demand. Once you have a position from the model, `nvim_buf_set_lines` is trivial. `buffer_edit`'s named wrappers (`replace_line_at`, `insert_lines_at`, etc.) are 1-line functions that add no safety or correctness.

3. **The only valuable piece is PosHandle** (extmark-backed streaming position), used exclusively by `chat_respond.lua`. This could be inlined into `chat_respond.lua` and `buffer_edit.lua` deleted entirely — tracked as a future simplification.

## Follow-up consideration

- Collapse PosHandle into `chat_respond.lua` and delete `buffer_edit.lua`
- Simplify the arch test to only guard the meaningful invariant: chat buffer mutations in the response pipeline use the exchange model for position computation

## Log

- **2026-04-10 — filed** from #90 follow-up.
- **2026-04-12 — wontfix** after analysis: wrapping non-chat scratch buffer writes adds no value; buffer_edit itself is mostly unnecessary given exchange_model is the real source of truth.
