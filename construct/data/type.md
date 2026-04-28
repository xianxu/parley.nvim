---
type: type
name: type
description: Meta-prototype — declares the structure of a data-type prototype. Apply this when adding a new type to the system.
---

# type

A *type prototype* is a markdown file that describes one kind of data artifact the agent can create. The prototype carries three things bundled together:

1. **Frontmatter shape** — fields, with which are required.
2. **Body skeleton** — sections, ordering, leading summary blocks.
3. **Authoring instructions** — guidance the agent reads when creating or editing an instance of this type.

The dispatcher skill (`xx-data`) reads the prototype at write/edit time and applies it. New types are pure data — adding one does not require a code or skill change.

This file is itself a prototype with `type: type`, so it self-hosts: applying `type.md` produces a new prototype file.

## Frontmatter shape

| Field | Required | Notes |
|---|---|---|
| `type` | yes | The type name. Matches the filename without `.md`. For this meta-prototype, `type: type`. |
| `name` | yes | Same as `type` for now. Reserved for future divergence (e.g., a single type spanning multiple variants). |
| `description` | yes | One sentence. Starts with "Use when...". Used by the dispatcher for fuzzy intent matching against conversational triggers. |

## Body skeleton

A prototype's body MUST contain these sections, in order:

1. **Title** — `# <name>` matching the filename.
2. **Lede paragraph** — one short paragraph explaining what this type captures and when it applies.
3. **Frontmatter shape** — table of fields the *instances* must carry, with required/optional and notes.
4. **Body skeleton** — the section structure of an *instance* of this type, with guidance about each section.
5. **Authoring instructions** — what the dispatcher should do when applying this prototype. Specific to this type's domain.
6. **Search recipes** (recommended) — `rg` examples for finding instances of this type by common attributes. See "Greppability" rule below.
7. **Rules** (optional) — type-specific constraints worth calling out.

**Critical:** these sections describe the prototype, *not* the instance. None of them appear in an instance of the type. The instance's body is whatever the **Body skeleton** section *describes*. The dispatcher reads the prototype as a spec and emits the spec's described shape; it never copies the prototype's meta-sections (Frontmatter shape, Body skeleton, Authoring instructions, Rules) into the instance.

The one self-referential exception: applying *this* meta-prototype produces a new prototype, whose body skeleton happens to be the same six meta-sections. That's consistent — instances always follow what the prototype's *Body skeleton* section says — it's just that for this prototype, that section says "produce another prototype."

## Authoring instructions

When the dispatcher applies `type.md` (i.e., the user wants to add a new type to the system), the goal is to design a new prototype, not to fill a fixed schema. So:

1. **Invoke `superpowers-brainstorming`** as the design step. The brainstorm should answer:
   - What's distinctive about this kind of doc — what problem does it solve that an unstructured note doesn't?
   - What belongs in **frontmatter**? Frontmatter is for fields that are *queryable* (filtered, sorted, indexed by tooling), *referenced from outside* (linked to by ID, surfaced in dashboards), or *stable enough* that humans won't rewrite them in prose. Free-form prose stays in the body.
   - What sections does the **body** need? Aim for the smallest set that's actually useful at read time. Resist baking in sections that 80% of instances will leave empty.
   - What does an agent need to **ask the user** when creating an instance? What can it usually infer from context?
   - Where should instances of this type live by default? (e.g., `memory/work/`, `workshop/staging/`, etc.) The dispatcher's location-discovery logic still applies, but the prototype can hint at a sensible default.

2. **Decide where the new prototype itself lives:**
   - **Shared** (`construct/data/<name>.md` in ariadne) — when the type is broadly useful and should propagate to every descendant repo via construct.
   - **Project-local** (`<repo>/data/meta/<name>.md`) — when the type is repo-specific (e.g., a `release-checklist` for a particular product). The `meta/` segment keeps prototypes namespaced separately from instances; instances of any type live elsewhere under `data/` or `memory/`.
   - Ask the user explicitly. Default suggestion: project-local unless the type is obviously generic.

3. **Write the prototype file** following the body skeleton above. The prototype should be self-contained — a fresh agent reading only this file should be able to create good instances without further context.

4. **Validate:** before declaring done, mentally apply the new prototype to a hypothetical instance. If the result feels thin, the prototype is too sparse; if it feels rigid, it's overspecified. Adjust.

## Search recipes

```sh
# List every type prototype on disk
rg -l "^type: type" construct/data/ data/meta/ 2>/dev/null

# Find which prototype declares a specific field (e.g., a "purpose" field)
rg -l "^type: type" construct/data/ data/meta/ | xargs rg -l "^| \`purpose\`"

# Find prototypes whose lede mentions a domain
rg -l "^type: type" construct/data/ data/meta/ | xargs rg -l -i "deadline"
```

## Rules

- One prototype per file. One type per prototype.
- Filename and `type:` field must agree.
- Prototypes are data, not code. Keep them readable end-to-end in under a minute.
- **Prototype is spec, not template.** Meta-sections (Frontmatter shape, Body skeleton, Authoring instructions, Search recipes, Rules) describe the instance — they never appear *in* the instance.
- A project-local prototype with the same name as a shared prototype shadows it completely (no merging).
- Edits to a prototype affect only *new* instances. Existing instances are unaffected unless re-edited.
- **Greppability.** Instances are searched with `rg`, no index. To keep the grep signal on one line:
  - Frontmatter list values use inline form: `attendees: [alice, bob, carla]`. Avoid YAML multi-line (`- alice` on its own line) — it makes per-item filtering harder across files.
  - Use ISO dates (`YYYY-MM-DD`) so prefix searches like `^date: 2026-04` work.
  - Use predictable `## Section` headers for body sections so `rg "^## Decisions"` finds all instances.
  - Every prototype should include a `Search recipes` section showing concrete `rg` invocations for its common queries.
