# Discovery Registry

## Overview
The discovery registry is parley's data-driven model of a repo's **noun
vocabulary** — *what file types (nouns) exist and how to find their instances* —
that a readonly research chat consumes instead of hard-coding type knowledge.
It is the M1 core of issue #116. Its `render()` output feeds parley's repo-aware
**chat context** (the P1 "chat as ariadne workbench" mode). _(Originally framed
as feeding a #128 `repo_discovery` skill; the #128 re-scope reclassified that as
P1 chat context, not a P2 skill — see `workshop/pensive/parley-two-modes-chat-vs-artifact.md`.)_

A registry maps `name → TypeDescriptor`. The effective registry is **base ∪
local**: a parley-shipped *base* (universal + parley-native types) unioned with
*local* `type:` values grep-discovered from the inspected repo. The registry
*interface* is decoupled from its *production* (grep now; a `datatype`-binary
index later — same output shape, swappable producer).

## Module layout (`lua/parley/discovery/`)
| Module | Role | Purity |
|--------|------|--------|
| `matcher.lua` | tagged-union predicate over `(path, fm)` | PURE |
| `descriptor.lua` | `TypeDescriptor` shape + `validate` | PURE |
| `base.lua` | `build(config)` → base descriptor list (pure fn of live config) | PURE |
| `registry.lua` | `Registry` — `of/get/names/query/spec_to_command/render` | PURE |
| `merge.lua` | `expand_locate` + `dedupe_compose` — the pure base∪local merge | PURE |
| `local_types.lua` | grep novel `type:` minus base → `local` descriptors | INTEGRATION (rg) |
| `init.lua` | `RegistryBuilder` — `build(ctx)` / `current()`; live-config via `setup(parley)` | INTEGRATION |

## Matcher discriminator kinds
The four highest-value nouns (chat/note/vision/issue) are **not** `type:`-
frontmatter docs, so a single `type:` test won't find them. The matcher is a
tagged union (from the #116 source-map audit):

| kind | test | used by |
|------|------|---------|
| `frontmatter` | `fm[field] == value` | pensive, prose, continuation (the `type:` docs) |
| `frontmatter_present` | `fm[field] ~= nil` | chat (header `file:`, no `type:`) |
| `filename` | basename matches pattern | issue (`NNNNNN-*.md`) |
| `any` | always true; `locate` glob discriminates | note, plan, vision |

`filename` is basename-only and does **not** distinguish issue from plan (both
share the `NNNNNN-slug` convention) — the `locate` glob does. Invariant: *a
`filename` matcher is only sound within its descriptor's `locate` scope.*

## TypeDescriptor
`{ name, label, scope, locate, matcher, blurb }` — everything deterministic
code needs about one type. `scope` ∈ `base | local`; `locate` is a list of path
globs (carry extension, e.g. `*.md`/`*.yaml`); `blurb` is one line for
`render()`. Base `locate` globs are **derived from config keys** (`issues_dir`,
`vision_dir`, `repo_chat_dir`/`chat_dir`, `repo_note_dir`/`notes_dir`) rather
than literals (ARCH-DRY); they are repo-relative so the builder can prefix
repo roots. `plan` has no config key (parley doesn't auto-create
`workshop/plans/`) — literal `workshop/plans/*.md`.

## The two consumers
- `query(type, term) → DiscoverySpec` then `spec_to_command(spec) → string`:
  the **deterministic-shell, thin-model** seam. The model only ever picks a
  noun + a term; the registry compiles the actual `rg` pipeline. Only a
  `frontmatter`-kind matcher adds a frontmatter filter; otherwise the `locate`
  glob discriminates. "Decide the search" (pure) is split from "run the search"
  (IO, consumer-side / M2).
- `render() → string`: the noun-vocabulary text — one sorted bullet per type
  (label, blurb, a derived find-hint). This is the repo-aware vocabulary parley's
  **chat context** (P1) surfaces; its format is a contract guarded by
  verbatim-line assertions in the registry spec. _(Pre-#128-re-scope this was
  framed as a `repo_discovery` skill body — now P1 chat context, not a P2 skill.)_

## base ∪ local composition (RegistryBuilder)
`build(ctx)` composes the effective registry for an injected mode context
(`{repo_root, super_repo_members}` — no real-cwd dependence):
- **global** (no repo_root) → base only.
- **repo** → base ∪ `local_types.discover(repo_root)`.
- **super-repo** → base ∪ union(local over members), deduped by name (base
  added first → wins ties; `local_types.discover` already subtracts base, so a
  collision can only arise across members → appears once).

The **merge**: repo-relative `locate` globs are expanded across `[repo_root] +
members`; absolute/global globs (chat/note's `chat_dir`/`notes_dir`) pass
through unchanged. So `query()` spans global ⊕ repo ⊕ siblings by reusing
parley's existing root union (super_repo members, sourced from
`super_repo.compute_members`) — no separate root-scope enum. `current()` reads
the live `config.repo_root` + `config.super_repo_members`.

## Grep-now / index-later seam
`local_types.discover` runs `rg -o '^type: [A-Za-z0-9_-]+'` (hyphen-safe —
`\w+` would truncate `meeting-notes`), following `grep.lua`'s idiom (load-time
rg detection + `vim.fn.system`, not `vim.system`). It degrades to "no local
types" when rg is absent. This module is the single swap point for a future
`datatype`-binary-maintained index: same descriptor-list output, different
producer.

## Scope (M1 only)
M1 is the registry **core** (this doc). Deferred:
- **M2** — finders source their home root folder from the registry (the
  existing per-type finders; `<C-g>m` stays the type-blind escape hatch).
- **M3** — embedded descriptor format + human-driven new-instance scaffolding.

## Related
- [Repo Mode](../infra/repo_mode.md) — the root-union the merge reuses.
- [Super-Repo Mode](../modes/super_repo.md) — sibling-repo member discovery.
- Issue `workshop/issues/000116-*.md`, plan `workshop/plans/000116-*-plan.md`.
