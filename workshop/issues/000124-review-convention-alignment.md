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

### M1 — `~X~` parser + highlighter ✅

- [x] Extend `parse_marker_sections` (`lua/parley/skills/review/init.lua`)
      to accept `~X~` as an alternative first-slot reference, mutually
      exclusive with `<X>`. Surfaced as parallel `quoted` / `strike`
      fields (one or neither set) — see plan doc for the rationale on
      separate fields vs. a unified `ref` with `kind`.
- [x] Update `drill_in.parse` to expose `strike`.
- [x] Add highlighter rule (`ParleyReviewStrike`, `strikethrough=true`)
      and scan branch in the highlighter loop.
- [x] Tests: parse `🤖~D~`, `🤖~D~{N}`, `🤖~D~[N]`, multi-line, empty-strike
      normalization, unclosed-strike malformed, both directions of `<X>` ↔
      `~X~` mutual exclusion. Also: `gather_and_strip` skips strike-only
      markers, even those with trailing `[N]`.

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

**2026-05-23 — M1 close.** Parser, drill_in, highlighter, and atlas
entry updated for the `~X~` family. 12 new tests in drill_in_spec
(parse + gather), all green. Full unit + integration suite green
(`make test-unit && make test-integration`), lint clean. Highlighter
visual verification deferred to operator — `ParleyReviewStrike` group
defined with `strikethrough=true` and applied to byte range of the
`~X~` content.

Design tweak from the original plan: keep parallel `quoted` / `strike`
fields (mutually exclusive) rather than a unified `ref` with `kind`.
Rationale captured in plan doc — less invasive to existing tests, reads
more naturally at call sites.

**2026-05-23 — M1 code review (post-commit follow-up).** Dispatched
general-purpose reviewer on diff `0c2cfa5..f273941`. Three Important
findings, all addressed:

1. *Greedy strike lexer false-positives.* `🤖~old code` followed by
   `~/path` later on the same line silently bound the path tilde as the
   closer. Bounded strike to single-line — multi-line strike rejected
   (operator marks each line separately if needed). Within-line first-`~`
   wins is documented as a known gotcha with a pinning test.

2. *`resolve_at` / `resolve_all` silently mishandled strike.* `🤖~D~{N}`
   would have been silently rewritten to `N` by the existing
   pending-path code, pre-empting M2's deliberate accept gesture. Gated
   strike out of both — they're no-ops until M2 ships the table-driven
   resolution.

3. *Test gaps.* Added: false-positive pinning (`🤖~old~/path~` → only
   `old`), byte_end pin, back-to-back strike markers, resolve_at /
   resolve_all gating tests, code-fence skip for strike, and the
   never-ready assertion in review_spec.

Two Nits also addressed: top-of-file grammar comment in drill_in.lua
updated to include the strike branch; atlas `drill_in.md` got a TBD
note pointing at M2 for resolution semantics. Test count up from 58 to
66 in drill_in_spec, +2 in review_spec. All green.
