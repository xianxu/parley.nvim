# Delete the Entity at the Cursor

One cursor-dispatched range — a markdown section, a paragraph, or a whole chat
exchange — exposed as text objects so every operator composes with it.

## Keys

| Key | Modes | Range |
| --- | --- | --- |
| `ae` | operator-pending, visual | the entity at the cursor |
| `ie` | operator-pending, visual | its inner form |
| `aE` | operator-pending, visual | the entity through the end of the question |
| `<C-g>k` | normal | delete the entity (same as `dae`) |
| `<C-g>K` | normal | delete through end of question (same as `daE`) |

`dae` deletes, `yae` yanks, `cae` changes, `vae` selects, and `.` repeats —
all from one range function rather than five commands. `:ParleyDeleteEntity`
and `:ParleyDeleteToEnd` are the discoverable equivalents of the two hotkeys.

Available in the Parley app as well as the plugin: the app's profile disables
default keymaps and re-enables only the `<C-g>`/`<M-…>` families, and
`starter_config` carves out operator-pending/visual-only entries so the text
objects survive that filter. They cannot claim an ordinary editing key, because
they only fire after an operator or inside a selection.

## What counts as the entity

Dispatch is on what the cursor line **is**, not on what contains it — every
line of a transcript is inside some exchange, so a containment rule would make
the other two kinds unreachable.

| Cursor sits on | Entity |
| --- | --- |
| `💬:` question line, or its `@@tag@@` preface | the whole exchange |
| an ATX heading line | that section |
| a structural marker line (`🤖: 📝: 🧠: 🔧: 📎: 🌿: 🔒:`) | nothing — the command is a no-op |
| a code-fence line (```` ``` ````) | nothing — deleting it would strand its partner |
| a transcript header line (see "What counts as a header") | nothing — header metadata is not an entity |
| any line, when the chat header will not parse | nothing — both surfaces refuse with a message |
| anything else | that paragraph |

A section or paragraph range is clamped to its enclosing exchange, so it never
runs into the next question.

**What counts as a header** is a property of the document, not of how Parley
classified the buffer — `chat_parser.transcript_header_end` asks the text
itself. That matters because `not_chat` rejects a buffer for reasons unrelated
to its shape (filename not timestamped, fewer than five lines, no `topic`
header), and a transcript saved under an ordinary name is still a transcript
whose header must not be deleted. The test is deliberately strict: the `---`
must close a *contiguous run of header-shaped lines*, so a genuine note that
happens to be titled `# topic: how to cook` and has a thematic break further
down keeps every one of its sections editable. Inside front matter the fence
is the delimiter, so anything between the two `---` lines is header whatever
its shape — which it has to be, because Parley's own long chat template puts
four lines of prose in there.

In a plain markdown buffer there is no exchange kind, and the other two work as
usual.

- **Section**: from the heading through the line before the next heading of
  equal or higher rank — `#` outranks `##`, so deeper subsections are carried
  along. The dialect is the repo's one ATX grammar
  (`lua/parley/markdown_heading.lua`): column-zero, one to three hashes, then a
  space. `#### Four` is body text, and a cursor on it takes the paragraph.
- **Paragraph**: the blank-delimited run, `dap`-style — but the walk also stops
  at headings and at structural markers (`💬 🤖 📝 🧠 🔧 📎 🌿 🔒`) with no blank
  line between, which `dap` would swallow. In a transcript, strict `dap` parity
  would let a paragraph eat the `💬:` line above it.
- **Exchange**: the span `exchange_clipboard.get_exchange_line_range` reports,
  the same one `ExchangeCut` uses, including the `@@tag@@` preface.

An outer range absorbs the blank run that follows it; an inner range trims it.
Keeping that in the *range* rather than cleaning up after the cut is what lets
the native operator and the commands produce identical buffers.

## Structural markers in a deleted range

- **📝 summary** — preserved when it sits at the range's edge *and* the question
  itself survives, so trimming an answer keeps its summary. A whole-exchange
  delete takes the summary with it, and a 📝 with content after it inside the
  range is deleted like any other line. Preservation is an edge trim, not an
  interior skip: a stock `d` over a text object cannot skip an interior line,
  and two surfaces that differ on the same keystroke would be worse than the
  lost line.
- **🧠 🔧 📎 🌿 🔒** — ordinary content. Note that `annotation.lua` and
  `buffer_edit.delete_answer` do carry 🌿/🔒 through a *programmatic* answer
  delete (#214 BR-75/BR-79); this operator deliberately does not extend that,
  because here the user chose the range and the register and `u` are intact.

## Limits

- **Counts are ignored.** `2dae` behaves as `dae`.
- **Code fences are walls.** A fence line is never deleted, a range never spans
  one, and a `# heading` inside a fenced block is content rather than a section
  — the same ruling `outline.lua` already makes for navigation. Without this,
  deleting a paragraph in a code block left an unterminated fence and every
  following line of the transcript rendered as code.

  "Fence" means whatever `lexical.is_fence_delim` recognises: three or more
  backticks **or** tildes, at column zero or indented, with or without an info
  string. The wall and the in-block test deliberately share that one predicate
  — an earlier cut used a backtick-only test for the wall and the full one for
  the in-block check, so a `~~~` block still broke.
- **Cost is the whole-buffer parse, not the range.** Measured 2026-09-16:
  13.6 ms on a 2 497-line transcript, 24.7 ms at 5 000 lines, 97.8 ms at
  20 000 (an independent re-measure, best-of-5, got 8.5 / 17.0 / 72.1 — same
  shape). The plan's original budget was one frame at 5 000 lines; the
  operator accepted the miss on the basis that real transcripts here are under
  2 500 lines, where it is comfortably under a frame. It is linear beyond
  that, so if it ever bites the escape hatch is `document.exchange(doc, row)`
  (`lua/parley/document/init.lua`), the incremental index that already serves
  folds and outline. No perf spec guards these numbers (the operator dropped
  the standing target), so they go stale silently if `parse_chat` changes —
  re-derive by timing `parse_chat` + `entity_range.range` over
  `tests.perf.chat_typing.build_fixture(n)`.
- **During generation**, the command path inherits
  `buffer_edit.replace_user_lines`' refusal; the native operator does not, and
  is handled as an ordinary user edit.

## Code and tests

- `lua/parley/entity_range.lua` — the pure range; all dispatch and policy.
- `lua/parley/entity_textobj.lua` — the selection surface.
- `lua/parley/markdown_heading.lua` — the shared ATX dialect.
- `tests/unit/entity_range_spec.lua`, `tests/unit/markdown_heading_spec.lua`,
  `tests/unit/markdown_heading_conformance_spec.lua`,
  `tests/integration/entity_textobj_spec.lua`,
  `tests/integration/entity_delete_parity_spec.lua`.
