# Boundary Review — parley.nvim#168 (whole-issue close)

| field | value |
|-------|-------|
| issue | 168 — buffer undo operation during chat generation resulted in a huge error message |
| repo | parley.nvim |
| boundary | whole-issue close |
| window | `3ca5e5824d29d7ac96176fb5e30208fe39af9fac..HEAD` |
| command | `sdlc close --issue 168` |
| reviewer | codex |
| timestamp | 2026-07-14 |
| verdict | FIX-THEN-SHIP |

## Summary

The reviewer found the buffer-scoped ownership design, synchronous cancellation
ordering, structural-lease fallback, bounded messaging, and documentation sound.
There were no Critical findings. The boundary required acceptance coverage and
one transport-failure path to be completed before shipping.

## Important findings and resolutions

1. `tasker.stop_buf` removed scoped handle records but suppressed a failed OS
   signal, so the protected history transaction could report success.
   - Resolution: the shared partition completes cleanup and returns a failure
     bit; the scoped wrapper raises a fixed sanitized error after partitioning.
     A failing-kill integration test proves the target record is retired, the
     unrelated record remains, and failure reaches the caller.
2. Production mapping coverage did not prove counted inactive redo, counted
   confirmed undo/redo, exact resulting history, mutation-before-retirement,
   dismissal, or bounded multibyte agent naming.
   - Resolution: production-path tests now drive each mapping with counts,
     compare exact transcript states, observe the mutated state from inside the
     retirement boundary, and cover dismissal plus a long multibyte label.
3. The durable implementation plan remained unchecked after delivery.
   - Resolution: completed steps through documentation and acceptance evidence
     are checked; close/review artifact steps remain open until the successful
     re-close.

## Minor finding and resolution

The module comment described all of `chat_history` as pure even though its
confirmation adapter calls Neovim. The comment now identifies the module as
policy plus a thin confirmation adapter; deterministic policy functions remain
unit-tested separately.

## Architecture

- `ARCH-DRY`: pass — pending identity has one registry owner and filtered stop
  logic is shared.
- `ARCH-PURE`: pass — deterministic prompt/decision policy remains separated
  from Neovim glue.
- `ARCH-PURPOSE`: addressed — the expanded production matrix enforces counted
  standard-key behavior and the synchronous retirement boundary.

## Verification

- Focused RED/GREEN evidence: failing transport signal test was red before the
  sanitized propagation change; tasker suite then passed 32 tests.
- Expanded `chat_respond` production suite passed 59 tests.
- `make test-spec SPEC=chat/lifecycle` passed after all resolutions.
- Full `make test` passed after all resolutions, including Luacheck with zero
  warnings/errors and every unit, architecture, and integration spec.
