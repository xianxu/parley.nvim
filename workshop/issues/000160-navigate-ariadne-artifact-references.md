---
id: 000160
status: working
deps: [ariadne#144]
github_issue:
created: 2026-07-03
updated: 2026-07-03
estimate_hours:
started: 2026-07-03T23:39:29-07:00
---

# navigate ariadne artifact references

## Problem

ariadne artifacts (issues, plans, review sidecars, targets) refer to each other
and across peer repos with **symbolic** refs — `ariadne#11`, `#15 M4`, `pair#84` —
but there's no fast way for a human in the editor to *jump* from a ref to the file
it names, especially across sibling repos. Navigation is manual (grep, guess the
path, `:e`).

This grew from **ariadne#144**, which originally framed the fix as files carrying
**stored cross-links** (e.g. `[ariadne#11](../ariadne/workshop/issues/000011-…md)`).
We rejected that premise: the issue *number* is immutable but the *path* is not —
slugs get renamed, and files move `issues/ → history/` on close/merge (ariadne#160
made that move happen on every merge). Stored links rot on archive. The fix is
**read-time resolution**.

The feature splits across two repos: **ariadne#144** is the resolver (`sdlc
resolve`, base-layer Go — reframed off the stored-link premise); **this issue** is
the parley editor UX that consumes it. `deps: [ariadne#144]`.

## Spec

**Keep the canonical ref symbolic; resolve the path on demand.** Agents already
write `ariadne#11` (the constitution mandates it and greps it). parley resolves it
to the current file location at navigation time — immune to renames, archiving,
and moves. Nothing is stored; nothing rots.

### Approach: `sdlc resolve` + parley UX

- **ariadne side (small dependency):** add a **read-only** `sdlc resolve <ref>` that
  maps a symbolic ref → the current file path(s), deriving artifact locations from
  the vocab/datatype models (the `discovery:` blocks — parley already sources the
  issue home from `issue.cue`, ariadne#116) rather than hardcoding. It also
  single-sources the **ref grammar** so parley and agents can't drift. Because it's
  read-only it takes **no git transaction lock** — so it avoids the lock-contention
  slowness of mutating verbs like `sdlc issue new`; cost is just Go process spawn
  (~10–40ms), imperceptible for keypress→jump.
- **parley side (this issue):** shell to `sdlc resolve` from Lua; **highlight**
  resolvable refs so they read as navigable (conceal/treesitter or regex); bind a
  keymap (`gf`-style) that resolves the ref under cursor and opens it. When a ref's
  id has a whole **family** (issue + `000160-*-plan.md` + `000160-*-m1-review.md`),
  offer a small picker — that is ariadne#144's original "interlink" ask, delivered
  as navigation (bidirectional, always current) instead of stored links.

### Ref grammar (single-sourced in ariadne; parley consumes)

- `repo#id` → that repo's workshop issue (`<parent>/<repo>/workshop/{issues,history}/<id>-*.md`).
- `repo#id Mx` → the issue + its milestone context (jump to the `Mx` row / review sidecar).
- Bare `#id` → the current repo.
- Disambiguate the GitHub inbox from the workshop tracker (sdlc already splits
  `--issue` vs `--github-issue`) — pick a form for GitHub refs (e.g. `repo gh#id`).
- Plans / review sidecars / targets resolve by the same 6-digit id.

### Why here, not in ariadne generating links (decided)

Read-time resolution is move-robust and stores nothing; write-time links store the
volatile path and rot on archive. The resolver *logic* lives in `sdlc resolve`
(single source, also usable by the CLI / agents — `sdlc open ariadne#11`), and
parley owns the editor affordance. Slower than a pure-Lua in-process resolver by a
process spawn, but single-source-of-truth is worth it (same call we made putting
the issue schema in `issue.cue`) — and read-only keeps it lock-free, so the spawn
is the only cost.

## Done when

- [ ] From a ref under the cursor (`ariadne#11`, `#15 M4`, `pair#84`), a keymap
      opens the current file for that artifact — correct across sibling repos and
      after the file has been archived (`issues/ → history/`).
- [ ] Resolvable refs are visually marked so they read as navigable.
- [ ] A ref with a family (issue + plan + reviews) offers a picker of the related files.
- [ ] Resolution derives artifact locations from the ariadne models (no hardcoded
      paths); grammar single-sourced in ariadne, not re-encoded in Lua.

## Plan

- [ ] **ariadne dependency — ariadne#144:** `sdlc resolve <ref>` (read-only; grammar +
      discovery from the vocab model). Tracked as its own ariadne issue (base-layer Go,
      goes through ariadne's SDLC). parley can prototype against a temporary Lua
      resolver to nail the UX before ariadne#144 lands.
- [ ] parley: ref highlighting (conceal/treesitter/regex).
- [ ] parley: resolve-under-cursor keymap → `sdlc resolve` → open; family picker.
- [ ] Cross-repo: derive the sibling-parent-dir + repo→path mapping (parley is the
      cross-repo operator surface already).

## Log

### 2026-07-03

- Created from a design discussion (with the operator) on ariadne#144. Conclusion:
  navigation belongs in parley at **read time** (symbolic ref stays canonical; path
  resolved on demand) — rejecting ariadne#144's stored-cross-link premise, which
  rots when files archive. Resolver logic goes in a read-only `sdlc resolve` (single
  source, lock-free, so not subject to the mutating-verb slowness) that parley shells
  to; parley owns highlight + keymap + family picker.
- Operator correction (2026-07-04): since the resolver (`sdlc resolve`) is ariadne
  base-layer work, **ariadne#144 is NOT wontfix** — it was reopened + reframed as the
  ariadne slice, and this issue now `deps: [ariadne#144]`.
