---
id: 000124
status: working
deps: []
target: review-convention
created: 2026-05-23
updated: 2026-05-23
---

# Align marker grammar and bindings with review-convention target

The canonical review-convention spec now lives at
`../ariadne/workshop/targets/review-convention.md`. Parley.nvim is the
human-side marking surface for that convention but its current
implementation diverges in three places:

1. **No `~X~` family.** The spec defines `🤖~D~`, `🤖~D~{N}`, `🤖~D~[N]` for
   deletion / replacement. Parser, drill_in, and highlighter have no
   notion of strikethrough markers today.

2. **No accept/reject split.** Spec §5 distinguishes `<M-a>` (accept) from
   `<M-r>` (reject) with a 10-row resolution table where the two gestures
   have asymmetric outcomes for the `~D~` family. Today's `<M-r>` is a
   single bulk "accept-ish resolve" — no reject path, no per-marker
   accept.

3. **Inconsistent `<M-q>` insertion.** Drill-in produces `🤖<sel>[]`
   (empty `[]`). The review skill's separate `<C-g>vi` produces
   `🤖[selected]` (no `<>` ref, selection inside `[]`). Spec wants one
   canonical form: `🤖<sel>[ ]` on selection, `🤖[ ]` without.

Per operator direction (this session): no backwards-compatibility for the
`<M-r>` semantic shift; bulk-resolve gets dropped entirely; redundant
review-skill insertion bindings (`<C-g>vi`, `<C-g>vr`) get retired in
favor of `<M-q>` as the single insertion path.

## Done when

- Parser recognizes `🤖~D~`, `🤖~D~{N}`, `🤖~D~[N]` (single tilde,
  non-nesting). `<X>` and `~X~` are mutually exclusive — only one
  reference slot per marker.
- Highlighter renders `~X~` content with strikethrough (custom; we own
  the rendering, not relying on markdown-renderer defaults).
- `<M-q>` (and `<C-g>q`) produces `🤖<selected>[ ]` on visual selection,
  `🤖[ ]` without selection. Cursor lands inside the `[ ]`.
- `<M-a>` (new keybinding) accepts the marker under cursor per spec §5.
- `<M-r>` (existing keybinding, repurposed) rejects the marker under
  cursor per spec §5.
- The 10-row accept/reject table from spec §5 is implemented and tested
  end-to-end (parse → resolve → resulting text matches).
- Bulk-resolve binding (`<C-g>r`, second slot of `<M-r>`) is removed.
- `<C-g>vi` and `<C-g>vr` are removed from config and keybinding
  registry. Their handlers in `lua/parley/skills/review/init.lua` are
  removed.
- Tests cover all marker forms in §3 of the spec and all rows of the
  resolution table.
- `lua/parley/skills/review/SKILL.md` updated with the new grammar.
- Atlas entry for marker grammar updated to reference the canonical
  target.

## Plan

Detailed design in
[`workshop/plans/000124-review-convention-alignment-plan.md`](../plans/000124-review-convention-alignment-plan.md).

### M1 — `~X~` parser + highlighter

- [ ] Extend `parse_marker_sections` (`lua/parley/skills/review/init.lua`)
      to accept `~X~` as an alternative first-slot reference, mutually
      exclusive with `<X>`. Surface as `{ kind = "delete", text, ... }`
      vs. `{ kind = "quote", text, ... }`.
- [ ] Update `drill_in.parse` to expose the reference kind.
- [ ] Add highlighter rule for `~X~` content rendering as strikethrough.
- [ ] Tests: parse `🤖~D~`, `🤖~D~{N}`, `🤖~D~[N]`, plus negative cases
      (`<X>~Y~`, `~X~<Y>` rejected).

### M2 — Accept/reject split + table-driven resolution

- [ ] Add `accept_at(text, offset)` and `reject_at(text, offset)` in
      `drill_in.lua` implementing spec §5's 10-row table.
- [ ] Wire `<M-a>` keybinding (new entry in `keybinding_registry.lua`,
      handler in `init.lua` parallel to `drill_in_resolve_at_cursor`).
- [ ] Repurpose `<M-r>` handler: replace `resolve_all` call with a
      `reject_at(...)` cursor-relative call. Drop the second key slot
      `<C-g>r`.
- [ ] Delete `drill_in.resolve_all` and `drill_in_resolve` (the bulk
      handler). Delete `chat_resolve_drill_in` registry entry.
- [ ] Tests: every row of the 10-row table, both accept and reject.

### M3 — `<M-q>` normalization + retire review-skill insertion

- [ ] Fix `<M-q>` insert path: drill-in's `wrap` already produces
      `🤖<text>[]` (matches spec). Insert path (`drill_in_insert`)
      already produces `🤖[]`. Adjust both so the cursor lands inside the
      bracket consistently — current `<M-q>` may diverge slightly from
      spec on cursor position; verify and align.
- [ ] Remove `<C-g>vi` from `keybinding_registry.lua` (review_insert)
      and `config.lua` (review_shortcut_insert).
- [ ] Remove `<C-g>vr` from `keybinding_registry.lua`
      (review_insert_machine) and `config.lua`
      (review_shortcut_insert_machine).
- [ ] Remove the corresponding handler block in
      `lua/parley/skills/review/init.lua` (lines ~437-505).
- [ ] Update `lua/parley/skills/review/SKILL.md` with the new grammar
      and binding set.
- [ ] Update atlas entry mentioning marker grammar to point at the
      canonical target.

## Log

(populated during implementation)
