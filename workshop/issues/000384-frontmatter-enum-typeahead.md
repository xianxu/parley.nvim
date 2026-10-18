---
id: 000384
status: working
deps: []
github_issue:
created: 2026-10-18
updated: 2026-10-18
estimate_hours:
collaboration-mode: collaboration
card_mirror: '01cf914ccbc6b47ca2c65d48da5087054e8fad6b' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-18T00:28:57-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: full, provenance: inferred}
---

# Frontmatter typeahead for enum values (collaboration-mode first, generic registry)

## Problem

Frontmatter keys with a fixed set of values (`collaboration-mode:` today, `presentation:` with #383, the issue `status:`) are typed from memory, and a typo only surfaces when the review fails (`collaboration-mode` "fails: name the bad mode"). The operator asked for typeahead on these values (via the hub, 10-18). It must draw on the definition parley already enforces, not a second hardcoded list, and be generic, so other enum keys join by declaring their values.

## Spec

- One registry of frontmatter enum keys: each declares its key and a function returning its allowed values (and optionally which files it applies to). A key joins by declaring itself; nothing else changes.
- `collaboration-mode` takes its values from the list `skills/review/collaboration.lua` enforces (`discussion`, `collaboration`, `chat`), which becomes an exported list that the resolver's `known` set is built from. That gives one source.
- The existing one-off issue `status:` omnifunc (`issues.lua`, vocabulary-backed) moves onto the registry, applying to issue files only.
- Typeahead triggers only inside the frontmatter block, on the value of a registered key (the scalar form `key: <here>`), and offers the values matching what is typed, on every markdown and chat buffer. Only one menu ever opens: nvim-cmp's when cmp is active in the buffer (a `parley_frontmatter` source added ahead of the buffer's own sources, never replacing them), else Vim's popup (see Revisions).
- Out of scope: the mapping form of `collaboration-mode` (`default:` and per-mode heading lists), and `presentation`'s entry, which #383 adds by declaring it.

## Done when

- In a markdown buffer, typing on a `collaboration-mode:` line in the frontmatter offers `discussion`, `collaboration` and `chat`, filtered by prefix and drawn from the resolver's own list.
- Nothing is offered outside the frontmatter, on undeclared keys, or once the value is typed out in full.
- Issue files still complete `status:`, through the same registry, and other files don't.
- Adding a key is a one-line declaration.
- With nvim-cmp active in the buffer, only one menu opens (cmp's, holding the values). Without cmp, Vim's popup is used.
- Specs cover the pure context and candidate logic, the popup, and the cmp path.

## Plan

Quick flow (about 80 code lines). One source per key (ARCH-DRY); the pure part is unit-tested with no buffer.

- [x] `lua/parley/frontmatter_enum.lua`, pure core:
  - `M.declare(key, { values = fn, applies = fn(path)? })` and `M.keys()`.
  - `M.context(lines, row, col)` returns `{ key, start, partial }` when the cursor is on a `key: <value>` line strictly inside the opening `---` block (via `frontmatter.parse`'s `lnum`/`close`), for a declared key; otherwise nil.
  - `M.candidates(key, partial, path)` returns the declared values starting with `partial`, or `{}` when `applies(path)` is false.
- [x] Declarations (values from each owner; the declaration lines live in `frontmatter_enum.lua`):
  - `skills/review/collaboration.lua` exports `M.modes = { "discussion", "collaboration", "chat" }`, builds `known` from it, and declares `collaboration-mode`.
  - `issues.lua` declares `status` from `vocab():status_values()`, with `applies` = issue files (its `issues_dir`). The dead one-off `M.omnifunc` / `setup_issue_completion` are deleted: `setup_issue_completion` has no caller, so status typeahead never worked.
  - #383 later adds `presentation` the same way.
- [x] Integration (revised twice, see Revisions): `frontmatter_enum.attach(buf)` from both the markdown setup (`init.lua`, beside `comment.attach`) and the chat setup (`prep_chat`) adds a buffer-local TextChangedI handler.
  - With nvim-cmp loaded and enabled for the buffer, the values are a `parley_frontmatter` cmp source. It is in its own group sorted before the buffer's sources, available only on a frontmatter value, and re-added on change.
  - Otherwise it is Vim's popup through `helper.complete_noselect`, the mechanism the old issue `status:` popup used. That `init.lua` block is deleted. There is no omnifunc.
  - `scripts/check-frontmatter-cmp.lua` is the opt-in live check against the real nvim-cmp.
- [x] Specs:
  - `tests/unit/frontmatter_enum_spec.lua`: context on, before and after the frontmatter, on an undeclared key, and with no closing `---`; prefix filtering; `applies`; the collaboration values are exactly the resolver's (one source).
  - `tests/integration/frontmatter_enum_popup_spec.lua`: TextChangedI offers the modes, filtered; quiet on a full value, an undeclared key and the body; one attach; status only in issue files; attached by parley's markdown setup.
- [x] Atlas: a line in the markdown-editing page on frontmatter typeahead and how a key joins.

## Log

### 2026-10-18
- 2026-10-18: closed — Suite green on 9e3ea59d (sdlc-local/suite). Specs: frontmatter_enum_spec 9/9, frontmatter_enum_popup_spec 7/7; issues, issue_vocabulary, issue_unavailable, collaboration, review_send green. Mutations fail their spec: no markdown attach, hardcoded mode list, no cmp branch, no symlink resolution. Live: scripts/check-frontmatter-cmp.lua passes against the operator real nvim-cmp (pumvisible=0, cmp menu = discussion) and fails with the cmp branch removed (both menus). Review round 1 BR-1/BR-2 and the 3 minors fixed (Revisions).; review verdict: SHIP
- 2026-10-18: flow upgraded quick → full — 219 added lines in code files (limit 100); an earlier round of this close already ran the full review

- Built. The integration changed from the posted plan, a simplification: issue files already had a working `status:` typeahead, a TextChangedI popup in `init.lua` calling `helper.complete_noselect`, which needs no completion plugin. The `omnifunc` in `issues.lua` was dead code (`setup_issue_completion` had no caller). So the popup is generalized into `frontmatter_enum.attach`, and no nvim-cmp source or omnifunc is added: one mechanism, which works whether or not cmp is installed (ARCH-DRY).
- `collaboration.lua` exports `M.modes`. Its `known` set and its bad-mode message are built from it.
- Mutation checks: dropping the markdown attach fails "is attached by parley's markdown buffer setup", and a hardcoded `known` missing `chat` fails "draws collaboration-mode from the resolver's own list".
- **cmp check (hub, 10-18).** The operator runs nvim-cmp, so I checked against their real config in a bounded headless nvim, with my worktree first on the runtimepath, typing `di` on a `collaboration-mode:` line.
  - **Before:** the two **fight**. Vim's popup opened (`pumvisible=1`, 1 item) **and** cmp's own menu opened at the same time (3 entries: buffer words like `discussing`, `dialog`).
  - **Fix:** when cmp is loaded and enabled for the buffer, the built-in popup is suppressed and the values become a `parley_frontmatter` cmp source. It goes in its own group sorted before the buffer's sources, is available only on a frontmatter value, is re-added on each change because buffer sources get reset, and calls `cmp.complete()` once when it was just added. Where cmp is disabled for the buffer, the Vim popup is kept.
  - **After:** `pumvisible=0`, and cmp's menu is open with 1 entry, the value. Spec'd with a stub cmp (source first, no Vim popup, body unaffected, fallback when disabled).

## Revisions

- **2026-10-18, while building (hub-approved).** The integration became Vim's TextChangedI popup, generalized from the issue `status:` popup that already worked, instead of a new cmp source plus an omnifunc. The omnifunc fallback was dropped, because the popup covers the no-cmp case.
- **2026-10-18, the hub's cmp check.** Measured against the operator's real nvim-cmp: the popup and cmp's menu opened at once. With cmp active the values are therefore a `parley_frontmatter` cmp source, in its own first group, and the Vim popup is the fallback when cmp is absent or disabled for the buffer. The Spec's integration bullet was reworded to match.
- **2026-10-18, close review round 1.**
  - BR-1: `status`'s `applies` resolves symlinks on both sides, as the deleted `init.lua` block did, with a symlinked-workspace spec.
  - BR-2: this section, the reworded Spec bullet and the header comment.
  - Minor findings:
    - `issues.complete_frontmatter_values` and the now-orphaned `IssueVocabulary:enumerable_values` are deleted, and their tests moved onto `status_values()` and the registry;
    - test keys are torn down with a new `undeclare`;
    - `scripts/check-frontmatter-cmp.lua` is the opt-in conformance check for the cmp stub. It passes against the real cmp, and fails with the cmp branch removed, reproducing the two menus.

