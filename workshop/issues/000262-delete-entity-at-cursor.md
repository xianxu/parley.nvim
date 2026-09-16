---
id: 000262
status: working
deps: []
github_issue:
created: 2026-09-16
updated: 2026-09-16
estimate_hours:
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
  (ATX heading `#` … `######`), delete that entire section: from the heading
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
- A cursor inside a blank-line-delimited paragraph deletes that paragraph
  (equivalence with `dap` verified in tests, but reachable via the new
  friendly command).
- A cursor on or inside a `💬:` question deletes that whole question/answer
  exchange as defined by `chat_parser`, not just the `💬:` line.
- Precedence is question > heading > paragraph and is covered by tests.
- The extended range deletes from the *entity* start (not the cursor column)
  through the end of the current exchange, stops at the next `💬:`, and
  degenerates to the whole exchange when invoked on the question line.
- 📝 summary lines survive a deletion that spans them, in one undo step, while
  🧠/🔧/📎 lines inside the range are removed with the answer; 🌿 branch links
  are never silently orphaned.
- The edge case vs. interior 📝 behavior of the text object and the command is
  settled, tested, and documented — not left to differ by accident.
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

## Plan

- [ ] Define entity detection precedence and range computation (reuse
  `chat_parser.find_exchange_at_line`/exchange spans and a heading-level
  scan for markdown sections), shared by `range_at_cursor()` and
  `range_to_exchange_end()`.
- [ ] Settle the structural-marker policy (📝 preserved, 🧠/🔧/📎 with the
  answer, 🌿 decided) and the dangling-summary open question above.
- [ ] Implement `range_at_cursor()` plus the buffer-local `ae`/`ie` text
  object (`o`/`x` modes, single undo group, blank-line cleanup).
- [ ] Add the `aE` object for the extended range, with non-contiguous deletion
  that skips preserved markers in a single undo step.
- [ ] Bind convenience hotkeys to `dae` / `daE` and add the
  `:ParleyDeleteEntity` / `:ParleyDeleteToEnd` commands, all delegating to
  the same two range functions.
- [ ] Add unit tests for range computation and integration tests for buffer
  mutation (section, paragraph, question, precedence, undo, and each
  operator).
- [ ] Document the binding in help and atlas; verify no collision with
  existing `chat_delete` flows.

## Log

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
