---
type: type
name: product
description: Use when capturing the durable charter of a product (the umbrella term for any deliberate effort spanning 0..N peer repos — products, projects, infra). Triggers on "set up a product file for X", "capture this product", "/xx-datatype product".
---

# product

A product is the living *charter*: vision, what it is in one sentence, the durable shape (components) of what's being built, and where each component currently stands. It spans 0..N peer repositories of the brain.

Distinct from sibling datatypes:

- `project` — an execution container ("what we've decided to do for a purpose, with an MVP scope"). Operator-POV, time-bounded, can cut across multiple products and repos. A product is referenced by many projects over its life.
- `roadmap` — month-level aggregate of projects + KTLO bucket.

In short: **product describes what is built; project describes what we're working on right now to advance it.**

## Frontmatter shape

| Field | Required | Notes |
|---|---|---|
| `type` | yes | `product` |
| `name` | yes | Slug form, lowercase-hyphenated. Matches the filename without `.md`. Single namespace per brain — no two products with the same slug. |
| `repos` | yes | List of peer repository names — `[ariadne, parley.nvim]`. Empty list `[]` is valid for a product without any repo yet. Each name resolves to `<workspace-root>/<name>` where workspace-root is the parent of the brain's git root. |
| `created` | yes | ISO date. |
| `updated` | yes | ISO date of the last edit. |
| `sources` | optional | Lineage — files, parley chat IDs, URLs the agent read when authoring. List of strings. Records "where did this come from" for later human auditing. Not a rigorous reproducibility chain. |

## Body skeleton

An instance of `product` has:

1. `# <name>` — title matching the slug.
2. **Lede line** — one sentence describing the product in plain language.
3. `## vision` — why this product exists, the bet, the audience. Multiple paragraphs allowed; stay tight.
4. `## components` — container for the product's durable shape.
5. Under `## components`: a flat list of `### <component-slug>` sections. Each:
    - One-line purpose statement on the line after the heading (with a blank line between) — what the component *is*.
    - `**State:** <enum> — <short note>` line, blank-lined. Captures where the component currently stands. See *State enum* below.
    - Free prose body. Dependencies, design notes, sub-features all stated as prose.
    - **No `####` nesting.** If a component naturally decomposes, ask whether the parent is really a *group* — and if so, promote children to flat top-level.

Use blank lines between heading, purpose, state, and prose so `rg -A2 "^### " data/product/` reads cleanly.

### State enum

The `**State:**` line uses one of these values, followed by `— <short free-text note>`:

- `idea` — articulated but not started.
- `planning` — designing, not yet building.
- `in-progress` — actively being worked.
- `shipped` — done for the purpose this product had it.
- `paused` — was active, intentionally on hold.
- `dropped` — abandoned (kept in the file for context, not for resumption).

Example: `**State:** in-progress — substrate works for descendants; external-onboarding test still pending.`

Update the line as the component moves. Git history is the trajectory.

### Cross-reference convention

Use single-backtick references in prose:

- `` `slug` `` — same-product component (when the doc's product context is unambiguous, e.g. inside that product's own roadmap).
- `` `product:slug` `` — cross-product component reference.
- `` `product` `` — the product itself.

## Authoring instructions

When the dispatcher applies this prototype:

1. **Distill before asking.** Pull product name, repos, vision, and components from recent conversation and any referenced pensives/parley chats before prompting the user. Pre-fill what's clear; ask only for what's missing.

2. **Required fields the dispatcher must resolve before writing:**
   - `name` (slug) — usually obvious from "product file for X". Confirm if X has spaces or capitals.
   - `repos` — ask if not stated. Default to `[<name>]` if a repo of that name exists in the workspace; `[]` if explicitly no repo yet.
   - Lede line — one sentence. If not extractable, ask: "in one sentence, what is `<name>`?"

3. **Component handling:**
   - If the user supplied a list of components, create them flat under `## components` with the one-line purposes you can extract from conversation.
   - If no components are stated, write `## components` empty and ask: "what are the top-level components, even rough names? Details can come later."
   - Slug rule: lowercase, hyphen-separated, descriptive (`substrate-skill-management`, not `substrate`). Avoid generic names that collide across products.
   - Set `**State:** <enum>` based on conversation. Default to `idea` for new entries when unstated; ask if the user has signaled progress (e.g., "we already shipped X" → `shipped`).

4. **Vision is human-load-bearing.** Don't invent it. If the user hasn't stated it, write `## vision` with a single placeholder line `<vision goes here>` and flag it to the user. Better empty than fabricated.

5. **Default location:** `data/product/<slug>.md`. Filename matches the slug.

   **Owned by an entity.** When a product belongs to a containing entity that already has its own directory under `data/` (e.g., a company under `data/life/<entity>/`), the product may live in an entity-nested subdirectory: `data/<entity-path>/<slug>/<slug>.md`. Slug uniqueness across the brain and slug-as-filename are preserved. Example: `data/life/42shots/book-4/book-4.md`.

   **What goes in the entity-nested folder vs. elsewhere.** The folder is the *home for the product spine plus the residue*: product-specific artifacts that don't fit any cross-cutting datatype (raw draft material, reader/customer-feedback notes, contract scans, asset files, marketing copy that hasn't earned its own type yet). It is **not** "everything related to the product." Cross-cutting datatypes — `project`, `roadmap`, `meeting-notes`, `pensive`, `reference`, `procedure`, `event`, `travel-plan` — stay in their canonical homes (e.g., `data/project/<slug>.md`) and link via a `product: <slug>` frontmatter field. This keeps `rg -l "^type: <type>"` queries one-liners regardless of which product an artifact serves, and lets cross-product instances (e.g., a marketing campaign covering two products) be a single canonical file with `products: [a, b]` rather than duplicated under two folders.

   **`prose.md` is the recognized sibling for pre-manuscript fragments.** Long-running written endeavors (book, blog, essay, spec) accumulate sentences and half-thoughts before they have a chapter or post to live in. When that happens, a `prose.md` lives next to the product spine — `<product-folder>/prose.md` — and the `prose` datatype owns it. **A product in default file form (`data/product/<slug>.md`) graduates to folder form when it first gains a prose sibling**: `data/product/<slug>.md` becomes `data/product/<slug>/<slug>.md` plus `data/product/<slug>/prose.md`. The graduation is a one-time `git mv` plus an `rg` sweep for stale path references; do it explicitly rather than silently relocating. See `construct/datatype/prose.md` for the prose datatype itself.

6. **Updates preserve everything else.** Adding or modifying a component edits the existing file in place; rewriting the whole thing is forbidden. The most common edit is updating a component's `**State:**` line as work progresses.

7. **Confirm before writing:** show destination path, lede line, components list. One round of confirmation.

## Search recipes

```sh
# All products (regardless of location — works for both data/product/ and entity-nested)
rg -l "^type: product"

# Resolve product file path by slug (works regardless of location)
rg -l "^name: book-4$" $(rg -l "^type: product")

# Products that touch a repo
rg -l "^type: product" | xargs rg -l "^repos:.*charon"

# Components of a product (top-level slugs)
rg "^### " data/product/ariadne.md
rg "^### " data/life/42shots/book-4/book-4.md

# All references to a component slug across products, roadmaps, and prose
rg "\`(\w[\w-]*:)?substrate-skill-management\`"

# All cross-product references anywhere
rg -o "\`[a-z][a-z0-9-]*:[a-z][a-z0-9-]*\`"

# Lede lines for all products (any location)
rg -A2 "^# " $(rg -l "^type: product")

# All components in a particular state across products (any location)
rg "^\*\*State:\*\* in-progress" $(rg -l "^type: product")

# All artifacts linking to a given product
rg "^product: book-4$" data/
rg "^products:.*\bbook-4\b" data/

# State of one component (history via git)
git log -p --follow data/product/ariadne.md | rg -B1 "^\*\*State:\*\* " | head -50
```

## Rules

- One product per file. Slug, filename, and `name:` field must agree.
- Components are flat (`### ` only). No `#### ` headings; promote to top-level or describe sub-features in prose.
- A roadmap targeting this product references components by slug. Renaming a component requires an `rg` sweep across `data/product/`, `data/roadmap/`, and any prose docs that reference it.
- Vision text is never fabricated by the dispatcher. Empty placeholder + flag-to-human is the right behavior when unstated.
- `sources` records what the agent read. It is not a rigorous reproducibility chain — model nondeterminism and cross-repo dependencies make sha/model tracking too brittle to be worth the cost. Use `sources` as a "where did this come from" hint for human auditing.
