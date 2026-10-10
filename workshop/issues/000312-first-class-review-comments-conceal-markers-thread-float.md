---
id: 000312
status: working
deps: [ariadne#316]
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
Revisions). Markers stay hidden in every mode (`concealcursor=nvic` while the
cursor is on a marker line; the window's own value elsewhere, so other conceals
are unaffected); the cursor never rests on hidden marker text (snap on
`CursorMoved`/`CursorMovedI`: no hidden byte in normal mode; in insert mode
only before the 🤖, after the marker, or inside the visible anchor), so
commands and typing can't target hidden text. An edit that still reaches hidden
bytes from a visible edge breaks the marker, which then renders raw + a broken
highlight (fail-visible); `u` restores. Visible `X`/`D` is ordinary prose and
stays editable.

**Thread float — a focused plain nvim buffer.** One turn per line with its
brackets kept (`[…]` / `{…}`), wrapped, human/robot turns on distinct
background colors; cursor lands in an empty trailing `[]`. Full nvim, no new
actions (existing `Alt+a`/`Alt+r` unchanged). Plain nvim write/quit semantics
(revised, see Revisions): `:w` joins turns to one line, encodes newlines as
`<br>` (a literal `<br>` as `\<br>`) and replaces the marker span; `:x` / `q`
write and close; `:q!` discards; a window closed otherwise with unsaved edits
keeps its text in the unnamed register. An empty trailing `[]` is dropped.
Only turn text is encoded/decoded — an anchor's X / D is the document's own
prose, kept verbatim. Accepted migration edge: a turn written before this
grammar that already holds a literal `<br>` decodes to a line break on accept
(rare; the escape has one home in `comment/codec.lua`). The float re-parses with the same tokenizer (no second parser).
The "only edit the last line" rule is convention, not enforced.

**Grammar change** (ariadne#316, closed on its branch; merge pending). Single-line + `<br>` escape go into the `review-convention`
target (canonical in `../ariadne/construct/local/fix/review-convention.md`)
as a `## Revisions` entry.

**Out of scope (follow-ups):** consecutive human turns (`[][]{}[]`, multiple
humans); comments in non-markdown files; "ask agent" from the float.

## Done when

- In any markdown buffer, each marker form renders per the table; `<CR>` on it
  opens the float; outside a marker `<CR>` is untouched.
- Cursor cannot rest on hidden bytes in normal or insert mode; a partial edit
  that breaks a marker renders it raw + `ParleyReviewBroken`; tests cover both.
- Float round-trips: open → reply (multi-line) → `:w` (or `:x` / `q`) writes a
  single-line marker with `<br>`, byte-identical elsewhere; repeated `:w` keep
  writing; `:q!` and a no-edit close leave the buffer unchanged.
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

- [x] M1 — compact rendering (view.layout → conceal in the decoration provider), broken-marker highlight, `concealcursor=nvic` on marker lines + cursor snap in every mode (plan Tasks 1–6)
- [x] M2 — thread float with single-line `<br>` write-back, `<CR>` binding, single-line writers + `<br>` decode on resolve/gather, ariadne grammar revision, atlas (plan Tasks 7–11)

## Log

### 2026-10-09
- 2026-10-09: closed M2 — Unit: codec (incl. \<br> escape), thread 11/11 (round-trip property incl. escaped <br>; existing empty [] reused as reply slot; {R}[] kept), view, drill_in (turn-only decode; anchors verbatim). Integration: comment_float_spec 12/12 (open, :w one-line <br> write-back, repeated :w (BR-13), fresh <M-q> marker no doubled turn (BR-19), no-edit close untouched, stale marker refused + register, unbalanced refused, q save+close / :q! discard, free-standing chain, <CR> on marker vs native incl. count, <M-q> multi-line refused), keybinding_agreement 35/35, buffer_mutation, arch sweeps 25/25. deps: ariadne#316 (BR-16). make test green bar 3 load-sensitive specs that pass alone. Visual check pending operator.; review verdict: SHIP
- 2026-10-09: closed M1 — Unit: comment_codec/view specs (33 view cases incl. property test over 3000 generated lines; insert-point snap; multibyte left snap). Integration: comment_render_spec (conceal + anchor hl in markdown and chat, broken marker, fenced code skipped, viewport bound 61 layout calls/frame on 5000 rows before and after an edit), comment_attach_spec (concealcursor nvic only on marker lines, user value elsewhere, restored on BufLeave; snap normal+insert). Neighbor specs green (highlighting, highlighter_document, keybinding_agreement, entity_textobj, drill_in, highlighter). BR-3 fixed. Visual check pending operator.; review verdict: FIX-THEN-SHIP
- Brainstormed with operator; decisions in the plan's "Decisions folded in".
- Tension found: #125 deliberately made the parser multi-line tolerant. Resolution: parser keeps it (legacy docs, accept/reject, drill-in); view + writers go single-line; legacy multi-line markers paint `ParleyReviewBroken`.
- Canonical grammar lives in `../ariadne/construct/local/fix/review-convention.md` → revision via an ariadne issue (plan Task 11).
- M1 implemented (Tasks 1–5): codec, view layout/snap/marker_at, shared `push_marker_decorations` (chat buffers previously rendered no markers; fenced code now skipped in both), `comment.attach` (`conceallevel=2`, `concealcursor=nvic`, snap on CursorMoved/CursorMovedI). Viewport-bound evidence (comment_render_spec): 5000-row buffer, layout calls per frame = 61 (41 drawn rows + 20 margin) before and after a one-line edit.
- Full `make test`: all green except `tests/arch/single_source_sweeps_spec.lua` "every symbol the plan tables name exists" → `open_thread`, the M2 float entry point not yet written (expected until M2).
- Visual check NOT automated: an embedded nvim (`--embed` + `nvim_ui_attach` from a `-l` driver) exits on UI attach, and `--listen` sockets are sandbox-blocked; extmark conceal geometry is asserted via the decoration provider instead. Operator visual check pending.
- Known limit: lines longer than the per-row read budget are decorated by chunk; a marker straddling a chunk edge paints broken (same constraint the old per-line highlight had).
- M2 implemented: thread.to_lines/from_lines (round-trip property over generated markers), comment.float (focused nvim buffer; :w writes back one line; :x/q write+close; :q! discards; unsaved close keeps text in "), <CR> native override (honors default_keymaps=false; stale-override arch guard now reads the `where` module), <M-q> refuses multi-line, <br> decoded in TURN text only (anchors verbatim), literal <br> escaped as \<br> (ariadne#316 BR-6).
- Grammar: ariadne#316 closed on its branch (review-convention §3/§5 + xx-fix SKILL.md single decode definition); not merged yet — parley's weaved `.agents/skills/xx-fix/review-convention.md` updates on the next weave after it lands.
- Full `make test` green except load-sensitive cliproxy_auth_login / packaging_vm / branch_child (each passes alone: 21/21, 17/17, 63/63).
- Measured actual is low (0.75h total at M2) relative to the session — recorded as measured, not adjusted.
- M2 boundary review round 1 (REWORK): BR-13 Critical — a second `:w` in the float was always refused (rewriting the row dropped the tracking extmark's column) → re-anchor after each write, test added; BR-14 this Log had been spliced into the Spec (fixed); BR-15 Spec/plan synced to plain write/quit semantics + anchors verbatim; BR-16 legacy literal `<br>` in turn text → recorded as the accepted migration edge in Spec.

## Revisions

- **2026-10-09** — edit protection: dropped the partial-edit revert guard in
  favor of snap-in-every-mode + fail-visible (operator: "works good enough";
  markers never reveal raw since `concealcursor=nvic`). Done-when's
  re-render criterion restated as viewport-bounded (the decoration provider's
  real cost model) with a concrete test.
- **2026-10-09** — M1 boundary review BR-3: `concealcursor=nvic` is scoped to
  lines carrying a rendered marker (window's own value elsewhere, re-read when
  not forcing, restored on `BufLeave`); insert-mode snap reasons about
  insertion points, so typing just before a quoted marker stays outside it.
- **2026-10-09** — M2: the float follows plain nvim write/quit semantics
  (no auto-write on close — `:q!` must be able to discard; unsaved closes keep
  their text in `"`), only turn text is `<br>`-decoded (anchors verbatim,
  ariadne#316 BR-1), and a literal `<br>` in a turn is `\<br>` (ariadne#316
  BR-6). Pre-grammar turns holding a literal `<br>` are an accepted edge.
