---
id: 000312
status: working
deps: []
github_issue:
target: review-convention
created: 2026-10-09
updated: 2026-10-09
estimate_hours:
card_mirror: 'ac40debd10f1e31534e69777d1e6ebba4fe78a9f' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-09T16:15:36-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
---

# First-class review comments: conceal markers + thread float

## Problem

`🤖[]{}` review markers sit raw in the prose. Once a chain grows past a turn or
two, the document becomes hard to read: the conversation drowns the text it is
about.

## Spec

Make markers first class in every markdown buffer: the buffer text is
unchanged (the file stays the contract with xx-fix / agents / pair), only the
*view* changes.

**Rendering — one rule: visible text stays visible, the chain hides behind `…`;
`<CR>` on any marker opens the thread float.**

| Raw | Shown as |
|---|---|
| `🤖[H]…` | `🤖[…]` |
| `🤖{N}…` | `🤖{…}` |
| `🤖<X>[…]…` / `🤖<X>{N}…` | `X` highlighted |
| `🤖~D~…` / `🤖~D~{N}…` | `D` highlighted + strikethrough |

**Single-line markers.** A marker never spans lines in the raw file; newlines
inside a turn are encoded as `<br>`. All writers (float write-back, `Alt+q`,
agents via the grammar) obey it. A pre-existing multi-line marker (#125 made
the parser tolerate them) is left raw + gets a diagnostic, not rendered.
Payoff: markers are line-local, so re-render touches only changed lines.

**Edit protection — hidden bytes behave as one glyph.**
1. Cursor snap: `CursorMoved` inside hidden bytes jumps to the span edge.
2. Overlap guard: a buffer-attach callback reverts an edit that *partially*
   overlaps a hidden span (with a notice); an edit covering the whole marker
   (`dd`, deleting a sentence) is intentional and passes. Visible `X`/`D` is
   ordinary prose and stays editable.

**Thread float — a focused plain nvim buffer.** One turn per line with its
brackets kept (`[…]` / `{…}`), wrapped, human/robot turns on distinct
background colors; cursor lands in an empty trailing `[]`. Full nvim, no new
actions (existing `Alt+a`/`Alt+r` unchanged). On close/write: join turns to one
line, encode newlines as `<br>`, replace the marker span; drop an empty
trailing `[]`. The float re-parses with the same tokenizer (no second parser).
The "only edit the last line" rule is convention, not enforced.

**Grammar change.** Single-line + `<br>` escape go into the `review-convention`
target (canonical in `../ariadne/construct/local/fix/review-convention.md`)
as a `## Revisions` entry.

**Out of scope (follow-ups):** consecutive human turns (`[][]{}[]`, multiple
humans); comments in non-markdown files; "ask agent" from the float.

## Done when

- In any markdown buffer, each marker form renders per the table; `<CR>` on it
  opens the float; outside a marker `<CR>` is untouched.
- Cursor cannot enter hidden bytes; partial-overlap edits are reverted,
  whole-marker deletes pass; tests cover both.
- Float round-trips: open → reply (multi-line) → close writes a single-line
  marker with `<br>`, byte-identical elsewhere; empty reply leaves the buffer
  unchanged.
- Multi-line markers stay raw with a diagnostic.
- Re-render is incremental by changed lines (test or trace shows no
  whole-buffer reparse on a single-line edit).
- `review-convention` target carries the revision; atlas updated.

## Plan

Durable plan: `workshop/plans/000312-first-class-review-comments-plan.md`.

- [ ] M1 — compact rendering (view.layout → conceal in the decoration provider), broken-marker highlight, `concealcursor=nc` + normal-mode cursor snap (plan Tasks 1–6)
- [ ] M2 — thread float with single-line `<br>` write-back, `<CR>` binding, single-line writers + `<br>` decode on resolve/gather, ariadne grammar revision, atlas (plan Tasks 7–11)

## Log

### 2026-10-09
- Brainstormed with operator; decisions in the plan's "Decisions folded in".
- Tension found: #125 deliberately made the parser multi-line tolerant. Resolution: parser keeps it (legacy docs, accept/reject, drill-in); view + writers go single-line; legacy multi-line markers paint `ParleyReviewBroken`.
- Canonical grammar lives in `../ariadne/construct/local/fix/review-convention.md` → revision via an ariadne issue (plan Task 11).
