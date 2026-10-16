---
id: 000257
status: working
deps: []
github_issue:
created: 2026-09-15
updated: 2026-10-16
estimate_hours:
card_mirror: '711f1b96b7401b22170aa14bd0fd17eb4f2c76fd' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-16T09:10:43-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
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

**When the cursor moves:** once, in the same tick that `respond` admits the submission (`start_scoped_response` returned a session), and only if the submitted exchange has a next question. It goes to that question's first line, just after the `💬: ` prefix, in the window the command ran in, and it leaves normal mode as is. Normal, insert (which `respond` already leaves) and visual submissions all go through `respond`, so they share it. The next question includes the empty trailing `💬:` prompt.

**When it doesn't move:**
- There is no next question (submitting the last one). The cursor stays where it was, and follow-cursor behaves as today.
- An explicit follow override (`respond(params, cb, true)`): an explicit request to follow the answer wins. No production caller passes one today.
- The command's window has gone, or no longer shows this chat.
- A refused submission (overlap, no question, an identity failure). No session means no move.
- Respond-all (the batch): it walks every question to the cursor, so there is nothing after it to advance to.
- Never later. Cancellation, failure, reload, deletion and completion don't move the cursor: the move is synchronous at admission and nothing schedules another.

**Precedence with follow-cursor:** follow already stops once the operator moves the cursor away (`written` follows only while the cursor is where it last left it), so the advance is that move. With a next question, the cursor is on it and the answer streams without dragging it. Without one, follow is unchanged.

**Destination by structure, not offset:** the next question is read from a parse of the buffer taken right after admission, in the same tick. Admission has already deleted a replaced answer, and exchange indices survive that. Nothing can edit between the parse and the move. The streaming that follows inserts lines above the cursor, and Neovim moves the cursor with its text. A test pins this: the cursor is still on question 2's text after question 1's answer streams in.

**Design:**
- Pure: `chat_respond.next_question_cursor(parsed, index, config)` returns `{row, col}` or nil.
- Glue: `advance_after_submit` in `respond`.
- ARCH-ORDER: this holds no state between events, because the move is one synchronous step at admission and is never scheduled. ARCH-CONSTRAINTS: one parse per submit, already done on that path. MOCK, SECURE, FUNERAL: N/A (no external IO, no new input, nothing durable).

Steps:

- [ ] `next_question_cursor` and `advance_after_submit` in chat_respond
- [ ] Tests (chat_respond_spec, fake provider):
  - q1 then q2: the cursor lands on q2 and stays there while q1's answer streams and completes; q1's writer is unaffected by typing in q2;
  - a resubmit mid-chat moves to the next question;
  - the last question leaves the cursor in place, and follow still follows;
  - a visual-range submit;
  - a refused (overlapping) submit does not move;
  - an explicit follow override does not move;
  - a cancel after the move does not move it again;
  - a unit case for `next_question_cursor`.
- [ ] Atlas (chat lifecycle: respond, follow-cursor) and the README's follow-cursor line, if it has one

## Log

### 2026-09-15

Filed at the user's request as a follow-up to #254. Desired workflow: after
submitting a question, advance to the next question so the operator can keep
writing while the earlier answer generates. The cursor movement must remain a
UI convenience and cannot become ownership authority for the submitted writer.
