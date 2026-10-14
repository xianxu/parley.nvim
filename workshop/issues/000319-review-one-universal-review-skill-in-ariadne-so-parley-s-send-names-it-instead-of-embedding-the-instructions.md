---
id: 000319
status: open
deps: []
github_issue:
created: 2026-10-13
updated: 2026-10-13
estimate_hours:
card_mirror: '62229aab23f46e4e48765251255a23dd22981fc9' # card fields mirrored from issue-cards; edit via sdlc
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

- [ ]

## Log

### 2026-10-13

## Revisions

- 2026-10-14 — revise (operator): with QA-file follow-ups the review send is now frequent, and the embedded
  boilerplate is noise. The send should be just:
  `review request: <abs path> process-instruction: <the file's process-instruction> Respond by editing the file in place (review convention: 🤖 markers).`
  plus, at most, the name of the skill that defines a round (e.g. "use the xx-universal-review skill"). Drop the
  "Review mode" brief, the "How to apply this round" block, the repeated operator instruction, and the
  "Changes since the last send" header when it says "first send" (keep a real diff when there is one, since
  that's new information). The mode semantics live in the skill, not in every message.
