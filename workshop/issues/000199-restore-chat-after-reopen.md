---
id: 000199
status: working
deps: []
github_issue:
created: 2026-08-18
updated: 2026-08-18
estimate_hours: 1.13
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

- Treat `BufDelete` as the end of a chat buffer's prepared lifecycle. The
  synchronous classification teardown in `highlighter.setup_buf_handler` must
  invalidate `M._prepared_bufs[buf]` alongside `_parley_bufs[buf]`, because both
  are buffer-keyed inputs to that handler's `BufEnter` classification/setup
  path (ARCH-DRY). Do not clear the marker for standalone `BufUnload`: Neovim
  preserves buffer-local mappings across `:bunload`, while `:bdelete` removes
  them.
- Keep `prep_chat`'s idempotence guard for repeated `BufEnter` events while a
  buffer remains loaded; do not rerun all chat setup on every entry.
- Cover the production path with an integration regression: prepare a real
  chat, verify its visual mappings are present, `:bdelete` it, reopen it through
  `open_buf(..., true)` as Chat Finder does, verify Neovim reused the handle,
  and verify both visual `<M-CR>` and `<C-g><C-g>` mappings were restored. The
  test need not invoke network-backed callbacks; mapping presence proves that
  `prep_chat` reran after the lifecycle transition.
- Cover the neighboring negative case: standalone `:bunload` must retain the
  prepared marker and its buffer-local mapping across reopen, proving teardown
  distinguishes `BufUnload` from `BufDelete` and does not redundantly prepare
  an already-prepared handle (ARCH-PURPOSE).
- No external service or binary is involved (ARCH-MOCK); this is a thin Neovim
  lifecycle fix with no new pure entity or public interface (ARCH-PURE).

## Done when

- A chat reopened after `:bdelete` regains visual `<M-CR>` definition lookup.
- The same reopened chat regains visual `<C-g><C-g>` response submission.
- The regression test fails without the lifecycle invalidation and passes with
  it.
- Standalone `:bunload` retains the prepared marker and mapping.
- Relevant integration tests and repository lint pass.

## Estimate

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec design=0.5 impl=0.04
item: lua-neovim design=0.2 impl=0.2
item: milestone-review design=0.0 impl=0.08
design-buffer: 0.15
total: 1.13
```

Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md`
against `baseline-v3.1.md`. Method A only. The reviewed spec resolves the
lifecycle decision, so the Lua design component uses the high-spec discount;
implementation values use v3.1's 40% ship-wall-clock scaling.

## Plan

- [ ] Add an integration test that reproduces prepare → `:bdelete` →
      finder-style reopen and asserts the chat mappings are restored.
- [ ] Add the adjacent `:bunload` regression asserting the preparation marker
      is retained and the mapping remains present after reopen.
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
- Checked standalone `:bunload`: Neovim reused the same handle and retained the
  visual mapping. Scope is therefore specifically `BufDelete`; clearing on
  `BufUnload` would cause unnecessary repeated setup.
