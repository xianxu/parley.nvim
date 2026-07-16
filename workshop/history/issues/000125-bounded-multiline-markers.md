---
id: 000125
status: done
deps: []
target: review-convention
created: 2026-05-30
updated: 2026-05-30
actual_hours: 4
---

# Bounded multi-line review markers

## Spec

Today `parse_markers` (lua/parley/skills/review/init.lua) is **line-bounded**:
`find_matching_bracket` only scans within a single line's string. When a
`🤖`-marker's opening `{` / `[` / `<` has no matching close on the *same* line,
the section is discarded and the `🤖` is silently not recognized as a marker — so
it never reaches the quickfix.

This bit us in the wild: `brain/atlas/threat-model-shared-brain.md:252` had an
agent proposal

```
### 🤖{2026-05-29 — local-only brains + topology ladder (`nous#33`)

`nous brain new` now provisions ... brain-topology-ladder.md`.}
```

The `{` opens on the heading line and closes three lines down at the end of the
body paragraph. The whole header+paragraph is one `🤖{Y}` (an *add-this*
proposal per the review-convention inline-marker grammar). Because the `{` is
unmatched on line 252, the marker vanished from the quickfix and was only found
by chance. The `###` heading was incidental — the same `🤖{` spanning two body
lines vanishes identically.

**Goal:** let a marker's `{}` / `[]` / `<>` sections span multiple lines, so
terminated multi-line / multi-paragraph proposals parse and surface in the
quickfix — **without** letting a stray opener swallow the rest of the document.

### Decisions (settled with operator)

1. **Bounded, not unbounded.** The single-line bound is currently load-bearing:
   it caps the blast radius of a stray `🤖{`. Removing it entirely trades a
   bounded failure (one ruined line) for an unbounded one (a typo'd brace eats
   to EOF). So: span lines, but **cap the close-search at an N-line ceiling**
   (default 50) + EOF.
2. **No structural terminators.** Not "stop at next heading" (proposals open on
   and contain headings — see the real case). Not "stop at next 🤖" (proposals
   about the review convention contain 🤖 in their prose). Only the line ceiling
   + EOF bound the search.
3. **`~~` strike stays single-line.** Tildes are common in prose (`~/path`, math
   `~`); a multi-line greedy `~` match would absorb arbitrary text. This was a
   deliberate existing choice (init.lua:79) and is preserved.
4. **No "malformed marker" surfacing.** An unterminated opener (no close within
   the bound) **falls back to today's behavior** — the opener simply isn't
   recognized as a marker. A quickfix entry pointing at an orphaned brace would
   nag without helping the human fix it.
5. **Fence / inline-code aware.** A `{`/`}` inside a fenced code block or inline
   code span must not open/close a multi-line marker. (Already true per-line;
   must hold across lines now.)

### Non-goals

- Multi-line highlighting. The highlighter (highlighter.lua) is viewport-range
  based and stays single-line for now; a multi-line marker just won't fully
  paint across lines. Tracked as a follow-up, not in this issue.
- Changing drill_in's behavior. drill_in (`_parse_marker_sections` caller) keeps
  its current single-line semantics — multi-line is opt-in via a new param that
  drill_in does not pass.

## Plan

Per lesson #7: `_parse_marker_sections` is shared by 3 callers
(`parse_markers`, highlighter.lua:432, drill_in.lua:79). The multi-line
capability is added as an **optional opt-in** so existing callers are unchanged.

- [x] **M1 — multi-line matcher (TDD, pure).**
  - [x] `find_matching_bracket(text, start, open, close, opts)` — opts.budget
        (newline ceiling, nil = unlimited) + opts.is_excluded(offset). No opts →
        historical unbounded single-text behavior (drill_in relies on this).
  - [x] `parse_marker_sections(text, pos, byte_len, opts)` threads opts to the
        matcher for `<>`/`[]`/`{}`; `~~` strike stays single-line (opts-independent).
  - [x] 11 new tests in review_spec.lua: terminated multi-line `{}`/`[]`/`<>`;
        the `nous#33` header+blank+paragraph shape; nested braces across lines;
        unterminated → not recognized; runaway guard (close > budget away);
        `}` inside fence + inside inline-code does not close; `~~` single-line;
        two markers (first multi-line) both found; per-section budget pin.
- [x] **M2 — wire `parse_markers` to multi-line.**
  - [x] Joined `doc` + binary-search `offset_to_pos` + sorted excluded-range set
        (fenced lines whole + per-line `inline_code_ranges`). Scan `🤖` over doc,
        skip excluded openers, call `parse_marker_sections` with
        `{ budget = MULTILINE_LINE_BUDGET (50), is_excluded }`.
  - [x] Regression: all 41 existing review_spec tests pass; full unit suite green.
  - [x] End-to-end: `skill.pre_submit` on the `nous#33` shape → 1 quickfix entry
        at the opener heading line (lnum=3). Removed now-dead `in_inline_code`.
- [x] **M3 — confirm callers unaffected + docs.**
  - [x] highlighter.lua (per-line) + drill_in.lua (multi-line, unbounded) pass no
        opts → unchanged. drill_in_spec 76/76, dispatcher 53/53 green. Per lesson
        #7, both call sites grep-confirmed to pass 3 args (no opts).
  - [x] SKILL.md "Marker syntax" + atlas/modes/review.md updated (multi-line
        bounded per-section; `~~` single-line).
  - [x] Fresh-eyes code review (general-purpose subagent) — see Log.

## Log


- 2026-05-30: closed — review_spec 52/52 + full test-unit + lint green; nous#33 multi-line marker surfaces as 1 quickfix entry via pre_submit; fresh-eyes review (one pass over full diff) found no Critical/Important. FORCE: M1-M3 executed as one atomic diff in a single session with one combined fresh-eyes review rather than three separate milestone-close commits — no intermediate review boundary existed to gate.
- 2026-05-30: Root-caused from `threat-model-shared-brain.md:252`. Verified
  against checkout that single-line `## 🤖{…}` parses fine in all paths
  (parse/populate/pre_submit/highlighter + 8 header edge cases) — the failure
  was specifically the **multi-line** span, not header position. Operator chose
  bounded multi-line over malformed-surfacing.
- 2026-05-30: Implemented M1–M3 (whole-doc parse). Verification:
  review_spec 52/52, full `make test-unit` green, `make lint` 0 warnings.
  E2E: `nous#33`-shaped multi-line marker now surfaces as 1 quickfix entry at
  the opener heading line via `pre_submit`.
- 2026-05-30: **Code review** (fresh-eyes subagent) — no Critical/Important.
  All 6 invariants verified (callers unaffected, no runaway [linear O(n×budget),
  50/51-line boundary exact], offset→col matches old byte-based `pos-1`,
  exclusion math + sorted early-break valid, search advancement, multibyte-safe).
  Findings: (Minor) pathological-input perf on adversarial bracket-heavy docs —
  `is_excluded` could binary-search; not worth fixing, real buffers unaffected.
  (Nit) budget is per-section not per-marker — corrected comment + SKILL.md +
  atlas wording and added a pinning test (`budget is per-section …`).
