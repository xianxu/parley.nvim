---
id: 000281
status: open
deps: []
github_issue:
created: 2026-09-26
updated: 2026-09-26
estimate_hours:
---

# Rethink tool-call storage and streaming presentation

## Problem

Tool-call content embedded in Markdown fences makes transcript parsing fragile,
especially while responses stream. The user reports that the current presentation
repeatedly expands and collapses those fenced blocks during streaming. Keeping
large tool payloads inline may not justify the parsing and display complexity.

Parley already stores images separately in a per-chat assets folder. Tool results
could follow that pattern: store the content beside the chat and keep a compact,
inspectable reference in the transcript.

## Spec

Design investigation, not an approved storage migration. Reconsider both tool-call
representation and result presentation, with per-chat result files as the preferred
alternative to explore. Decide whether arguments should also move out of line.

Compare the current fenced representation with external payloads plus transcript
references. Prioritize stable streaming display, simpler parsing, and easy inspection
of a call's arguments, result, status and errors. Avoid merely layering more fold
repair onto the existing representation without evaluating its cost.

Account for context reconstruction, call/result identity, interrupted streams and
reopening a chat. Decide how files follow chat rename/move, branching, deletion and
export, and how existing inline transcripts remain readable. Distinguish durable
chat assets from disposable state caches: externalizing payloads changes the current
transcript-authority contract and requires an explicit decision, not a hidden cache.

Starting points: atlas/providers/tool_use.md, atlas/chat/format.md,
atlas/chat/attachments.md, atlas/chat/transcript_truth.md and
lua/parley/tools/serialize.lua. Related: #264 (semantic fold flicker).

## Done when

- Document the streaming expansion/collapse problem and the complexity of inline fenced payloads.
- Compare storage/presentation alternatives and record a recommended design with tradeoffs, including the existing per-chat image asset pattern.
- Define transcript references, result inspection, context reconstruction, file lifecycle and compatibility expectations for the chosen design.
- Specify a prototype/verification plan covering partial streams, fence-like result content, interruption/reopen and stable display; file implementation follow-ups after the design decision.

## Plan

- [ ] Trace how streamed tool content reaches serialization, parsing and folding; reproduce the reported display instability.
- [ ] Evaluate per-chat payload files and compact transcript references against inline fences.
- [ ] Record the design decision, lifecycle/compatibility rules and verification plan.

## Log

### 2026-09-26

- 2026-09-26: Filed at user request. Preferred direction to investigate is storing tool results beside the chat, analogous to image assets; no implementation or migration authorized by this task capture.
