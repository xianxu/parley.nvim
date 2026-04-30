---
id: 000114
status: working
deps: []
created: 2026-04-29
updated: 2026-04-30
---

# super repo mode allow repo as sticky search term

In super repo mode, we prefix repo names like {brain}, {charon} to each item. but it seems

1/ search on {charon} is not sticky, e.g. next invocation of the finder default search that term
2/ search behavior also a bit strange, {char doesn't match any, but {charon} matched correctly
3/ take a look at the several finders, and their should be some uniformity on how to search, sticky behavior, particularly in the

## Done when

- Typing `{char` (incomplete bracket) filters by repo `charon` the same way `{charon}` does
- `{repo}` filter is preserved (sticky) across reopens of every super-repo-aware finder: chat, note, issue, vision, markdown
- Sticky helpers live in one place; no per-finder copies
- Markdown finder switches from `<repo>/<rel>` to `{repo} <rel>` so the same `{repo}` filter convention applies
- Unit tests cover incomplete-bracket matching and sticky extraction

## Spec

### Bug 1 — incomplete bracket fails to match

`float_picker.lua::tokenize_query` only treats `^%b{}$` (closed) tokens as `kind="root"`. An incomplete `{char` becomes `kind="plain"` text=`"{char"`. `tokenize_haystack` strips `{` (not a word char). The whole-haystack subsequence fallback only fires when query length ≤ 3, so `{char` (length 5) gets nothing.

Fix: in `tokenize_query`, treat `{xxx` (no closing `}`) as `kind="root"`, text=`xxx`; same for `[xxx`. The existing prefix-match path handles the rest.

### Bug 2 — sticky query missing for some finders

Today:
- chat_finder: extracts `{root}` and `[tag]` (only complete forms)
- note_finder: extracts `{root}` only (only complete forms)
- issue_finder, vision_finder, markdown_finder: no sticky_query at all

Fix: extract a single `finder_sticky` module with helpers that preserve both completed (`{xxx}`) and in-progress (`{xxx`) fragments, then wire it into all 5 finders. Add `sticky_query = nil` to the state tables for issue / vision / markdown.

### Convention 3 — markdown finder uses `{repo}` prefix

Today markdown_finder displays `<repo>/<rel>` and tags entries by repo name into the tag bar. To make `{repo}` filtering uniform, switch the display to `{<repo>} <rel>` (matching the other finders) and keep the tag bar — the tag bar still works as a per-category quick toggle, the `{repo}` filter still works as a sticky text filter.

Note: outside super-repo (single repo, no per-file repo prefix), nothing changes.

## Plan

- [ ] M1 — `tokenize_query` accepts incomplete `{xxx` / `[xxx` as in-progress root/tag tokens
- [ ] M1 — unit test: `_fuzzy_score("{char", "{charon} foo") > 0` and `tokenize_query("{char")` returns `{kind="root", text="char"}`
- [ ] M2 — new `lua/parley/finder_sticky.lua` with `extract(query, kinds)` (kinds = `{ "root", "tag" }` or `{ "root" }`) and `format_initial_query(sticky)`
- [ ] M2 — chat_finder + note_finder switch to `finder_sticky`; remove local copies
- [ ] M2 — sticky extraction also keeps in-progress `{xxx` / `[xxx` fragments
- [ ] M2 — unit tests for sticky extraction (complete + in-progress, root + tag)
- [ ] M3 — wire sticky_query into `issue_finder` (root only), `vision_finder` (root only); add `sticky_query = nil` to their `_*_finder` state tables in init.lua
- [ ] M4 — `markdown_finder` switches `<repo>/<rel>` → `{<repo>} <rel>` display & matching `search_text`; wire sticky_query (root only); update `_markdown_finder` state
- [ ] M5 — update `atlas/modes/super_repo.md` and `atlas/ui/pickers.md` to reflect the new uniform convention
- [ ] M6 — run `make test` and `make lint`, manual smoke test on a workspace with two `.parley` siblings

## Log

### 2026-04-29

Issue created.

### 2026-04-30

Investigated. Root cause for bug 2 (`{char` no match) confirmed in `float_picker.tokenize_query`. Sticky query: chat_finder + note_finder have it, issue/vision/markdown don't. User confirmed scope: pull markdown_finder under `{repo}` convention.
