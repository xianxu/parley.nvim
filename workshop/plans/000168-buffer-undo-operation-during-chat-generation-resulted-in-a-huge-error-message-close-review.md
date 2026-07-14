# Boundary Review — parley.nvim#168 (whole-issue close)

| field | value |
|-------|-------|
| issue | 168 — buffer undo operation during chat generation resulted in a huge error message |
| repo | parley.nvim |
| boundary | whole-issue close |
| window | `3ca5e5824d29d7ac96176fb5e30208fe39af9fac..HEAD` |
| command | `sdlc close --issue 168` |
| reviewer | codex |
| latest verdict | REWORK |

## Validated strengths

The reviews consistently validated buffer-scoped ownership, synchronous
stop/history/retire ordering, immutable identity snapshots, structural-lease
fallback, bounded user messaging, two-buffer isolation, and the README/atlas
updates. No concern was raised about the chosen interaction or scope.

## Review rounds and resolutions

### Round 1 — FIX-THEN-SHIP

1. Scoped handle records were removed while thrown signal failures were
   suppressed.
   - Resolution: partitioning now records failure and the scoped wrapper raises
     a fixed sanitized error after cleanup; a throwing-kill regression passes.
2. Production mapping coverage did not yet prove counted inactive redo,
   counted confirmed undo/redo, exact history results, mutation before
   retirement, dismissal, or bounded multibyte agent naming.
   - Resolution: production tests now cover the complete matrix and observe
     the mutated transcript from inside the retirement boundary.
3. The durable implementation checklist remained unchecked.
   - Resolution: delivered steps through documentation and acceptance evidence
     are reconciled; final close-artifact steps remain open until SHIP.
4. The module comment called the entire history module pure despite its thin
   Neovim confirmation adapter.
   - Resolution: the comment now distinguishes policy from the adapter.

### Round 2 — REWORK

1. Real `vim.uv.kill` failures are normally returned as
   `nil, message, code`, not thrown. The first regression therefore did not
   model `EPERM`/`ESRCH`, and return-shaped failures still looked successful.
   - Resolution: scoped stopping checks both protected-call success and the
     libuv success result. A non-throwing `EPERM` regression proves failure is
     propagated after owned records are partitioned; tasker now passes 33
     focused tests.
2. `PendingIdentity` was listed as PURE even though identity lookup reads the
   mutable pending-session registry and is tested through Neovim integration.
   - Resolution: the durable plan now classifies it as an INTEGRATION snapshot
     API wrapping the mutable registry (`ARCH-PURE`).

## Architecture

- `ARCH-DRY`: pass — pending identity has one registry owner and filtered stop
  logic is shared.
- `ARCH-PURE`: addressed — deterministic history policy is pure; pending
  identity is explicitly an integration snapshot.
- `ARCH-PURPOSE`: addressed — counted standard keys, synchronous retirement,
  fallback safety, and both thrown/return-shaped signal failures are enforced.

## Verification after latest resolutions

- Focused tasker RED/GREEN: the non-throwing `EPERM` case failed before the
  result check, then all 33 tasker integration tests passed.
- Production `chat_respond` suite: 59 tests passed.
- `make test-spec SPEC=chat/lifecycle`: passed.
- Full `make test`: passed, including zero lint errors and every unit,
  architecture, and integration spec.
- Final SHIP verdict is pending the next SDLC re-close review.
