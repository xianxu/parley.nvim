---
id: 000257
status: open
deps: []
github_issue:
created: 2026-09-15
updated: 2026-09-15
estimate_hours:
---

# Advance cursor to the next question after submission

## Problem

Submitting a question starts asynchronous response work but leaves the cursor on
the submitted exchange. This makes the normal workflow—submit question 1, then
write or submit question 2—require a manual jump through the transcript.

## Spec

After a question is accepted for response submission, move the cursor to the
next question in the same chat buffer automatically. The move is a command-time
editor convenience; the submitted response's captured document identity and
ownership remain independent of the cursor.

- Move within the current window without changing the active buffer or opening
  another window.
- Resolve the destination by captured exchange identity/structure, not by a
  stale line offset. Edits, folds and concurrent streaming before the move must
  not land the cursor in an unrelated exchange.
- If a next question already exists, place the cursor at its question text in
  the normal editable position. If there is no next question, retain the current
  cursor rather than jumping to an answer, EOF, or another buffer.
- Apply the move once the submission has been admitted, even while its answer
  streams. Later cancellation, reload, deletion or failure must not move the
  cursor again or move it to a replacement exchange.
- Respect explicit command modes that intentionally keep the cursor following
  the active response; document the precedence with existing follow-cursor
  configuration before implementation.

## Done when

- Submitting question 1 places the cursor on question 2 when question 2 exists.
- The submitted response continues streaming correctly after the cursor moves;
  editing or submitting question 2 does not affect question 1's writer.
- Submission with no following question leaves the cursor where it was.
- Deleting or inserting exchanges around the handoff cannot place the cursor on
  the wrong question; reload and cancellation do not cause a late cursor move.
- Normal, insert and visual submission paths share the behavior, and existing
  cursor-follow configuration has explicit regression coverage.

## Plan

- [ ] Identify the response-admission boundary and the document-relative
  question destination, including follow-cursor configuration precedence.
- [ ] Implement one guarded cursor-advance operation and add deterministic tests
  for concurrent streaming, edits, deletion, reload, cancellation and EOF.
- [ ] Update keybinding/help or atlas documentation and complete review.

## Log

### 2026-09-15

Filed at the user's request as a follow-up to #254. Desired workflow: after
submitting a question, advance to the next question so the operator can keep
writing while the earlier answer generates. The cursor movement must remain a
UI convenience and cannot become ownership authority for the submitted writer.
