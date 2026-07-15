# Boundary Review — 000188-wrap-facet-bar-lines#188 (whole-issue close)

| field | value |
|-------|-------|
| issue | 188 — wrap facet bar across multiple lines |
| repo | parley.nvim |
| boundary | whole-issue close |
| window | 1358ed355063e62658e40aef45226228e999456d..f88b0e9 |
| reviewer | codex |
| timestamp | 2026-07-15T11:24:43-07:00 |
| verdict | REWORK |

## Findings

- Critical (`ARCH-PURPOSE`): `facet_bar_layout` measured every fragment from
  display column zero. Tabs have contextual display width, so a tab-containing
  facet rendered through cell 18 while its semantic span extended through cell
  21, making blank cells clickable and defeating maximal packing.
- Important: the new mouse-wheel interaction for vertically capped facet bars
  was absent from the README.

## Resolution

- Added pure and production-adapter RED regressions for tab-sensitive packing,
  span endpoints, and blank-cell misses.
- Made the injected width operation accept the fragment's starting display cell
  and used it for whole-button fit, split packing, and semantic span endpoints.
- Documented mouse-wheel access to wrapped facet rows in the README.

## Verification

- `make test-spec SPEC=ui/pickers`: 10 mapped files, 247 tests, 0 failures/errors.
- `make test JOBS=1`: exit 0; all unit, architecture, and integration files pass;
  Luacheck reports 0 warnings/errors in 273 files.
- `git diff --check`, `sdlc issue validate --issue 188`, and duplicate-aware
  traceability key/list/path audits pass.

The full raw reviewer transcript was compacted per `workshop/lessons.md`; this
durable record preserves the verdict, actionable findings, resolutions, and
verification without feeding the prompt and full diff into the re-review.
