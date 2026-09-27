---
id: '000264'
status: done
started: 2026-09-27T11:51:45-07:00
created: 2026-09-16
updated: 2026-09-27
estimate_hours: 3.71
actual_hours: 2.46
---

# Semantic folds flicker open on a local blank-line edit

## Problem

Operator report: while composing a question, the previous exchange's `📝:`
summary — two lines above the cursor — briefly expands and then re-collapses.
It is distracting during ordinary editing. The reported edit was removing blank
lines (not all of them) from the run between the summary and the `💬:` question
starter. Desired behavior: the summary stays folded.

Measured: the flicker is not local. On a 242-row transcript carrying 40 summary
folds, deleting **one** blank line near the end opens **all 40** folds at once
for 12 scheduler turns, then re-closes them. The settled state is always
correct; only the intermediate is wrong.

The operator's instinct ("nothing would materially change") is right at the
document level. A blank row is, however, a real grammar token — it terminates a
non-explicit reasoning block (`highlight_structure.lua:81`,
`answer_structure.lua:81`) — so the model cannot cheaply prove the edit is
inert. That justifies re-deriving; it does not justify repainting the buffer.
