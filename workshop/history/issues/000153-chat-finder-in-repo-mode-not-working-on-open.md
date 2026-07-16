---
id: 000153
status: done
deps: []
created: 2026-06-29
updated: 2026-06-29
estimate_hours: 0.5
started: 2026-06-29T14:05:38-07:00
actual_hours: 0.56
---

# chat finder in repo mode not working on open

default search is scoped to {repo} which matches nothing. I think it might be a regression where {repo} should be used in the chat file name if it's in the repo. 

## Done when

- ChatFinder in plain repo mode opens with a default query that matches repo-local chats.
- The fix is pinned by a unit regression.
- Existing ChatFinder logic tests pass.

## Spec

In plain repo mode, ChatFinder should default to the primary chat root filter that
the scanner already indexes for primary-root entries: `{}`. This preserves the
existing primary-root search convention and avoids changing root-label indexing
for extra roots (`ARCH-DRY`, `ARCH-PURE`). Super-repo mode should continue to
leave the sticky query unset so sibling aggregation is not narrowed by default
(`ARCH-PURPOSE`).

The default should still be applied only once per Parley session, and only when
the user has not already set a sticky finder query.

## Estimate

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: lua-neovim design=0.1 impl=0.2
item: milestone-review design=0.0 impl=0.2
design-buffer: 0.0
total: 0.5
```

## Plan

- [x] Update the repo-mode default sticky query test to expect `{}`.
- [x] Change `default_sticky_query_for_repo_mode()` to return `{}` in plain repo mode.
- [x] Run the focused ChatFinder unit spec and lint if available.

## Log

### 2026-06-29
- 2026-06-29: closed — focused ChatFinder spec red/green passed; make lint passed; full make test passed; no atlas change because this only aligns a default query token with existing primary-root indexing; review verdict: SHIP
- Claimed the issue and ran `sdlc start-plan`. Root cause: repo-mode default
  seeded `{repo}`, but primary-root ChatFinder entries are indexed with `{}`,
  so the first-open query filtered out the repo chats it meant to show. Chose the
  smaller fix of aligning the default query to the existing primary-root token.
- Red/green verification: the focused ChatFinder spec failed when the expectation
  changed to `{}` while the helper still returned `{repo}`, then passed after the
  helper change. Also ran `make lint` and full `make test`; both passed.
