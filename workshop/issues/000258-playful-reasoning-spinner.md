---
id: 000258
status: open
deps: []
github_issue:
created: 2026-09-15
updated: 2026-09-15
estimate_hours:
---

# Show playful spinner during reasoning status

## Problem

When a provider reports reasoning progress, the chat status switches to the
literal `Reasoning...`/`Reasoning: ...` message. Reasoning can take a long time,
so this loses the playful animated waiting language already used before the
first response bytes (`Cooking`, `Brewing`, and similar verbs). The static
reasoning label makes a normal wait look stuck.

## Spec

Use the existing per-generation playful spinner presentation while a response
is reasoning. Keep the canonical animated spinner and rotate through the
existing waiting verbs instead of replacing it with a static reasoning status.

- Reuse the existing spinner frames, verb list, timing, extmark anchor and
  cleanup owned by `chat_pending`; do not create a second animation loop.
- Treat reasoning detail as optional secondary information. If shown, it must
  remain bounded and composed with the playful status without suppressing its
  spinner or verb; empty detail keeps the animation moving.
- Continue animating across long reasoning periods and repeated provider
  fragments. Do not reset the frame or verb on every fragment.
- The first committed answer/tool output still hides the waiting presentation.
  Completion, failure, cancellation, reload, buffer deletion and stale
  generations still remove all spinner state.
- Keep the behavior per generation and per buffer. Concurrent responses may
  display independent statuses and must not overwrite one another.
- Preserve detached progress behavior for definition and other skills; this
  task concerns chat response reasoning.

## Done when

- A response that spends time reasoning shows an animated spinner with an
  existing playful verb rather than a static `Reasoning...` line.
- Repeated reasoning fragments leave the spinner animated and update any
  secondary detail within existing bounds.
- Transitioning to answer text, tool use, completion, failure or cancellation
  removes the spinner cleanly without leaving an extmark or timer.
- Two concurrent responses retain distinct animated statuses anchored to their
  own captured tips.
- Tests cover reasoning with no detail, long/repeated detail, verb rotation,
  concurrent sessions and terminal cleanup; existing waiting-spinner tests stay
  green.

## Plan

- [ ] Trace reasoning progress through `chat_presentation` and `chat_pending`,
  deciding how bounded detail coexists with the playful status.
- [ ] Implement the shared presentation transition and add deterministic timing,
  repetition and concurrent-generation tests.
- [ ] Update response-progress documentation and traceability, then review.

## Log

### 2026-09-15

Filed at the user's request. The existing waiting spinner already has playful
verbs and animation; this task makes reasoning use that same presentation
instead of the static `Reasoning...` status. No implementation changes are part
of this issue yet.
