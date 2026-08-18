---
id: 000199
status: working
deps: []
github_issue:
created: 2026-08-18
updated: 2026-08-18
estimate_hours:
started: 2026-08-18T15:21:36-07:00
---

# Restore chat setup after buffer reopen

## Problem

Deleting a prepared chat buffer with `:bdelete` unloads it and removes its
buffer-local keymaps. Opening the same document again through Chat Finder
resurrects the same buffer handle, but `M._prepared_bufs[buf]` still says the
buffer is prepared. `prep_chat` therefore returns before reinstalling chat
setup, leaving visual `<M-CR>`, visual `<C-g><C-g>`, and the other buffer-local
chat behavior unavailable until Neovim restarts.

## Spec

- Treat `BufUnload`/`BufDelete` as the end of a chat buffer's prepared
  lifecycle. The existing synchronous teardown must invalidate
  `M._prepared_bufs[buf]` alongside the other buffer-keyed state so a later
  `BufEnter` can prepare a resurrected handle again (ARCH-DRY).
- Keep `prep_chat`'s idempotence guard for repeated `BufEnter` events while a
  buffer remains loaded; do not rerun all chat setup on every entry.
- Cover the production path with an integration regression: prepare a real
  chat, verify its visual mappings, `:bdelete` it, reopen it through
  `open_buf(..., true)` as Chat Finder does, verify Neovim reused the handle,
  and verify both visual `<M-CR>` and `<C-g><C-g>` were restored.
- No external service or binary is involved (ARCH-MOCK); this is a thin Neovim
  lifecycle fix with no new pure entity or public interface (ARCH-PURE).

## Done when

- A chat reopened after `:bdelete` regains visual `<M-CR>` definition lookup.
- The same reopened chat regains visual `<C-g><C-g>` response submission.
- The regression test fails without the lifecycle invalidation and passes with
  it.
- Relevant integration tests and repository lint pass.

## Plan

- [ ] Add an integration test that reproduces prepare → `:bdelete` →
      finder-style reopen and asserts the chat mappings are restored.
- [ ] Run the focused test and confirm it fails because the prepared marker
      survives teardown.
- [ ] Clear the prepared marker in the existing synchronous buffer teardown.
- [ ] Run focused and broader verification, then update the issue log and atlas
      only if the architectural map needs a behavior change.

## Log

### 2026-08-18

- Reproduced against the production `open_buf(path, true)` path: Neovim reused
  buffer handle 1; `_prepared_bufs[1]` remained true; visual `<M-CR>` and
  `<C-g><C-g>` changed from present before `:bdelete` to absent after reopen.
  Root cause is incomplete teardown of buffer-keyed preparation state
  (ARCH-PURPOSE).
