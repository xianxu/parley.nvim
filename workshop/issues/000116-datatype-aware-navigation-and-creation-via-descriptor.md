---
id: 000116
status: working
deps: [000114]
created: 2026-04-30
updated: 2026-06-11
estimate_hours: 20
---

# datatype-aware navigation and creation via descriptor

#115 narrows `<C-g>m` to find datatype artifacts. This issue is the broader follow-up: make parley.nvim a first-class client of ariadne's datatype system, on both the read side (typed pickers) and the write side (template scaffolding for human-driven creation).

Background context: [pensive on parley/datatype duality](../../../ariadne/docs/vision/2026-04-30-01-pensive-parley-datatype-duality.md).

## Framing

`workshop/` is parley-authoritative + agent-readable. `data/` is agent-authoritative + parley-readable. Both produce markdown with `type:` frontmatter in well-known locations. The duality holds as long as the convention does, but parley today only navigates the read side via the `<C-g>m` catch-all.

Each datatype prototype (`ariadne/construct/datatype/<name>.md` or `<repo>/datatype/<name>.md`) already encodes everything parley needs to know about an instance — search pattern, default location, slug rule, frontmatter shape. We just don't expose it to deterministic code today; the prototype body is prose.

The proposal is to add a **machine-readable descriptor** to each prototype that an agent emits and parley consumes. Static, committed, no runtime agent calls.

## Done when

- Parley can list / pick / open instances of any registered datatype without hardcoding type-specific knowledge.
- Parley can scaffold a new instance of a datatype from a template (frontmatter + body skeleton), so humans can create issues / pensives / projects without invoking an agent.
- `<C-g>m` is **kept as the type-blind escape hatch** (unchanged). M2 does only the minimal retrofit: the existing per-type finders (chat/note/issue/vision) source their *home root folder* from the registry instead of hardcoding it. (The faceted typed finder — generic UI + per-type facets — is split to #115.)
- The descriptor format is documented in ariadne's `construct/datatype/type.md` so future prototypes ship with a descriptor by default.

## Spec

### Read side

- Discover available types by listing prototypes in both `<repo>/datatype/` and `<repo>/construct/datatype/`, local-shadows-shared. (Mirrors how the dispatcher resolves types in `xx-datatype`.)
- For each type, parse its descriptor → search pattern + location glob. Build a picker that lists instances, sorted by mtime by default.
- `<C-g>m` opens a type-chooser then the typed picker; `<C-g>M` keeps current behavior.

### Write side

- Each prototype's descriptor declares a template: frontmatter scaffold (with TODO markers for required fields) and a body skeleton.
- Parley command "new instance of type X" creates a new file in the default location with the template pre-filled and cursor on the first TODO.
- Filename convention comes from the descriptor (e.g., `<date>-NN-pensive-<slug>.md` for pensives).

### Descriptor format — open design question

Three candidates, want to settle this before the first prototype gets a descriptor:

1. **Embedded fenced YAML** in the prototype (e.g., a ` ```parley ` code block). Single source of truth, diffable, no extra files. Parley parses markdown to extract.
2. **JSON sidecar** at `<prototype>.parley.json`. Easy to parse, no markdown awareness needed. Two files per type.
3. **Lua sidecar** at `<prototype>.parley.lua`. Native to nvim, lets the descriptor express dynamic behavior (e.g., a function for slug extraction). Two files per type and it's executable code.

Lean: (1) for static cases, with an escape to (3) when a type genuinely needs computed behavior. Decide on the first descriptor PR.

### Cross-repo

Datatypes can reference instances across repos (e.g., `brain/data/project/charon-launch-push.md` references `charon#13`). Super-repo mode (#114) is the surface that makes this navigable from a single parley session. This issue assumes #114 lands or progresses in parallel; cross-repo navigation is not solved here.

## Plan

- [ ] design discussion: pick descriptor format (1/2/3 above)
- [ ] write the descriptor into one prototype as a pilot — likely `pensive` (small, well-defined)
- [ ] parley: descriptor parser + type registry
- [ ] parley: typed picker, wire to `<C-g>m`; preserve `<C-g>M`
- [ ] parley: "new instance" command using template
- [ ] roll descriptor into remaining prototypes
- [ ] update `construct/datatype/type.md` (the meta-prototype) so future prototypes ship with a descriptor by default

## Revisions

### 2026-06-11 — readonly-discovery framing; registry is multi-source + composed; descriptor leans structured

Reason: a brain design conversation settled parley's direction as a **readonly**
research/exploration harness, with *discovery* as the narrow, conflict-free
slice it borrows from a repo's agent substrate. Deltas to this issue:

- **The registry is multi-source — not just `construct/datatype/`.** The
  discovery surfaces a research chat most wants — `issue`, `chat`, `note`,
  `vision`, `atlas` — are exactly the ones *not* modeled as datatype prototypes
  (`issue` lives in `sdlc issue`, chat/note/vision are parley-native, atlas is a
  convention). So the type registry draws from datatype descriptors **+** the
  `sdlc issue` contract **+** parley-native types **+** atlas. The
  descriptor-per-prototype is *one* source of the registry, not the whole.
- **Base ∪ local composition** (resolves the global / repo / super-repo modes).
  Parley ships a *universal base registry* (chat/note/prose/pensive — types any
  repo has); a repo declares only its *local delta* (its novel types); effective
  = base ∪ local. Local discovery shrinks to the delta and is grep-cheap:
  `rg -o '^type: \w+' | sort -u` minus the base. Global mode = base-minus-repo
  types; super-repo = union of siblings' deltas over the shared base. The
  hard-coded finders become the base registry's entries.
- **Descriptor format leans option 1 (structured / machine-readable), and it
  must be parseable, not prose** — so the assembler is deterministic and a
  future indexer can emit it.
- **Decouple the registry *interface* from its *production*.** The consumer reads
  a registry abstraction; production is grep now and, later, a `datatype`
  lifecycle binary maintaining an index as a write-side byproduct (loom/cloth).
  Same interface, swappable producer — so this issue can ship grep-backed and
  graduate without reworking the consumer.
- **The registry's consumer is a virtual `repo_discovery` skill** (parley.nvim#128).
  The noun-vocabulary is assembled into an always-on, read-only skill in repo
  mode — the merge point between a repo's borrowed substrate and parley's own
  (situational facts only, so conflict-free). Description framing: *"what file
  types (nouns) exist in this repo and how to find their instances."*
- **Write-side stays valid.** #116's scaffolding (template new-instance creation)
  is *human-driven manual* creation — consistent with the readonly-*agent*
  direction (the LLM is readonly; the human may scaffold via a template).

## Log

### 2026-04-30

Issue filed off the duality pensive. See pensive for the framing context and the open questions that motivated this.

### 2026-06-11

Brain design conversation settled product behavior for the readonly-harness
direction — see `## Revisions`. New siblings: **parley.nvim#128** (skill-system
redesign — consumes this registry as a virtual `repo_discovery` skill) and
**parley.nvim#129** (capability-based permission model). The descriptor-format
open question is narrowed toward structured/machine-readable + multi-source; the
read-side registry is now the higher-priority half (it feeds the harness),
write-side scaffolding unchanged.

Plan written: `workshop/plans/000116-discovery-registry-plan.md` — M1 registry
core (the #128 unblock) / M2 typed picker / M3 descriptor format + scaffolding.
Scope approved by operator; **descriptor-format deferred to M3** (M1 uses a
parley-shipped Lua base registry ∪ grep-discovered local `type:` values — see
source-map audit). Estimate 20h (M1 ≈ 8h). Fresh-context plan-document-reviewer
pass → Issues Found (minor/moderate), all addressed: flat test paths,
direct-plenary TDD runs (`make test-spec` is atlas-keyed, inert until Task 8),
hyphen-safe `type:` regex `[A-Za-z0-9_-]+` (`\w+` truncates `meeting-notes`),
config-derived dir globs (`ARCH-DRY`), and the filename-matcher locate-scoping
invariant (issue vs plan share the `NNNNNN-slug` pattern). M1 does NOT depend on
#115 (that's M2's `<C-g>m`). Execution: a fresh parley.nvim session runs
`sdlc claim --issue 116` → `sdlc change-code` → `superpowers-executing-plans`.

M2 scoped down (operator decision): M2 is **only** "existing finders source
their home root folder from the registry" — not a typed picker, not a generic
browser. The generic *faceted* finder (one shared UI parameterized by type;
per-type facet bars — chat `[tag]`, issue status + super-repo `{repo}`) is its
own design → **#115** (reframed; `deps: [000116]`). **Accepted simplification:**
M2 assumes each type is *homed in a folder* (the 4 existing finders are); types
whose instances *scatter* across the repo with no fixed home are NOT handled by
the finder retrofit — parley doesn't handle scatter today anyway. This is purely
a *finder/UI* limit: M1's frontmatter `Matcher` still discovers scatter types for
the agent (#128), so the readonly harness isn't bound by the M2 simplification.

Deps fixed (2026-06-11): removed **#115** from `deps` — it was circular after
#115 was reframed to the faceted finder, which now `deps: [000116]`. #116 keeps
`deps: [000114]` (super-repo, already landed). Separately, **#128's** hard dep on
#116 was dropped — only its `repo_discovery` task needs #116 **M1**; the rest of
#128 is independent (see #128 log). Operator-approved sequencing: **#116 M1 (now)
→ #128 → bridge `repo_discovery` → #129 → #116 M2/M3**.
