---
id: '000203'
status: done
started: 2026-08-22T17:34:39-07:00
created: 2026-08-21
updated: 2026-08-22
estimate_hours: 2.18
actual_hours: 5.44
---

# chat_parser: recover from a malformed or truncated tool fence

## Problem

A tool body whose fence is never closed makes `chat_parser` treat everything up
to the next unrelated bare fence as body content. Every `💬:` in between stops
starting an exchange, so the rest of the chat collapses into one exchange —
silently. Exchange starts feed `exchange_anchors` identity, which drives #200's
destructive fold clear, so the folds go with it.

Measured on the shape below: 2 exchanges where the pre-#200 parser gave 3.

    💬: q1
    🤖: [A]
    📎: r id=1
    ```                 <- opener, never closed
    never closed
    💬: q2              <- swallowed
    🤖: [A]
    ```                 <- unrelated bare fence, read as this body's close
    💬: q3              <- swallowed

**This is unreachable from anything parley writes.** `fence.for_content` picks a
fence strictly longer than the longest backtick run in the content, so a
parley-written body provably cannot close its own fence and the first matching
close is always the correct one. The shape requires input parley did not
produce: hand-edited, truncated mid-write, or pasted from elsewhere.

Deferred from #200 M2 (operator decision, 2026-08-21) after three local
heuristics each failed: bounding the search at the "next structural boundary" is
circular, because the boundary may itself be inside the body; and declining to
suppress when the body holds a question defeats M2's headline case, since
`read_file` on a transcript produces exactly that with a minimum-length fence.
