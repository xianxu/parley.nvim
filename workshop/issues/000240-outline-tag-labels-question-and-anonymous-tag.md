---
id: 000240
status: open
deps: []
github_issue:
created: 2026-09-12
updated: 2026-09-12
estimate_hours:
---

# Outline tag conventions: an @@tag@@ immediately before a question labels it; @@_@@ is anonymous and hides itself, or the question it precedes

## Problem

Since #232 every `@@…@@` line reaches the chat outline as its own item,
rendered at the question level (`"  → " .. text`, `outline.lua:43-49`), with
one item rule shared by the flat and tree builders. That makes the outline a
usable syllabus — but a tag and the question it annotates are still two rows,
and there is no way to keep a question *out* of the outline at all.

The operator's use (astro, the learning test bed): re-read a transcript, put
a short tag above a question so the outline reads as a curriculum of tags
rather than of full question text; and mark throwaway questions ("try
again", "shorter") so they stop cluttering the syllabus. Three conventions,
one mechanism:

1. **A tag on the line immediately before a question labels the question.**
   The outline shows the tag *in place of* the question's text — one row,
   not two.
2. **`@@_@@` is the anonymous tag.** It never appears in the outline.
3. **Together:** `@@_@@` immediately before a question removes that
   question from the outline structure entirely.

"Immediately before" is strict: the tag on line *i*, the `💬:` line on
*i+1*. A blank line between them breaks adjacency and both rows render as
today.

## Spec

**One post-pass over the item list, shared by both builders** — the same
shape #232 chose for the item rule (ARCH-DRY; the tree builder's private
rule is how annotations went missing for months). Both builders already
walk `all_lines`/`file_lines` and emit `{ display, value.lnum, type }` in
document order, so the pass is pure and needs only the items and the lines:

```
for each annotation item A whose text is T:
  if next item Q is a question with Q.lnum == A.lnum + 1:
    if T == "_": drop A and Q
    else:        Q.display = indent .. "  " .. T   (the question's row, labelled T)
                 drop A
  elif T == "_": drop A
```

Points that need deciding in code rather than left to the implementer:

- **The merged row is the question's row.** Its `type` stays `question`
  (the trailing-placeholder drop at `outline.lua:190/304` and anything else
  keyed on type keep working), and its `value.lnum` is the **question
  line**, so Enter lands where it lands today. The picker's
  cursor-to-item mapping (`find_nearest_outline_line`, `outline.lua:71`)
  must treat the tag line as belonging to that item: with the cursor on the
  tag line, the merged row is the selected one. Simplest: after the pass,
  the merged item records `value.tag_lnum = A.lnum`, and the mapping checks
  both.
- **Labelling only replaces the display.** Search/filter in the picker
  matches the tag, not the hidden question text — that is the point (the
  tag is the learner's own name for it). Say so in the help text.
- **`@@_@@` before a question hides the question from the outline, not from
  the chat.** Nothing about context building, highlighting, or the buffer
  changes. This is display-only, in one file.
- **Adjacency is line-exact.** No blank-line tolerance; the rule is easy to
  state and easy to see in the buffer.
- **Nested/inline branches**: the tree builder emits branch rows from the
  parser, not from lines, so a `🌿` row between a tag and a question cannot
  occur at adjacent line numbers; nothing to special-case. An annotation as
  the last item (no following question) renders as today.

**Not in scope, but recorded as the obvious next question:** `@@…@@` lines
are ordinary content to the parser — they sit at the end of the previous
answer and are sent to the model (`annotation.lua` covers `🌿:`/`🔒:` only).
Whether tags should be withheld from context like `🔒:` is a separate
decision; nothing here depends on it.

## Done when

- `@@polar alignment@@` on the line above `💬: how do I…` → one outline row
  reading `polar alignment`, Enter jumps to the question, filter matches
  "polar".
- `@@_@@` alone → no row. `@@_@@` above a question → neither row; the
  outline's next row is the following question.
- A blank line between tag and question → two rows, as today.
- Flat and tree outlines agree (extend `outline_parity_spec.lua`); the pass
  has its own unit tests on hand-built item lists (merge, anonymous,
  anonymous+merge, non-adjacent, tag-as-last-item).
- Cursor on the tag line selects the merged row in the picker.

## Plan

- [ ] Pure `apply_tag_conventions(items, lines)` in `outline.lua`; unit tests on hand-built items
- [ ] Call it from `_build_picker_items` and the tree builder; parity test cases
- [ ] `find_nearest_outline_line` / picker preselect: tag line maps to the merged row
- [ ] Help text: tag replaces the label; `_` is anonymous

## Log

### 2026-09-12

- Filed from the brain advisor session on the operator's conventions (1–3
  verbatim in Problem). Builds on #232, shipped 2026-09-12 (one item rule;
  annotations at the question level — the side-quest `8213799` set the
  indentation this issue's merged row inherits). Motivated by astro, where
  the outline is meant to read as a syllabus.
