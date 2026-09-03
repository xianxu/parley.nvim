---
id: 000212
status: open
deps: []
github_issue:
created: 2026-09-02
updated: 2026-09-02
estimate_hours:
---

# gate the ariadne surface behind repo detection

## Problem

The ariadne workflow surface is registered unconditionally for every user, and
then fails *silently* for anyone without an ariadne repo — which is worse than
failing loudly.

`init.lua:851-852` passes `register_global` a **literal** scope list,
`{ "global", "repo", "note", "issue", "vision", "chat" }`, never filtered by
`.parley` presence. The seven ariadne modules are also `require`d unconditionally
at `init.lua:69,70,97,111,115,119,123`. Consequences for a plain user:

| Feature | What they see | Decided at |
|---|---|---|
| Issue finder `<C-y>f` | Empty picker, no error — `issues_dir` always resolves against git root so the guard cannot fire | `issues.lua:474-476` |
| New issue `<C-y>c` | Prompt, spinner, then `Issue creation failed:` | `issues.lua:752-776` |
| Vision finder `<C-j>f` | Empty picker, no error | `vision_finder.lua:53` |
| Vision export | Writes an empty `roadmap.csv`/`roadmap.dot` into their git root | `vision.lua:1626-1631` |
| `gf` on a plain `#42` | `sdlc` not found; native `gf` never attempted | `artifact_ref.lua:115-131` |

Additionally `<C-n>i`/`<C-n>I` are bound globally and are not rebindable
(`keybinding_registry.lua:305-318`), four `<leader>c*` maps are claimed in every
buffer with zero tests for `parley.copy`, and `<C-g>?` *hides* the repo/issue/
vision bindings outside a repo (`keybinding_registry.lua:66-68`) — so help and
reality disagree in both directions at once.

Separately, `skills/review/SKILL.md:1` links the marker grammar to
`../../../../ariadne/workshop/targets/review-convention.md` — a sibling repo that
does not ship — and that file is sent to the model as system prompt.
`drill_in.lua:31,514` names the same out-of-repo spec as normative for `<M-q>`.

## Spec

A feature that cannot work in the current context must not be bound, and must not
present an empty affordance.

- Filter the `register_global` scope list by actual context instead of passing a
  literal. Help and registration already derive from one table
  (`keybinding_registry.lua`), so gating them together is the natural fix and
  keeps them from drifting apart (`ARCH-DRY`).
- Make the seven ariadne module requires conditional or lazy, so a plain install
  neither loads nor pays for them (`ARCH-CONSTRAINTS`: plugin load is a startup
  path; the budget is Neovim's startup frame, and inert subsystems should not be
  on it).
- Where a feature is genuinely unavailable, say so once and clearly, rather than
  rendering an empty picker with a facet bar.
- `gf` must fall through to native `gf` when resolution is impossible, not surface
  a raw shell error. A plain `#42` in prose is not an artifact ref.
- Inline the review-convention grammar into the shipped `SKILL.md` so the prompt
  text is self-contained, and stop citing an out-of-repo path as normative.
- Do not delete the ariadne features. This is gating, not removal; it is also the
  decoupling that any future #162 split requires first, so the work is not
  throwaway either way.

## Done when

- In a directory with no `.parley` marker, no `<C-y>*` or `<C-j>*` mapping exists,
  and `:map` proves it.
- No ariadne module is loaded in that context, provable by module-table inspection.
- `<C-g>?` lists exactly the bindings that are actually live — the help/reality
  agreement is asserted in both directions by a test.
- `gf` on a plain `#42` with no `sdlc` present performs native `gf`.
- The shipped review `SKILL.md` contains no link that escapes the repository.
- Inside an ariadne repo, every gated feature still behaves as it does today.

## Plan

- [ ] Context-filter the `register_global` scope list; assert unbound-when-inert.
- [ ] Make the seven ariadne requires conditional/lazy; assert not-loaded-when-inert.
- [ ] Assert help matches live bindings in both directions.
- [ ] `gf` falls through to native when no ref resolves.
- [ ] Inline the review-convention grammar into the shipped SKILL.md.
- [ ] Regression pass inside an ariadne repo — no feature lost.

## Log

### 2026-09-02

Split out of the `workshop/plans/000206-shipping-surface-inventory.md` audit as blockers B8 and B9
plus the Tier 3 silent-failure set.

This issue is the decoupling half of #162. The coupling grep found the ariadne
surface concentrated in `issues.lua` (82 refs), `vision.lua`, `super_repo.lua`,
`neighborhood.lua`, `artifact_ref.lua` and the two finders, with the chat core at
0-6 refs and `init.lua` (71 refs) as the single wiring hub — so a split is
tractable, but gating is what the launch needs and is a prerequisite of splitting
regardless. #162 accordingly becomes a deferred decision, not scheduled work.
