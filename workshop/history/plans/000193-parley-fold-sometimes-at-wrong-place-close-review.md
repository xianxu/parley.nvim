# Boundary Review — parley.nvim#193 (whole-issue close)

| field | value |
|-------|-------|
| issue | 193 — parley fold sometimes at wrong place |
| repo | parley.nvim |
| boundary | whole-issue close |
| window | 85eed67fe928c504a745283cadc0eef64359d1c8..e4cb97b |
| reviewer | codex |
| timestamp | 2026-07-17T09:48:47-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: medium
```

The diff satisfies issue #193's Spec and Plan: semantic answer structure is
single-sourced, streaming reconciliation is bounded to the active insertion or
provisional span, and fold mutation is limited to model-derived foldable blocks.
No Critical, Important, or Minor findings were reported.

### Validated strengths

- `answer_structure.reduce` centralizes semantic answer segmentation and removes
  the parallel raw-marker folding grammar.
- Streaming reconciliation reads the insertion block, widening only to a
  recorded provisional thinking opener for a late explicit terminator.
- The Neovim fold adapter returns before mutation for non-foldable blocks and
  recreates only the active semantic range.
- Atlas parsing, exchange-model, and lifecycle documentation matches the code.

### Independent review evidence

- `tests/unit/answer_structure_spec.lua`: 4/4 passed.
- `tests/unit/exchange_model_spec.lua`: 25/25 passed.
- `tests/unit/tool_folds_spec.lua`: 1/1 passed.
- `tests/integration/tool_folds_spec.lua`: 4/4 passed.
- `git diff --check 85eed67..e4cb97b`: passed.

### Architecture

- `ARCH-DRY`: pass — semantic parsing derives from one reducer.
- `ARCH-PURE`: pass — reducer/model logic is pure; buffer and fold operations
  remain at the Neovim boundary.
- `ARCH-PURPOSE`: pass — streaming, initial load, tool, and terminal paths no
  longer rely on a final whole-chat corrective fold pass.

No plan revisions were recommended.
