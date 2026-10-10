---
id: 000312
status: working
deps: []
github_issue:
target: review-convention
created: 2026-10-09
updated: 2026-10-09
estimate_hours: 4.88
card_mirror: '5d13b7a45ae62416e28aaa425bd84b67a701e2af' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-09T16:15:36-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: full, provenance: inferred}
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
the parser tolerate them) is left raw + painted `ParleyReviewBroken`, not rendered.
Payoff: markers are line-local, so re-render touches only changed lines.

**Edit protection — hidden bytes behave as one glyph** (revised, see
Revisions). Markers stay hidden in every mode (`concealcursor=nvic`); the
cursor never rests on a hidden byte (snap on `CursorMoved`/`CursorMovedI`), so
commands and typing can't target hidden text. An edit that still reaches hidden
bytes from a visible edge breaks the marker, which then renders raw + a broken
highlight (fail-visible); `u` restores. Visible `X`/`D` is ordinary prose and
stays editable.

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
- Cursor cannot rest on hidden bytes in normal or insert mode; a partial edit
  that breaks a marker renders it raw + `ParleyReviewBroken`; tests cover both.
- Float round-trips: open → reply (multi-line) → close writes a single-line
  marker with `<br>`, byte-identical elsewhere; empty reply leaves the buffer
  unchanged.
- Multi-line markers stay raw, painted `ParleyReviewBroken`.
- Re-render is viewport-bounded: a test on a 5000-line buffer shows a redraw
  after a one-line edit calls the marker layout only for viewport rows.
- `review-convention` target carries the revision; atlas updated.

## Estimate

*Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against `baseline-v3.1.md`. Method A only.* Two Lua/Neovim features (M1 render+snap, M2 float+write-back+writers), design ×0.2 for the pre-resolved durable plan; a UX iteration round budgeted for visual tuning after the first manual look.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec                 design=1.0 impl=0.1
item: lua-neovim                 design=0.4 impl=0.6
item: lua-neovim                 design=0.4 impl=0.6
item: cross-repo-refactor-small  design=0.1 impl=0.1
item: atlas-docs                 design=0.1 impl=0.08
item: milestone-review           design=0.0 impl=0.2
item: milestone-review           design=0.0 impl=0.2
item: ux-rename-iteration        design=0.5 impl=0.12
design-buffer: 0.15
total: 4.88
```

## Plan

Durable plan: `workshop/plans/000312-first-class-review-comments-plan.md`.

- [ ] M1 — compact rendering (view.layout → conceal in the decoration provider), broken-marker highlight, `concealcursor=nvic` + cursor snap in every mode (plan Tasks 1–6)
- [ ] M2 — thread float with single-line `<br>` write-back, `<CR>` binding, single-line writers + `<br>` decode on resolve/gather, ariadne grammar revision, atlas (plan Tasks 7–11)

## Log

### 2026-10-09
- Brainstormed with operator; decisions in the plan's "Decisions folded in".
- Tension found: #125 deliberately made the parser multi-line tolerant. Resolution: parser keeps it (legacy docs, accept/reject, drill-in); view + writers go single-line; legacy multi-line markers paint `ParleyReviewBroken`.
- Canonical grammar lives in `../ariadne/construct/local/fix/review-convention.md` → revision via an ariadne issue (plan Task 11).

## Revisions

- **2026-10-09** — edit protection: dropped the partial-edit revert guard in
  favor of snap-in-every-mode + fail-visible (operator: "works good enough";
  markers never reveal raw since `concealcursor=nvic`). Done-when's
  re-render criterion restated as viewport-bounded (the decoration provider's
  real cost model) with a concrete test.
