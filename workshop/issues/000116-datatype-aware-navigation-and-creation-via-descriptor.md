---
id: 000116
status: open
deps: [000114, 000115]
created: 2026-04-30
updated: 2026-04-30
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
- `<C-g>m` becomes the typed-picker entry point; `<C-g>M` keeps the existing depth-bounded markdown search as escape hatch.
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

## Log

### 2026-04-30

Issue filed off the duality pensive. See pensive for the framing context and the open questions that motivated this.
