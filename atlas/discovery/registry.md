# Discovery Registry

## Scope

The registry is an internal library describing repository document types and
where to search for them. It is exposed as `require('parley').discovery`.
It builds descriptors and search commands; it does not execute the search.
There is currently no production request-builder consumer of its `render()`
output, so this registry does not automatically teach a chat the repository's
types or grant file access. Ordinary users use the existing artifact finders
and context/file tools; the [repo policy](../infra/repo_mode.md) controls access.

The effective registry combines Parley's base types with local `type:` values
discovered through ripgrep. Its interface keeps descriptor production separate
from command compilation (`ARCH-PURE`). A future index could replace discovery,
but an index service is not a current installation requirement.

## Module layout (`lua/parley/discovery/`)
| Module | Role | Purity |
|--------|------|--------|
| `matcher.lua` | tagged-union predicate over `(path, fm)` | PURE |
| `descriptor.lua` | `TypeDescriptor` shape + `validate` | PURE |
| `base.lua` | `build(config)` → base descriptor list (pure fn of live config) | PURE |
| `registry.lua` | `Registry` — `of/get/names/query/spec_to_command/render_command/render` | PURE |
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

## Library outputs

`query(type, term)` produces a `DiscoverySpec`. `spec_to_command(spec)` compiles
that into structured search directories, relative name globs, frontmatter filters
and a content term. `render_command(cmd)` shell-quotes the corresponding ripgrep
pipeline. Absolute locate globs become positional directories plus relative `-g`
patterns; only `frontmatter` matchers add a frontmatter filter. Executing the
rendered command remains the caller's responsibility.

`render()` produces one sorted bullet per type, with label, description and
derived find hint. Neither output is currently injected into ordinary chat.

## base ∪ local composition (RegistryBuilder)
`build(ctx)` composes the effective registry for an injected mode context
(`{repo_root, super_repo_members}` — no real-cwd dependence):
- **global** (no repo_root) → base only.
- **repo** → base ∪ `local_types.discover(repo_root)`.
- **super-repo** → base ∪ union(local over members), deduped by name (base
  added first → wins ties; `local_types.discover` already subtracts base, so a
  collision can only arise across members → appears once).

The **merge**: repo-relative `locate` globs are expanded across the super-repo
members when present, otherwise the selected repo root; absolute/global globs (chat/note's `chat_dir`/`notes_dir`) pass
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

## Issue vocabulary and release data

`construct/generated/vocabulary/issue.json` is tracked and shipped with Parley.
It is generated from the maintainer's CUE vocabulary; installed users do not need
ariadne or CUE to read it. `issue_vocabulary.home()` supplies the issue directory
at setup with precedence: explicit `issues_dir` > vocabulary home > built-in
default. The runtime loader resolves from the installed plugin root, validates
its shape, and reports missing/damaged data without preventing chat startup.
See [issue management](../issues/issue-management.md) for degraded capabilities.

## Checks and related behavior

The `discovery_*_spec.lua` files in `tests/unit/` cover the pure library. `tests/integration/discovery_builder_spec.lua` covers configured
roots and compiled search behavior; `discovery_local_types_spec.lua` covers
ripgrep discovery. `tests/unit/issue_vocabulary_spec.lua` covers release data.

- [Repo mode](../infra/repo_mode.md): project roots.
- [Super-repo mode](../modes/super_repo.md): sibling discovery.
