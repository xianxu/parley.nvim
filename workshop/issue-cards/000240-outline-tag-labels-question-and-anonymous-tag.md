---
id: '000240'
status: done
started: 2026-09-14T20:14:11-07:00
created: 2026-09-12
updated: 2026-09-14
estimate_hours: 1.345
actual_hours: 2.04
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
