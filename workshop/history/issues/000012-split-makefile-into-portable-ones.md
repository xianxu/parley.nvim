---
id: 000012
status: done
deps: []
created: 2026-03-28
updated: 2026-03-28
---

# split Makefile into portable ones

Split the single Makefile into

1. One for openshell
2. One for common agentic workflow
3. One specific for Parley/lua/nvim

## Done when

- Makefile is a thin assembler of three sub-files
- `make help` prints combined help from all three
- All existing targets still work

## Plan

- [x] Add help-workflow target to Makefile.workflow with its own help text
- [x] Add help-sandbox target to .openshell/Makefile with its own help text
- [x] Extract parley-specific targets (test, lint, fixtures, etc.) into Makefile.parley with help-parley target
- [x] Slim main Makefile to just include the three sub-files and define `help` as assembly
- [x] Verify `make help` prints all sections and `make test` still resolves

## Log

### 2026-03-28

- Split help text first: each sub-Makefile got its own `help-*` target, main `help` calls all three as prerequisites
- Then extracted parley-specific targets (test env, test, test-spec, test-changed, lint, fixtures, model-check) into `Makefile.parley`
- Main Makefile reduced to 7 lines: three includes + help target
- `.openshell/Makefile` uses `-include` (optional — sandbox not required for core dev), others use `include` (always expected)
