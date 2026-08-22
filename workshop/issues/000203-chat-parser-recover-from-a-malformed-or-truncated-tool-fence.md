---
id: 000203
status: open
deps: []
github_issue:
created: 2026-08-21
updated: 2026-08-21
estimate_hours:
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

## Spec

- A malformed or truncated tool fence must not silently swallow later exchanges.
- Well-formed transcripts keep today's behaviour exactly: the first matching
  close is correct and in-body markers are content (#200 M2).
- Failure on malformed input should be visible rather than silent — the operator
  chose over-forking as the preferred degradation, but only where it does not
  cost the well-formed case.

## Done when

- [ ] The shape above yields 3 exchanges, and #200's adversarial fixture still
      yields 2.
- [ ] Well-formed bodies are unaffected: `tests/fixtures/fold_adversarial.md`
      and `fold_tool_transcript.md` unchanged, live-corpus audit still clean.
- [ ] `tests/unit/chat_parser_tools_spec.lua`'s pending case is enabled.

## Plan

- [ ] Decide the model — most likely a real fence-depth pass over the answer
      rather than a per-marker lookahead, so "is this line inside a body" is
      answered once for the whole buffer
- [ ] Implement behind `parley.fence` so all consumers keep one definition
- [ ] Enable the pending test; add the truncated-mid-write shape
- [ ] Re-run the live-corpus audit

## Log

### 2026-08-21

Filed from #200 M2's boundary review (BR-43 shape B). Full reasoning and the
three failed heuristics are in #200's `## Log`; the pending test carries a
pointer here.
