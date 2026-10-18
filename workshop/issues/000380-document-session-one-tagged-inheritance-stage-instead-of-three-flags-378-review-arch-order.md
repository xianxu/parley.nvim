---
id: 000380
status: working
deps: []
github_issue:
created: 2026-10-17
updated: 2026-10-17
estimate_hours:
collaboration-mode: collaboration
card_mirror: '4007a0284dcdae916763606fea5c07218f63bba4' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-17T19:05:38-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "50734f5c", done: "55a076a8"}
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

- [x] Replace `state.inherit`, `args.inherit`, `args.inherited` and the `confirm_parent` kind check with one `state.inheritance = {stage, parent}`. The stages are hinted, looking, confirming, registering and relooking (`inherit_as` refuses any other). Each stage lives exactly as long as the operation it names: it is cleared when that operation's matching event arrives, and set again only by the step that issues the next one. `admits`, `inheriting` and the register-refusal branch read the stage (ARCH-ORDER).
- [x] Unit tests: #378's settle table, unchanged, passes. A new transition table walks 26 rows (stage × event → next stage), checks that a second inherit and a stale reply move nothing, and checks that no operation carries an inheritance flag. A registered or pending child never starts one.

## Log

### 2026-10-17
- Plan posted to the hub, proceeding unless it objected. Built as planned; no shell change was needed, because agentic_document never read the flags.
- Targeted runs pass: document_session 47, which includes the settle table unchanged and the new 26-row transition table; side_inherit 9; agentic_document 47; owned_move 16; lifetime 10. Mutation check: with `changed` no longer clearing the stage, the transition table fails (relooking → changed).
