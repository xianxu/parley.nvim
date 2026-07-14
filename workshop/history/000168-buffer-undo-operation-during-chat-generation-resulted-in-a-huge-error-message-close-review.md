# Boundary Review — parley.nvim#168 (whole-issue close)

| field | value |
|-------|-------|
| issue | 168 — buffer undo operation during chat generation resulted in a huge error message |
| repo | parley.nvim |
| boundary | whole-issue close |
| window | `3ca5e5824d29d7ac96176fb5e30208fe39af9fac..HEAD` |
| command | `sdlc close --issue 168` |
| reviewer | codex |
| final verdict | SHIP |
| confidence | high |

## Validated strengths

The reviews validated buffer-scoped ownership, synchronous
stop/history/retire ordering, immutable identity snapshots, structural-lease
fallback, bounded user messaging, two-buffer isolation, and the README/atlas
updates. The final review found the implementation fulfills the issue Spec and
Plan with no Critical, Important, or Minor findings.

## Review rounds and resolutions

### Round 1 — FIX-THEN-SHIP

1. Scoped records were removed while thrown signal failures were suppressed.
   - Resolved by propagating a sanitized failure after deterministic cleanup
     and adding a throwing-kill regression.
2. Production mapping coverage did not yet prove the complete counted-history
   and synchronous-retirement acceptance matrix.
   - Resolved with counted inactive/confirmed undo and redo, exact transcript
     assertions, mutation observed inside retirement, dismissal, and bounded
     multibyte agent-label coverage.
3. The durable implementation checklist remained unchecked.
   - Resolved by reconciling every delivered plan step.
4. The history module comment overstated the purity boundary.
   - Resolved by distinguishing deterministic policy from its thin Neovim
     confirmation adapter.

### Round 2 — REWORK

1. Real `vim.uv.kill` failures use a `nil, message, code` return rather than an
   exception, so return-shaped `EPERM`/`ESRCH` failures still looked successful.
   - Resolved by checking the libuv success result inside the protected call;
     a non-throwing `EPERM` regression proves failure propagation after scoped
     cleanup.
2. `PendingIdentity` was listed as PURE despite reading the mutable registry.
   - Resolved by classifying it as an INTEGRATION snapshot API wrapping the
     pending-session registry (`ARCH-PURE`).

### Round 3 — SHIP

The reviewer confirmed guarded undo/redo preserves counts, defaults to No,
cancels only the current buffer, mutates history before synchronous retirement,
and retains the structural-lease fallback. No findings remained.

## Architecture

- `ARCH-DRY`: pass — filtered transport stopping and pending identity each have
  one source of truth.
- `ARCH-PURE`: pass — deterministic policy is separated from thin Neovim and
  lifecycle adapters; integration entities are classified accurately.
- `ARCH-PURPOSE`: pass — counted keys, synchronous retirement, buffer
  isolation, signal-failure handling, and lease fallback are all delivered.

## Verification

- Focused tasker RED/GREEN covered thrown and non-throwing libuv signal
  failures; all 33 tasker integration tests passed.
- Production `chat_respond` suite passed 59 tests.
- `make test-spec SPEC=chat/lifecycle` passed.
- Full `make test` passed, including zero lint errors and every unit,
  architecture, and integration spec.
- `git diff --check` passed before close.
