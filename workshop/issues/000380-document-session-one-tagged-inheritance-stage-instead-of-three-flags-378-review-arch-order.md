---
id: 000380
status: open
deps: []
github_issue:
created: 2026-10-17
updated: 2026-10-17
estimate_hours:
collaboration-mode: collaboration
card_mirror: '7367672cef28647dce6a70f5748db495f5d8678c' # card fields mirrored from issue-cards; edit via sdlc
---

# document_session: one tagged inheritance stage instead of three flags (#378 review, ARCH-ORDER)

## Problem

The #378 close review (round 4, a Minor under ARCH-ORDER) noted that `document_session` tracks a side doc's inheritance with three flags and an operation kind:
- `state.inherit`, the hint stashed while the attach lookup is out;
- `args.inherit`, on the inherit lookup;
- `args.inherited`, on the inherited register and its re-lookup;
- the `confirm_parent` operation kind.

The legal combinations are not written down anywhere. The settle step and the `admits`/`inheriting` helpers read these flags back to decide whether a held Alt+Return flushes or drops. In the same review, a lookup's or confirm_parent's `not live` branch was noted as practically unreachable, and no fixture enters it.

## Spec

Collapse the flags into one tagged inheritance stage carried by the model: none, hinted, looking, confirming, registering, relooking. `admits`, `inheriting` and the settle decision then read that stage. #378's table test (`settles a queued press exactly once on every ending`) stays as the guard, and should pass unchanged.

## Done when

- One stage field replaces `state.inherit`, `args.inherit`, `args.inherited` and the kind check in the inheritance helpers.
- The settle table test passes unchanged, and a unit case covers each stage transition, including the ones that are rejected.

## Plan

- [ ]

## Log

### 2026-10-17
