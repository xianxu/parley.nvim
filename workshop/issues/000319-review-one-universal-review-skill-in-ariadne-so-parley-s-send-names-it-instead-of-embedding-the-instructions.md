---
id: 000319
status: working
deps: [ariadne#399, parley.nvim#332, pair#573]
github_issue:
created: 2026-10-13
updated: 2026-10-15
estimate_hours:
card_mirror: 'a78c4e811b6661820aaf64793c69ab8bd71cf7fb' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-15T16:16:41-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
---

# Review: one universal review skill in ariadne, so parley's send names it instead of embedding the instructions

## Problem

Each review send (the universal Alt+Return from a reviewed doc to an agent session) embeds the whole review protocol: review mode, how to apply the round (e.g. propose deletions as 🤖~old~{new}), the marker convention, plus the diff since the last send. The operator first used it on 2026-10-13 (ops' slot-continuity target, sent to the TL in ops:0) and it worked well, but the receiving agent gets the same multi-paragraph instructions every round, and the protocol lives in parley (`lua/parley/skills/review/mode.lua`, `SKILL.md`) rather than with the agents that execute it.

## Spec

Lift the review protocol into ariadne as one agent skill (working name `xx-universal-review`, alongside `xx-fix`, whose marker grammar it shares: `review-convention.md`), so every ariadne-styled repo's agents have it. Parley's send then carries only what varies per round: the file, the mode name, the operator's instruction and the changes since the last send, plus one line such as "use the xx-universal-review skill". Mode semantics (free-form, generate, …) are defined once, in the skill. Cross-repo: the skill lands in ariadne first (file the ariadne side with `--deps` when this is planned); parley keeps a fallback to the full inline text for agents without the skill.

## Done when

- An ariadne skill defines the review round (modes, application rules, marker grammar), and parley's send references it instead of embedding the text.
- A send to an agent with the skill is a few lines plus the diff; the round's behaviour is unchanged (tests on the message builder).
- Agents without the skill still get a working round (fallback).

## Plan

- [ ] Approve the S2a integration choice and land the shared skill (ariadne#399) plus S1 dependencies first.
- [ ] Generate the canonical protocol bundle and implement pure short/inline message formatting with explicit capability evidence.
- [ ] Integrate formatting inside S1's registered-send seam, preserving admission, lock, dedup/resend and confirmed-success baseline behavior.
- [ ] Run targeted/full verification, stage for the hub's live check, close on SHIP and land.

Durable plan: [universal review submissions](../plans/000319-universal-review-send-plan.md).

## Log

### 2026-10-13

### 2026-10-15 — S2a plan drafted

Claimed and started after #335 landed. Read the ops design S2 and project S2a;
loaded the refreshed architecture/worker contracts. Filed ariadne#399 unclaimed
for hub dispatch. The S1 owner confirmed its registered submission bypasses
review_send.message even for explicit process-instruction; the proposed plan
therefore requests one payload adapter inside S1, without bypassing its
registration, locks or receipt ownership.

The canonical grammar is 8,774 bytes, larger than Couch's 8,192-byte envelope;
standalone fallback embeds the generated round/mode brief and points to the
packaged grammar file. The pure builder budgets UTF-8 bytes and real diffs.
Issue schema and whitespace checks pass. This turn changes only issue/plan
artifacts; no implementation or runtime tests are claimed. Awaiting hub approval.

## Revisions

- 2026-10-14 — revise (operator): with QA-file follow-ups the review send is now frequent, and the embedded
  boilerplate is noise. The send should be just:
  `review request: <abs path> process-instruction: <the file's process-instruction> Respond by editing the file in place (review convention: 🤖 markers).`
  plus, at most, the name of the skill that defines a round (e.g. "use the xx-universal-review skill"). Drop the
  "Review mode" brief, the "How to apply this round" block, the repeated operator instruction, and the
  "Changes since the last send" header when it says "first send" (keep a real diff when there is one, since
  that's new information). The mode semantics live in the skill, not in every message.

- 2026-10-15 — S2a planning proposal after #335 landed. Shared half filed as
  ariadne#399, unclaimed for hub dispatch, with S1 dependencies parley.nvim#332
  and pair#573. Mode/protocol fallback will be generated from the shared source;
  no independent Parley mode definitions. #332's owner confirmed its coordinator
  consumes named Markdown even with process-instruction, so changing only the
  old message builder would miss the Couch path. Request hub approval for a
  payload adapter within S1's existing registered send, preserving its state
  ownership and submitted-only behavior when no review instruction is present.
  See the durable plan for alternatives, contracts, tests and handoff. No code
  changed; awaiting plan approval.
