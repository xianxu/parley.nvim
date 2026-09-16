---
id: 000262
status: working
deps: []
github_issue:
created: 2026-09-16
updated: 2026-09-16
estimate_hours: 2.57
started: 2026-09-16T12:23:08-07:00
---

# Delete entity at cursor — markdown section, paragraph, or chat question

## Problem

Editing chat transcripts and markdown notes requires frequent deletion of
larger-than-line units: a whole markdown section under a heading, a blank-line
delimited paragraph, or an entire chat question (💬: block plus its answer).
The stock Vim `dap` (delete a paragraph) works for blank-line paragraphs but
is not discoverable for light Vim users, does not handle markdown section
ranges, and does not know about Parley's question/answer structure. There is
no single quick command that does the right thing based on where the cursor
is.

## Spec

Provide a single quick command — **delete entity at cursor** — that deletes
the entity the cursor is currently inside, with context-aware dispatch:

- **Markdown section:** when the cursor is on a markdown section title
  (an ATX heading in the repo's dialect — column-zero, one to three hashes,
  see Revisions), delete that entire section: from the heading
  line through to (but not including) the next heading of equal or higher
  level (`#` rank ≤ current), or end-of-file. Preserve a single blank line
  between the surrounding content where appropriate. Must handle nested
  subsections (they are contained inside the deleted range).

- **Paragraph:** when the cursor is inside a blank-line-delimited paragraph
  (outside a heading and outside a chat question), delete that paragraph.
  This is the `dap`-equivalent for users who don't know `dap`. The range is
  the contiguous non-blank lines bounded by blank lines or file/section
  boundaries, matching Vim's paragraph text-object semantics.

- **Chat question:** when the cursor is on or inside a question block
  (a `💬:` turn as parsed by `chat_parser.lua`, including its `question`
  lines and any associated answer until the next `💬:` or EOF), delete that
  entire exchange/question. Reuse the parser's `find_exchange_at_line` /
  exchange span (`question.line_start` → `answer.line_end` or
  `question.line_end`) so the deletion is structurally correct and does not
  leave orphaned answer text.

Nothing at or above the transcript's `---` separator is an entity: the header
is metadata, and `# topic:` would otherwise be a level-1 heading that nothing
outranks, so a section from line 1 would take the whole file.

Precedence when the cursor could match multiple entities: question > section
title > paragraph. A cursor on a heading line inside a question never happens
(questions are not headings), but a cursor inside an answer that contains
markdown headings should still be treated as "inside the question" for this
command — the chat structure owns the range, not the markdown section logic.
Outside any question, heading-line detection wins over paragraph.

### Extend to end of question

A second range, sharing the same dispatch: **from the start of the entity at
the cursor through the end of the current exchange.** The start snaps backward
to the entity boundary — standing anywhere inside a paragraph deletes that
whole paragraph *and* everything after it in the question, never from the
cursor column. Standing on a heading takes that heading's section and
everything after it; standing on the 💬: line degenerates to the whole
exchange, i.e. the same result as the plain entity range.

The end is the exchange end as `chat_parser` reports it (`answer.line_end`,
else `question.line_end`) and never crosses the next `💬:`. Outside any
exchange — a plain markdown buffer, or transcript headers — the end is the
enclosing section's end, or EOF when there is no enclosing section.

This is the “I've read enough, drop the rest of this answer” case, and it is
why the *range function* is the unit of reuse rather than a delete command:
`range_at_cursor()` and `range_to_exchange_end()` share entity detection
entirely and differ only in where the range stops.

### Structural markers inside a deleted range

`chat_parser` recognizes a class of line-level structural markers inside an
answer — 📝 summary, 🧠 reasoning, 🔧 tool use, 📎 tool result, plus 🌿 branch
and 🔒 local lines (`document/lexical.lua:patterns`). Any of them can fall
inside a deleted range, so the policy is stated per marker class, not as a
special case for one emoji:

- **📝 summary — preserved.** Operator's call: after heavy editing of an
  answer the summary is no longer accurate, but it still carries structural
  information about what the exchange was, and it is what `memory_prefs.lua`
  greps out of chat files when building memory. Deletion is therefore
  *non-contiguous* — the range minus the summary line — which the
  implementation must handle explicitly (delete in descending line order, or
  rebuild the surviving lines in one `nvim_buf_set_lines` call, so undo stays
  one step). `exchange.summary.line` gives the line directly; no re-scanning.
- **🧠 reasoning, 🔧 tool use, 📎 tool result — go with the answer.** They are
  answer content and carry no meaning without the body they belong to.
- **🌿 branch links — must not be silently orphaned.** A branch line is the
  only pointer to another transcript file; dropping it strands that file.
  Decide at design time whether to preserve it like 📝, refuse the deletion,
  or warn.

**Contiguity constraint.** A text object selects one contiguous linewise
range; stock `d` then deletes all of it. So `dae` cannot skip a 📝 line that
sits *strictly inside* its range — only a dedicated command can do a
non-contiguous delete. In practice this rarely bites: `defaults.lua` instructs
the model to emit 📝: as the **last** line of the answer, after a blank line,
so preservation is normally just “end the range one line earlier”, which stays
contiguous and works with stock `d`. The rule is therefore:

- 📝 at the range edge (the common case) → the range function trims the
  boundary back; text object and hotkey behave identically.
- 📝 strictly interior (possible after heavy editing, which is exactly the
  scenario the operator described) → the text object takes the contiguous
  range including it; the `:ParleyDelete*` command and hotkey do the
  non-contiguous delete. Document the divergence rather than pretending it
  away, or reconsider whether an interior 📝 should instead be hoisted to the
  end of the surviving text.

Open question the operator flagged: preserving 📝 when the *whole* exchange is
deleted leaves a dangling summary under no question. Options — (a) preserve
uniformly, simple and consistent with “it still has structural information”;
(b) preserve only for partial deletions, drop it when the question itself
goes; (c) preserve and reattach to the preceding exchange. Resolve before
implementing; default to (a) absent a better argument.

### Surface: a text object, not a bespoke delete command

The entity definition lives in Lua as a single `range_at_cursor()` returning
`(start_line, end_line)`. Expose it as a **buffer-local text object** in
operator-pending and visual mode rather than as a one-off delete mapping —
one definition then serves every operator (`d`, `y`, `c`, `v`, `gq`, `>`),
with dot-repeat for free:

```lua
local function select_entity()
  local s, e = require("parley.entity").range_at_cursor()
  if not s then return end
  vim.cmd(("normal! %dGV%dG"):format(s, e))
end
vim.keymap.set({ "x", "o" }, "ae", select_entity, { buffer = buf, silent = true })
```

**Decided: the text object is `ae` (whole entity) and `ie` (inner — section
body without its heading, question without its answer).** `dae` deletes,
`yae` yanks, `cae` replaces, `vae` selects — one thing to remember, and it
composes with every operator the user already knows.

A literal `dE` was considered and rejected: it requires mapping `E` in `o`/`x`
mode, and `E` is a stock motion (end of WORD), so `dE`/`yE`/`cE` would be
shadowed inside Parley buffers. `ae`/`ie` follows the `a`/`i` text-object
convention and shadows nothing.

The extended range gets the capital variant: **`aE` = this entity through the
end of the question**, so `daE` deletes it, `yaE` yanks it. Shift reads as
“more”, and it keeps one letter for the whole family. No `iE` — an “inner”
variant of a range that already runs to a hard boundary has no useful meaning.

On top of the text objects, bind plain hotkeys to `dae` and `daE` for users
who don't think in text objects — registry keybindings plus discoverable
`:ParleyDeleteEntity` / `:ParleyDeleteToEnd` commands, all of which just
invoke the same two range functions. The text objects are the implementation;
the hotkeys are shortcuts to the common cases, not a second code path.

`opfunc` + `g@` is the alternative surface, needed only if a charwise or
count-aware operator is wanted later; the text object is enough for the
initial cut. Keep the mapping buffer-local to Parley chat/markdown buffers so
it never leaks into other filetypes. Deletion must be one undo step.

Consider a count (`2dae`) or a visual-selection scope in a follow-up; the
initial cut is single-entity at cursor with no extra prompt.

## Done when

- A cursor on a markdown heading deletes that heading's entire section (through
  next same-or-higher heading / EOF) in one undo step.
- A cursor inside a blank-line-delimited paragraph deletes that paragraph.
  It matches `dap` on plain prose; unlike `dap` it also stops at a heading or
  a structural marker with no blank line between, which `dap` would swallow.
- A cursor on or inside a `💬:` question deletes that whole question/answer
  exchange as defined by `chat_parser`, not just the `💬:` line.
- Precedence is question > heading > paragraph and is covered by tests.
- No range ever starts at or above the header separator, and a chat whose
  header will not parse refuses rather than silently falling back to unclamped
  markdown rules.
- The extended range deletes from the *entity* start (not the cursor column)
  through the end of the current exchange, stops at the next `💬:`, and
  degenerates to the whole exchange when invoked on the question line.
- A 📝 summary at the *edge* of a range survives it, in one undo step, when the
  question itself survives; an interior 📝, a whole-exchange delete, and
  🧠/🔧/📎/🌿/🔒 lines all go with the range (see Revisions, 2026-09-16).
- Both surfaces are byte-identical on a quiescent document, proven by a parity
  test over every cursor row in a buffer **with closed folds**; the one
  documented asymmetry is that the programmatic path inherits
  `buffer_edit.replace_user_lines`' refusal while a response is streaming and
  the native operator does not.
- `ae`/`ie` work with every operator (`d`/`y`/`c`/`v` at minimum) from the one
  range function, are buffer-local, and shadow no stock motion users rely on
  in chat buffers.
- The convenience hotkey and `:ParleyDeleteEntity` both route through that
  same range function — no duplicated range logic — and are registered,
  documented in help/atlas, and free of collisions with existing Parley
  bindings; deletion is undoable and does not leave extra blank-line artifacts
  or orphaned sections.
- Focused unit/integration tests cover section range (nested headings, last
  section to EOF, single-line section), paragraph boundaries, question span
  (with and without answer, at header), precedence, the extended range from
  each entity type, and 📝 preservation (mid-answer, last line of answer, and
  whole-exchange deletion).

## Estimate

Derived via `estimate-logic-v3.1` against `baseline-v3.1.md`, using the
repo-local calibration named by `sdlc estimate-source` (flagged stale but
canonical here). Method A only. Design hours carry v2.1's +15% buffer because
this issue has a thorough plan doc (`workshop/plans/000262-*-plan.md`);
`impl=` values are written at v3.1's 40% of the v2 primitive table.

Step 2.5 (library availability): Neovim ships no text-object framework, and
pulling one in for three objects would be heavier than the 30 lines this
needs — no shortcut to credit. The *repo* shortcuts are real, though, and the
design hours below are already discounted for them: `exchange_clipboard`
supplies the exchange range math and `keybinding_registry` supplies the
keymap surface, so neither is greenfield.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec design=0.10 impl=0.05
item: lua-neovim design=0.30 impl=0.40
item: lua-neovim design=0.15 impl=0.35
item: lua-neovim design=0.10 impl=0.45
item: cross-cutting-refactor design=0.05 impl=0.08
item: atlas-docs design=0.05 impl=0.08
item: milestone-review design=0.00 impl=0.30
design-buffer: 0.15
total: 2.57
```

Three `lua-neovim` rows: the pure core (`markdown_heading` + `entity_range`,
which owns five distinct rules), the surface (text objects, commands,
registry/config entries), and the test surface — six new spec files plus the
text-object/fold/visual-mode interaction that Task 10 itself calls invisible
to a naive test. `cross-cutting-refactor` is folding `outline.lua` onto the
shared dialect plus its conformance test; `milestone-review` covers both
boundaries.

**Revised upward from 1.98 after the estimate-quality judge (2026-09-16).**
The first cut carried six spec files inside two implementation rows and
budgeted 25% less implementation than parley#208, whose 189-line plan measured
1.81 h actual against this one's 1054 lines and 15 tasks. The judge also noted
the `issue-spec` impl of 0.02 sat below the model's own 0.04–0.12 floor at
v3.1 scale. Raised rather than defended: the comparable actuals in this repo
are #208 1.81, #227 3.35, #206 3.49, and a knowingly-low estimate is what
pollutes the calibration ledger the gate exists to protect.

## Plan

- [x] M1 — the pure range core: one `entity_range.range(parsed, lines, row,
  opts)` owning precedence, bounds, trailing-blank and 📝 policy, over a
  single shared heading dialect (`markdown_heading`) that `outline.lua` folds
  onto and the document tokenizer is pinned against. Unit-tested with no
  mocks.
- [x] M2 — the surface: `ae`/`ie`/`aE` registered as `o`/`x` maps through the
  keybinding registry, their hotkey and `:Parley*` twins, a parity test over
  every cursor row in a folded buffer, the perf measurement, traceability
  routing, and the atlas/README keys.

## Revisions

### 2026-09-16 — precedence is a line-class rule, not containment

- **Reason:** the Spec as written says a cursor anywhere inside an answer is
  “inside the question”. Every line of a chat buffer is inside some exchange,
  so read literally that makes the section and paragraph cases unreachable in
  chat buffers — and it contradicts the operator's own requirement that the
  extended range start at *paragraph* level inside an answer.
- **Delta:** precedence now dispatches on what the cursor line **is**, not on
  what contains it — `💬:` line (or its `@@tag@@` preface) → whole exchange;
  ATX heading line → that section; anything else → that paragraph. The
  containment reading survives as clamping only: a section or paragraph range
  never crosses its enclosing exchange's bounds. Settled while writing
  `workshop/plans/000262-delete-entity-at-cursor-plan.md`.

### 2026-09-16 — marker policy, heading dialect, and `dap` equivalence

Three further deviations from the Spec as first written, settled together
while the plan cleared its quality gate. Recorded as a class rather than one
at a time (ARCH-PURPOSE).

- **Reason (marker policy):** the Spec asked for a design-time ruling on 🌿 and
  defaulted the dangling-summary question to “preserve uniformly”; the operator
  ruled otherwise on 2026-09-16. It also mandated a *non-contiguous* delete
  around an interior 📝, with the divergence between the two surfaces
  documented rather than removed.
- **Delta:** 📝 is preserved only as an **edge trim**, and only when the
  question survives; interior 📝 and whole-exchange deletes take it.
  🧠/🔧/📎/🌿/🔒 are ordinary content. This removes the non-contiguous
  path entirely, which is what lets the text object and the command be
  byte-identical — a stock `d` over a text object cannot skip an interior
  line, so keeping the Spec's rule would have meant two surfaces that differ
  on the same keystroke.
- **Known tension, accepted deliberately:** `lua/parley/annotation.lua` and
  `buffer_edit.delete_answer` exist to carry 🌿/🔒 *through* a programmatic
  range delete (#214 BR-75/BR-79), and this ruling does not extend that
  protection to the new operator. The cases differ in kind: `delete_answer`
  destroys an answer the user did not ask to destroy, whereas `dae` is the
  user deleting a range they selected, with the register and `u` intact. If
  that reading is wrong, the fix is to reuse `annotation.lua` here rather than
  to write a second preservation path.
- **Reason (heading dialect):** the Spec says ATX `#` … `######`.
- **Delta:** the repo's one dialect is column-zero, one to three hashes
  (`document/lexical.lua:352`, `outline.lua`), and this feature consumes it
  rather than introducing a fourth. `#### Four` is body text and a cursor on
  it takes the paragraph. Widening to six levels is a separate change that
  moves outline and the tokenizer together.
- **Reason (`dap` equivalence):** Done-when asked for `dap` equivalence in
  tests.
- **Delta:** equivalence holds on plain prose only. The paragraph walk
  additionally stops at a heading and at a structural marker (`💬 🤖 📝 🧠
  🔧 📎 🌿 🔒`) even with no blank line between — `dap` would swallow a
  heading directly above its body, and in a transcript it would swallow the
  `💬:` line itself. Strict `dap` parity would be a bug here.

## Log

### 2026-09-16 — M1 review round 2: REWORK again, class fixed

Round 1's fix was the site, not the class — the exact failure round 1 named,
repeated one round later. Two more Criticals:

- **The floor was gated on classification.** It read `parsed.header_end`, and
  `parsed` is nil whenever `not_chat` rejects the buffer — which it does for
  five reasons unrelated to document shape (name not timestamped, fewer than
  five lines, no `topic` header…). A transcript under a non-timestamped name is
  classified markdown, still gets the text object installed, and had no floor:
  `dae` on line 1 destroyed it. Now derived from the document's own shape via a
  new pure `chat_parser.transcript_header_end(lines)`, a strict sibling of
  `find_header_end` (which returns the first `---` anywhere and would floor a
  thematic break in a genuine note).
- **The unparsable-header refusal was half-applied.** The command's guard sat
  inside `if not reason then`, unreachable exactly when needed, so the two
  surfaces gave different answers to "is this a chat?". Both now use one
  classifier.

Plus: parity now sweeps document *shape* as well as cursor row (that second
axis is where the divergence lived), and the streaming refusal is tested —
scoped to "the command propagates it and the buffer is intact", injected at the
`buffer_edit` seam, since an overlapping user capture does not reproduce it and
a live generation is heavier than the claim needs.

Honest note: I blanket-ticked all 66 plan checkboxes in the round-1 rework,
including Task 11 Step 4, whose test did not exist. The review caught it. That
step is now genuinely done.

### 2026-09-16 — M1 boundary review: REWORK, reworked

Verdict REWORK on a genuine Critical the operator's smoke test could not have
found, because it lives where nobody puts the cursor: **`dae` on line 1 of a
transcript emptied the buffer.** `# topic:` is a valid level-1 heading, nothing
outranks it, and there is no exchange above the first one to clamp against, so
the section ran to EOF. Line 2 took the `---` with it, after which every later
range lost its exchange clamp and would cross `💬:` boundaries — the one thing
the Spec forbids outright. The parity spec looped `for row = 4`, so the only
three rows where this was reachable were exactly the ones not covered, while
Done-when claimed parity "over every cursor row".

Fixed as a rule, not a patch: `entity_range` rule 6 floors every range at
`parsed.header_end + 1`, derived from the parse rather than threaded through
`opts` so no caller can forget it. Parity now runs `for row = 1`, and a
separate regression asserts line 1 is a **no-op** — parity alone would not have
caught it, since both surfaces agreed on deleting everything.

Also addressed from the same review:

- `parsed_for` no longer collapses "not a chat" and "chat that will not parse"
  into one `nil`; a chat whose header is mid-edit refuses with a message
  instead of degrading to unclamped markdown semantics.
- The heading-dialect sweep had left a second `outline.lua` consumer behind
  (`:254`, the token path, hand-restating `<= 3`); it now reads
  `markdown_heading.MAX_LEVEL`. `exporter.lua:539-541` maps `##`/`###`
  independently too — pre-existing, recorded for whoever widens the dialect.
- ARCH-CONSTRAINTS: the declared `< 16 ms @ 5 000 lines` was missed (24.7 ms;
  17.0 ms on an independent best-of-5). Recorded as an accepted deviation with
  the operator's basis, not silently restated.
- Coverage the review named: `die`/`cae` at the surface, and an end-to-end
  assertion that an edge 📝 survives `daE`.

Process slip worth recording: commit `e007f6c5` swept unrelated
`workshop/parley/` transcript churn in with `git add -A`. Those files were
already dirty at session start; they should have been a separate `side-quest:`
commit (AGENTS.md §12).

### 2026-09-16 — packaged app parity

Operator verified the plugin working and asked for the packaged app too. There
was a real gap: `starter_config.options` sets `default_keymaps = false` and
re-enables only entries whose key is in the `<C-g>`/`<M->` families (or whose
scope is a finder). The two hotkeys passed that filter; **all three text
objects were silently dropped**, so the app would have shipped `<C-g>k` with no
`dae`/`yae`/`cae`.

Fixed by carving out operator-pending/visual-only entries rather than widening
the filter. The filter exists so the app does not take ordinary editing keys
away from users who are not Vim experts; a text object fires only after an
operator or inside a selection, so it cannot claim a bare key and the policy's
intent does not reach it. A negative test pins that the carve-out did not
widen anything: `resolve_ref_gf` (a bare `gf`, normal mode, same scope) is
still excluded.

Verified by driving the **app's own option builder**, not the shipped defaults:
`ae`/`ie`/`aE` are really present in `o` and `x` on a prepped chat buffer under
`starter_config.options`.

Suite state unchanged otherwise. `parley_harness_golden_spec` still fails
11/11 here and on the branch base (pre-existing).
`document_dependencies_spec`, `perf_document_spec` and `perf_ownership_spec`
fail only under the 8-way parallel make target and pass serially.

### 2026-09-16 — M1 + M2 landed, ready for smoke test

Branch `000262-delete-entity-at-cursor` (in place). Built:

- `markdown_heading.level` — the ATX dialect, stated once. `outline.lua` folded
  onto it (its 2/4/6-space indent ladder is exactly `("  "):rep(level)`), and
  `document/lexical.lua`'s inline byte-scanner is pinned to it by conformance
  test over a 20-line corpus straddling every edge of the grammar. All 20 agree.
- `entity_range.range` — 29 unit assertions green, including a property sweep
  over malformed transcripts (empty buffer, header-only, fenced heading, row
  past EOF) asserting no inverted or out-of-range result.
- `entity_textobj.select` + the five registry entries + `:ParleyDeleteEntity` /
  `:ParleyDeleteToEnd` — 8 integration assertions green on a real prepped chat
  buffer.

Two hazards found by *running* the mechanism, not by reading it. Both would
have shipped a feature that passes its specs and misbehaves in the editor:

1. An `x`-mode mapping must leave visual mode before selecting. `V` inside an
   existing selection moves only the cursor end and keeps the anchor, so `vae`
   selected from wherever the user started. Stock `vip` resets both ends.
2. `G` cannot enter a closed fold — it snaps to the fold's first line, silently
   widening the range. `prep_chat` calls `tool_folds.setup(buf)`, so 🔧:/📎:
   blocks are closed folds in ordinary use; this was not an edge case.

Test-suite state, stated exactly: `tests/unit/parley_harness_golden_spec.lua`
fails 11/11 on this branch AND on its base commit — pre-existing, verified in a
worktree at the base, unrelated to this work. `perf_document_spec` and
`perf_ownership_spec` fail under the 8-way parallel `make test-integration` and
pass serially on this branch, matching the repo's known parallel-load
sensitivity. Everything else is green.

Not yet done: the parity test (Task 13), the perf measurement against the 16 ms
budget, the atlas/README key documentation (Task 14), and both milestone
closes.

### 2026-09-16

Filed from operator request: quick delete for markdown section at cursor,
paragraph (friendly `dap`), and chat question — unified as "delete an entity."

Operator follow-up: "is there a way to change nvim's keystroke such that dE
becomes delete entity, and entity definition is controlled by nvim's lua
extension?" — yes, three routes: (1) a text object mapped in `o`/`x` mode,
which gives every operator + dot-repeat from one range function; (2) `opfunc`
+ `g@` for a charwise/count-aware operator; (3) a plain normal-mode mapping,
which buys nothing the other two don't. Shipping (1). Literal `dE` requires
mapping `E` in operator-pending mode, shadowing the stock end-of-WORD motion
inside chat buffers — hence `ae`/`ie` instead, which the operator confirmed:
“I think `dae` would be nice then. one thing to remember, and worst case we
can bind a hot key to that.” Recorded as the decision in Spec, with the
hotkey as a wrapper over the same range function.

Operator, same day, adding the extended range: “we should also have a shortcut
to delete to end of this question, from current cursor, assuming starting at
entity level. so if I'm on a paragraph (denoted by blank lines), then the
current paragraph would be deleted as well, and all the remaining. I guess
leave summary 📝: lines along, as I'm not sure what to do with it. it's going
to be not accurate after heavy editing of the answer, but may still have some
structural information.”

Checked the parser while writing this up: 📝 is already modelled as
`exchange.summary = { line = N, content = … }` (`chat_parser.lua:799`) with the
prefix from `config.chat_memory.summary_prefix`, and it belongs to a declared
structural-marker class (`document/lexical.lua:patterns`). So preservation
needs no new scanning, and the policy is written for the whole class rather
than for 📝 alone — 🌿 branch links raise the same orphaning question and are
the one the operator has not ruled on.
