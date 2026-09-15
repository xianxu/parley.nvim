# Boundary Review — parley.nvim#241 (whole-issue close)

| field | value |
|-------|-------|
| issue | 241 — Chat outline shows only the last inline branch on a line: the tree builder keys branches by line number, so a second [🌿:…](…) on the same line overwrites the first |
| repo | parley.nvim |
| issue file | workshop/issues/000241-outline-drops-earlier-inline-branches-on-same-line.md |
| boundary | whole-issue close |
| milestone | — |
| window | e7b4f48c4c0b9df6c9026ff8800c9d7611ce0f22..f679f7aec666a0c9990a0d15ac8941f48dcbefba |
| command | sdlc close --issue 241 |
| reviewer | codex |
| timestamp | 2026-09-14T18:22:00-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The pinned change fulfills #241’s revised Spec and Plan: same-line branches retain parser order, each receives its existing subtree handling, and child navigation stays intact. No blocking findings. Repository files were left unchanged.

### 1. Strengths

- `lua/parley/outline.lua:254` replaces the lossy map value with an ordered array while reusing the existing renderer and resolver.
- `tests/unit/outline_parity_spec.lua:146` verifies exact row order, child attribution, mixed branch forms, and independent expansion.
- `atlas/ui/outline.md:31` accurately documents the behavior. No new command, binding, or configuration requires a README update.

### 2. Critical findings

None.

### 3. Important findings

None.

### 4. Minor findings

None.

### 5. Test coverage

Verified in an isolated archive of the pinned head:

- Outline suite: **190 passed**, zero failures or errors.
- Regression check: replacing only `outline.lua` with the base version makes all four same-line cases fail; mixed-form cases remain green.
- Restoring head returns the suite to green.
- Lint: zero warnings/errors across 451 files.
- Pinned diff whitespace check passed.

### 6. Architecture

- **ARCH-DRY — pass:** reuses parser order, resolver, rendering, and recursion.
- **ARCH-PURE — pass:** small grouping change within the existing file-reading boundary; no additional IO coupling.
- **ARCH-PURPOSE — pass:** preserves every parsed branch, including independent child expansion.
- **ARCH-MOCK — pass:** no new external dependency; integration tests use isolated real files.
- **ARCH-CONSTRAINTS — pass:** linear grouping; existing per-branch resolution and recursion remain unchanged.
- **ARCH-SECURE — pass:** existing path-resolution boundary retained; synthetic fixtures isolate test writes.
- **ARCH-ORDER — pass:** synchronous projection introduces no state between events; ordered iteration preserves document order.
- **ARCH-FUNERAL — pass:** arrays expire with the invocation; new fixture directories have teardown cleanup.

### 7. Plan revision recommendations

None. The existing revision explicitly preserves #250’s child-file navigation contract.

```findings
{}
```
