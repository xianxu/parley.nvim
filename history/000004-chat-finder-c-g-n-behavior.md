---
id: 000004
status: done
deps: []
created: 2026-03-28
updated: 2026-03-28
---

# chat finder <C-g>n behavior

<C-g>n should cycle through question header and branch points.

## Done when

- `<C-g>n` cycles through both `💬:` question headers and `🌿:` branch points

## Plan

- [x] Modify `search_chat_sections()` in `init.lua` to match both `chat_user_prefix` and `chat_branch_prefix`
- [x] Verify lint and tests pass

## Log

### 2026-03-28

- Changed `search_chat_sections()` to use vim regex alternation: `/^💬:\|^🌿:` so `<C-g>n` (and subsequent `n`/`N`) cycles through both question headers and branch points.
- Lint clean (1 pre-existing warning in outline.lua), all tests pass.
