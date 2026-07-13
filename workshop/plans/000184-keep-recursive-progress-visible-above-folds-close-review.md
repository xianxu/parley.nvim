# Boundary Review — parley.nvim#184 (whole-issue close)

| field | value |
|-------|-------|
| issue | 184 — Keep recursive progress visible above folds |
| repo | parley.nvim |
| issue file | workshop/issues/000184-keep-recursive-progress-visible-above-folds.md |
| boundary | whole-issue close |
| milestone | — |
| window | 4286ac320a31b1fda61b6660a1155c4c22f72cc6..HEAD |
| command | sdlc close --issue 184 |
| reviewer | codex |
| timestamp | 2026-07-13T16:15:58-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The production fix and architecture passed review. One Important test-oracle gap remained: the post-minimum assertion proved staged output was present, but not that it flushed exactly once.

## Finding

- `tests/integration/chat_respond_spec.lua`: add an exact occurrence or transcript-line assertion for the staged final answer after release.

## Resolution

The regression now counts the final answer in the rendered transcript and requires exactly one occurrence. The mapped response-progress suite is rerun before re-review.

## Verified by reviewer

- `make test-spec SPEC=chat/response_progress`
- `make test-spec SPEC=chat/exchange_model`
- `make lint` — zero warnings/errors across 265 files
- `make test JOBS=1`
- `git diff --check 4286ac3..HEAD`

Architecture: `ARCH-DRY`, `ARCH-PURE`, and `ARCH-PURPOSE` passed. No README change is needed because no user-invoked surface changed.
