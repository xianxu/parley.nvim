---
id: 000115
status: open
deps: [000116, 000186]
created: 2026-04-30
updated: 2026-07-14
---

# Faceted typed finder (find artifacts of interest, by type)

> Reframed 2026-06-11 from "improve `<C-g>m`" — see `## Revisions`. The original
> goal (find datatype artifacts, filter out noise) is realized properly by a
> registry-driven *faceted* finder, not by overloading the `<C-g>m` catch-all.

## Background (original framing, 2026-04-30)

After the start of ariadne datatypes — semi-structured markdown files with rules, some managed as processes (project, roadmap) — these are, like issues and chats, just semi-structured markdown; only the interpreter (deterministic vs agentic) differs. `<C-g>m` was created as a catch-all viewing device for markdown. Two improvement dimensions were noted: (1) more depth (datatypes nest deeper than `data/project`); (2) control noise by finding *only* datatype artifacts (needs a directory/naming/discriminator convention).

## Revisions

### 2026-06-11 — reframed to the faceted finder; `<C-g>m` stays the escape hatch

The design conversation that produced the discovery registry (#116) resolved dimension (2) — "find only datatype artifacts, by type" — into its own surface rather than an overload of `<C-g>m`:

- **`<C-g>m` stays the type-blind, registry-independent escape hatch** (dumb markdown walk, catches freeform files). It must keep working even when the registry is wrong/empty/mid-refactor, so it deliberately does *not* depend on the registry. Dimension (1) (more depth) is a minor, separate `<C-g>m` tweak — not this issue.
- **Type-aware finding moves here**, to a *faceted* finder driven by #116's registry.

### 2026-07-14 — #186 foundation dependency

- Reason: #115 and #186 both named Issue Finder repository facets and could
  otherwise create parallel policy implementations.
- Delta: add #186 as a dependency, consume its `finder_facets` engine, and
  narrow this issue's remaining delivery to descriptor-driven facet
  declarations plus shared finder/adapter unification.

## Spec

A single shared finder UI, **parameterized by type** (not an all-types view). Each invocation is scoped to one type; per-type finders (chat `<C-g>f`, note `<C-n>f`, issue `<C-y>f`, vision `<C-j>f`) become *instances* of this one UI with their type fixed.

**Why single-type, not all-types:** each type has its own filterable **facets** —
- chat → frontmatter tags (`[tag]`);
- issue → status, and `{repo}` in super-repo mode;
- note → date structure;
- any type → `{repo}` in super-repo mode.

So a finder needs (a) potentially a type selector and (b) one-or-more *per-type* facet bars. You can't render a coherent facet bar across heterogeneous types at once — hence single-type-per-invocation. The **UI is generic; the facets are type-supplied.** Reuse the existing sticky-filter machinery (`finder_sticky.lua` `[tag]`/`{repo}` fragments + `float_picker`); membership/discrimination uses #116's `Matcher`.

**Registry extension this implies:** a descriptor declares its **facets** (the filterable frontmatter fields + whether `{repo}` applies). That's the natural growth of the #116 `TypeDescriptor` and the load-bearing new piece — design it here.

**Relationship to #116 M2:** #116 M2 does only the *minimal* retrofit (existing finders source their home root folder from the registry). This issue is the larger, separate design that unifies the finders into one faceted UI. It depends on #116's registry (`deps: [000116]`).

**Relationship to #186:** #186 first extracts Chat Finder's deterministic facet
state/filter/projection behavior into the registry-independent
`finder_facets` engine and uses it for current Chat/Issue adapters. This issue
must consume that engine: registry `TypeDescriptor` facet declarations supply
keys/configuration to it, while the eventual shared finder component owns type
selection and adapter unification. It must not introduce a second facet-policy
state machine. Accordingly this issue also depends on #186.

## Done when

- One shared finder component renders a type's instances with that type's facet bar(s), sourced from the registry.
- The existing per-type finders are instances of it (chat/note/issue/vision), preserving their current filters (chat `[tag]`, super-repo `{repo}`).
- Issue preserves and consumes the `{repo}` facet delivered by #186 through the shared registry-driven finder component.
- `<C-g>m` is untouched (still the type-blind escape hatch).

## Plan

_Needs its own design pass + plan doc (`superpowers-writing-plans`) — non-trivial (faceted UI, per-type facet declarations, finder unification). Not started; gated behind #116 M1 (the registry) and ideally M2 (root-sourcing retrofit)._

- [ ] Design registry facet declarations and shared finder unification on top of #186.

## Log

### 2026-04-30

Filed as "improve `<C-g>m`".

### 2026-06-11

Reframed to the faceted typed finder (see `## Revisions`). Split cleanly from #116: #116 M2 = minimal finder-root-sourcing; this issue = the faceted-UI unification + per-type facet declarations. `deps: [000116]`. Surfaced during the discovery-registry design conversation when the "two filter bars" problem (type-switch + per-type facets) showed an all-types view is incoherent — so: single-type-per-invocation, shared UI.

### 2026-07-14

Reconciled ownership with #186: #186 delivers the registry-independent facet
policy engine plus current Chat/Issue adapters; #115 depends on it and retains
ownership only of registry facet declarations and full finder unification
(`ARCH-DRY`, `ARCH-PURPOSE`).
