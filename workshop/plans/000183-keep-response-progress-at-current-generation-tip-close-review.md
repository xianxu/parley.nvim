# Boundary Review — #183 whole-issue close

| field | value |
|-------|-------|
| issue | 183 — Keep response progress at current generation tip |
| boundary | whole-issue close |
| window | `e3ed1e0..8919fe1` |
| reviewer | codex, fresh context |
| date | 2026-07-13 |
| final verdict | FIX-THEN-SHIP |

## First review — REWORK

The reviewer found that `tip_written` could revive a progress extmark that had
already been invalidated externally before the stream write. The adapter could
not distinguish that stale state from the expected invalidation caused by
replacing the mutable pending line.

Resolution: the stream callback now validates the visible mark immediately
before mutation and grants a one-use repair authorization. Validation, write,
and relocation remain synchronous in that callback, so only the immediately
following writer-caused invalidation can restore the same extmark ID. A
real-buffer regression proves that pre-existing external invalidation terminates
the session and suppresses the queued write.

## Second review — FIX-THEN-SHIP

The reviewer confirmed the corrected code, architecture, and tests. The only
Important finding was that the generated review sidecar contained a raw,
18,000-line terminal transcript with ANSI escapes and trailing whitespace,
which made the review artifact itself fail `git diff --check`.

Resolution: the raw transcript was replaced by this concise durable record of
the verdicts, actionable finding, fix, and evidence.

## Verification evidence

- `make -f Makefile.local test-spec SPEC=chat/response_progress`
- `make -f Makefile.local test-spec SPEC=chat/exchange_model`
- `make -f Makefile.local test JOBS=1` — lint clean; all unit, architecture,
  and integration specs passed
- `git diff --check`
