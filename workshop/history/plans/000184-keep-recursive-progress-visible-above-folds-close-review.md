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
verdict: SHIP
confidence: high
```

The change fulfills issue #184 with a minimal spatial fix: recursive progress anchors to the model-derived separator outside Parley-generated folds, while existing temporal and writer-relocation behavior remains intact. No findings remain.

## Strengths

- Anchor and insertion share the canonical stream-block position; no fold-state query or duplicate scan was introduced.
- The production-path regression drives two recursive tool rounds and checks the waiting third leg outside all four generated folds.
- Terminal cases cover cancellation cleanup, partial-output-before-error ordering, fold stability, and exactly-once staged release.
- The response-progress atlas accurately describes the placement contract; no README change is required because no user-invoked surface changed.

## Verified by reviewer

- `make test-spec SPEC=chat/response_progress`
- `make test-spec SPEC=chat/exchange_model`
- `make lint` — zero warnings/errors across 265 files
- `git diff --check 4286ac3..HEAD`

Architecture: `ARCH-DRY`, `ARCH-PURE`, and `ARCH-PURPOSE` passed.
