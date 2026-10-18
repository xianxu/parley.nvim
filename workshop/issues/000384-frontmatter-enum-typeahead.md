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
---

# Frontmatter typeahead for enum values (collaboration-mode first, generic registry)

## Problem

Frontmatter keys with a fixed set of values (`collaboration-mode:` today, `presentation:` with #383, the issue `status:`) are typed from memory, and a typo only surfaces when the review fails (`collaboration-mode` "fails: name the bad mode"). The operator asked for typeahead on these values (via the hub, 10-18). It must draw on the definition parley already enforces, not a second hardcoded list, and be generic, so other enum keys join by declaring their values.

## Spec

- One registry of frontmatter enum keys: each declares its key and a function returning its allowed values (and optionally which files it applies to). A key joins by declaring itself; nothing else changes.
- `collaboration-mode` takes its values from the list `skills/review/collaboration.lua` enforces (`discussion`, `collaboration`, `chat`), which becomes an exported list that the resolver's `known` set is built from. That gives one source.
- The existing one-off issue `status:` omnifunc (`issues.lua`, vocabulary-backed) moves onto the registry, applying to issue files only.
- Typeahead triggers only inside the frontmatter block, on the value of a registered key (the scalar form `key: <here>`), and offers the values matching what is typed. It is available through nvim-cmp (a `parley_frontmatter` source added to the buffer's existing sources, not replacing them) and through omnifunc as a fallback, on every markdown buffer.
- Out of scope: the mapping form of `collaboration-mode` (`default:` and per-mode heading lists), and `presentation`'s entry, which #383 adds by declaring it.

## Done when

In a markdown buffer, typing on a `collaboration-mode:` line in the frontmatter offers `discussion`, `collaboration` and `chat` (filtered by prefix), drawn from the resolver's own list. Nothing is offered outside the frontmatter or on undeclared keys. Issue files still complete `status:`, through the same registry. A spec covers the pure context and candidate logic and the cmp source, and adding a key is a one-line declaration.

## Plan

Quick flow (about 80 code lines). One source per key (ARCH-DRY); the pure part is unit-tested with no buffer.

- [ ] `lua/parley/frontmatter_enum.lua`, pure core:
  - `M.declare(key, { values = fn, applies = fn(path)? })` and `M.keys()`.
  - `M.context(lines, row, col)` returns `{ key, start, partial }` when the cursor is on a `key: <value>` line strictly inside the opening `---` block (via `frontmatter.parse`'s `lnum`/`close`), for a declared key; otherwise nil.
  - `M.candidates(key, partial, path)` returns the declared values starting with `partial`, or `{}` when `applies(path)` is false.
- [ ] Declarations, each at its owner:
  - `skills/review/collaboration.lua` exports `M.modes = { "discussion", "collaboration", "chat" }`, builds `known` from it, and declares `collaboration-mode`.
  - `issues.lua` declares `status` from `vocab():status_values()`, with `applies` = issue files (its `issues_dir`). The dead one-off `M.omnifunc` / `setup_issue_completion` are deleted: `setup_issue_completion` has no caller, so status typeahead never worked.
  - #383 later adds `presentation` the same way.
- [ ] Integration:
  - `frontmatter_enum.attach(buf)` from the generic markdown setup (`init.lua`, beside `comment.attach` / `session_sync.attach`).
  - It sets `omnifunc` when the buffer has none.
  - When nvim-cmp is loaded, it registers a `parley_frontmatter` source once (`is_available` = cursor inside a frontmatter value) and appends it to the buffer's current sources (`cmp.get_config().sources`), never replacing them.
  - `neighborhood`'s chat source list (`cmp_path_sources`) includes it too, so chat buffers keep it.
- [ ] Specs:
  - `tests/unit/frontmatter_enum_spec.lua`: context on, before and after the frontmatter, on an undeclared key, and with no closing `---`; prefix filtering; `applies`.
  - The collaboration values equal the resolver's `known` (one source).
  - `tests/integration/frontmatter_enum_cmp_spec.lua`: with a stub `cmp` table, attaching appends the source and keeps an existing one; its `complete` yields the modes on a `collaboration-mode:` line and nothing in the body; omnifunc gives the same.
- [ ] Atlas: a line in the markdown-editing page on frontmatter typeahead and how a key joins.

## Log

### 2026-10-18
