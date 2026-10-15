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

- [x] Record the hub-approved submitted-only revision and notify the shared-skill/S1 owners.
- [ ] Wait for ariadne#399 and parley.nvim#332 (S1 depends on pair#573), then inspect their landed interfaces and run change-code.
- [ ] Delete the verbose Couch builder, editor diff/baseline and alternate send branch; preserve S1's exact submitted-only payload and the canonical inline review outside Couch.
- [ ] Run targeted/full verification, coordinate the staged live check, close on SHIP and land.

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

### 2026-10-15 — shared export consumer review

Reviewed ariadne#399's plan at 6c3845509146386a234410367012d2df77ac3b33
with a fresh read-only reviewer. Export roles/mode semantics fit the approved
submitted-only contract. Returned three required clarifications: confirmed
absence versus unavailable lookup (including legacy session-sync CAS), review
snapshot/hash and reflected-only owed folding, and standalone composition that
excludes the Couch file-edit adapter. Requested resolved-byte hashes and a
total manifest sort. On this consumer, the canonical round must own flag
semantics; do not retain Mode.directives as another authored definition.
Plan review only; no implementation or live verification claimed. Await the
revised producer contract and the existing dependency landings.

### 2026-10-15 — producer pin inspected

At ariadne#399 pin 8bead12b81f8380757fc55e6e3e90e80bf4fe2d2, all nine
export member byte counts/hashes match pinned contents and all six modes match
Parley byte-for-byte. The proposed export fits local composition. Sent two
remaining adapter corrections to the owner/hub: legacy tracked type before
COUCH_TREE-unset classification, and reflected-only folding of captured owed
IDs. The durable plan records the exact provisional schema/composition.
Awaiting the landed merge pin and #332; no implementation started.

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

### 2026-10-15 16:25 — submitted-only revision (approved)

Authority: ops:0 delivery 9111a425-a6cd-4098-9138-009139f4155c, submitted and
verified. The hub selected the operator's simple-submission direction and
approved the plan with this change.

**Current payload contract:** every Couch Alt+Return sends only
`submitted: ABS_PATH` through S1's existing send_registered flow, including
files with process-instruction. No payload adapter, capability-dependent
format, embedded mode/instruction, editor-computed diff or send baseline.
Ariadne#399 reads the file's frontmatter process-instruction and computes
changes since its last read with couch --session-sync diff; section modes come
later. Outside Couch the existing in-editor review keeps a complete inline
round derived from the canonical source. #319 waits for #399 and #332.

**Revised acceptance:** the actual keymap uses the same exact submitted-only
payload with/without process-instruction and on repeated sends; the old verbose
builder/diff/baseline and alternate sender are removed; outside-Couch inline
review still works without shared skill discovery. S1 continues to own
registration, locks, dedup/resend and receipts. These clauses supersede the
old Spec/Done-when wording about an editor-built diff and skill-dependent send.

The original implementation proposal is retained verbatim as
workshop/plans/000319-universal-review-send-proposal.md; the durable plan now
records the approved execution tasks. No code changed in this revision.
