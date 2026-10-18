---
id: 000384
status: open
deps: []
github_issue:
created: 2026-10-18
updated: 2026-10-18
estimate_hours:
collaboration-mode: collaboration
card_mirror: '39be89c7f30858d932bc2f36e9381b1237ed00a1' # card fields mirrored from issue-cards; edit via sdlc
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

- [ ]

## Log

### 2026-10-18
