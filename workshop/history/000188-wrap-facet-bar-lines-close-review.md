# Boundary Review — 000188-wrap-facet-bar-lines#188 (whole-issue close)

## Initial review

| field | value |
|-------|-------|
| window | `1358ed3..f88b0e9` |
| reviewer | codex |
| timestamp | 2026-07-15T11:24:43-07:00 |
| verdict | REWORK |

### Findings

- Critical (`ARCH-PURPOSE`): tab-containing facet labels rendered through cell
  18 while their semantic spans extended through cell 21 because fragment width
  was always measured from column zero. This made blank cells clickable and
  defeated maximal packing.
- Important: README omitted mouse-wheel access to vertically capped facet rows.

### Resolution and evidence

- Added pure and production-adapter RED regressions for contextual tab packing,
  span endpoints, and blank-cell misses; made the injected width operation
  start-cell-aware throughout fit, split, and span calculations.
- Documented wrapped-bar wheel scrolling in README.
- `make test-spec SPEC=ui/pickers`: 10 mapped files, 247 tests, 0 failures/errors.
- `make test JOBS=1`: exit 0; all unit, architecture, and integration files pass;
  Luacheck reports 0 warnings/errors in 273 files.
- Diff, issue-schema, and duplicate-aware traceability audits pass.

## Re-review

| field | value |
|-------|-------|
| window | `1358ed3..fe548b9` |
| reviewer | codex |
| timestamp | 2026-07-15T11:34:10-07:00 |
| verdict | FIX-THEN-SHIP |

### Assessment

- No code, test, atlas, or README defect remained. `ARCH-DRY`, `ARCH-PURE`, and
  `ARCH-PURPOSE` all passed.
- Important bookkeeping finding: the prior revision's historical unchecked
  state appeared to contradict the checked close/retry rows. The appended plan
  revision now distinguishes the post-REWORK interval from the successful
  retry; the gate finalized issue #188 as `codecomplete`.

The generated raw transcripts were compacted per `workshop/lessons.md`; this
record retains verdicts, findings, resolutions, and verification without
feeding prompts and full diffs into later review windows.
