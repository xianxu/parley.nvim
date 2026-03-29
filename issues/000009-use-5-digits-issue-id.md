---
id: 000009
status: done
deps: []
created: 2026-03-28
updated: 2026-03-28
---

# use 5 digits issue id

currently we are using 4 digit id: 0001-issue-some.md. let's use 6 digits to have more head room. also update history folder of past issue files

## Done when

- New issues get 6-digit IDs
- Existing issues/history files renamed to 6-digit IDs
- ID parsing accepts any number of digits (forward-compatible)

## Plan

- [x] Update `issues.lua`: change `%04d` → `%06d`, `%d%d%d%d` → `%d+` pattern
- [x] Deps parsing already flexible — no change needed
- [x] Rename existing files in `issues/` and `history/` to 6-digit prefixes
- [x] Update `id:` frontmatter inside renamed files
- [x] `make lint` + `make test`

## Log

### 2026-03-28

