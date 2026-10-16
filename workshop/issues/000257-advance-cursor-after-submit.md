---
id: 000257
status: codecomplete
deps: []
github_issue:
created: 2026-09-15
updated: 2026-10-16
estimate_hours:
card_mirror: 'b7c683e2a2ba132f6ba6cef883686a1f17b400e5' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-16T09:10:43-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "4da32fa3", done: "63f2f451"}
actual_hours: 0.77
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
- Stop at cursor (`<C-g>x`) with the cursor on no running response stops the
  one response running in the chat directly; with two or more running, it asks
  which (see Revisions).

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

- [x] `next_question_cursor` and `advance_after_submit` in chat_respond
- [x] Tests (chat_respond_spec, fake provider):
  - q1 then q2: the cursor lands on q2 and stays there while q1's answer streams and completes; q1's writer is unaffected by typing in q2;
  - a resubmit mid-chat moves to the next question;
  - the last question leaves the cursor in place, and follow still follows;
  - a visual-range submit;
  - a refused (overlapping) submit does not move;
  - an explicit follow override does not move;
  - a cancel after the move does not move it again;
  - a unit case for `next_question_cursor`.
- [x] Atlas (chat lifecycle: respond, follow-cursor) and the README's follow-cursor line, if it has one

## Revisions

- 2026-10-16, suite on d3909bd9; TL decision (a): after the advance, submit-then-stop (`<C-g>x`) opened a picker with one choice, since the cursor is no longer on the answer. Two specs hung on that picker. The stop rule changes: with the cursor on no running response and exactly one running in the chat, stop it directly; two or more still open the picker. It has its own test. The under-cursor case puts the cursor back on its question, and the stale-picker case runs two responses so the picker still opens. Atlas: chat/lifecycle, "Stopping and correcting a response".
- 2026-10-16, close review round 1:
  - **BR-1 (Critical):** with the cursor outside every exchange, the submission answers the last exchange, but the advance read `exchange_idx or 0` and jumped to question 1. Now one index, `submitted`, feeds both the submission and the advance. Regression case added.
  - **BR-2 (Important):** Done-when gains the stop-rule clause.
  - **Minors:** the advance parses through `chat_context.parse` (ARCH-DRY), and that parse is the one extra parse per submit (the Plan's "already done on that path" was wrong). Insert-mode submission is tested: the command's stopinsert ends Insert mode after it returns, moving the cursor left like `<Esc>`, so from Insert the cursor is placed one character further.

## Log


- 2026-10-16: closed — Round 1 fixes: one submitted index feeds the submission and the advance (BR-1; cursor outside every exchange keeps its place, regression case); Done-when covers the stop rule (BR-2); the advance parses via chat_context.parse; Insert-mode landing tested. chat_respond_spec 63/63, chat_stop_generation 7/7 incl. the one-running direct stop; mutation checks fail each case. Operator live smoke PASSED on d3909bd9 (cursor advance); the stop rule and round-1 fixes are test-covered, not smoked. Full suite green on d4f4a10f (sdlc-local/suite); the first run hit the unrelated cliproxy_auth_login_spec restart-rung flake, which passed 21/21 twice alone.; review verdict: SHIP
### 2026-09-15

Filed at the user's request as a follow-up to #254. Desired workflow: after
submitting a question, advance to the next question so the operator can keep
writing while the earlier answer generates. The cursor movement must remain a
UI convenience and cannot become ownership authority for the submitted writer.
- Built. Mutation checks, each reverted and cmp-restored: without the advance, the streaming, resubmit and visual cases fail; advancing despite an explicit follow override fails the override case.
- The README has no follow-cursor section; the atlas covers it (chat/lifecycle, "Advance after submit").
