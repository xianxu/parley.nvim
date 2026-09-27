---
id: 000281
status: codecomplete
deps: []
github_issue:
created: 2026-09-26
updated: 2026-09-27
estimate_hours:
started: 2026-09-27T11:38:12-07:00
flow: {kind: quick, provenance: inferred, spec: "517ebd22", done: "24251552"}
actual_hours: 0.11
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

### Findings (2026-09-27)

**1. The expand/collapse flicker comes from fold repair, not from where tool
payloads are stored.** Reproduced headless (scratch spec driving
`document` + `tool_folds.step` one turn at a time). The chat has a closed
`🔧`/`📎` pair; a second tool block is appended the way the runner writes it:

| Append shape | Turns an earlier, closed fold is open |
|---|---|
| Result split over two writes (closing fence in the 2nd) | 2 |
| Whole block in one write | 1 |
| Compact reference line only (externalized result) | 1 |

In every case `apply()` (`tool_folds.lua:323`) clears every fold in the
exchange in one turn (`zD`, :375-382) and recreates them in the next
(:383-400), so every *unchanged* fold of the exchange blinks open once per
structural write. Streaming an answer that runs N tools means about 2N+
writes (one per call, one per result, more for results over 4 KB, since
`generation_runner.lua:418` writes at most 4096 bytes per turn and the result
changes kind when its closing fence arrives, `document/grammar.lua:120`).
Externalizing removes only the extra writes from splitting; the blink per
block remains. This is #264's defect (b) on the append path: #264 names the
eager `clear_uncertainty` at `tool_folds.lua:426`, and the same
clear-before-create split exists inside `apply()`.

**2. Inline fences are less fragile than the issue assumed.** The fence length
is dynamic (`fence.lua:54-58`: one longer than the longest backtick run, at
least 3) and closes only on a bare run of the same length, so fence-like
result content is already safe. The real remaining hazard is a column-0
structural marker (`💬:`, `📎:` …) inside a body, which ends the body
(`fence.lua:148-154`). The read and search tools prefix their lines; `ls`/
`find` path output and raw stderr don't (`atlas/providers/tool_use.md:283-301`).

**3. Payload size is real.** A result can be 100 KB by default and up to
512 KB (`init.lua:891`, `response_tools.lua:85-86`); `read_file` skips the
200-line pager. Calls are capped at 64 KB. Arguments aren't streamed: they're
decoded after the response completes (`response_provider.lua:57-72`).

**4. Moving payloads out breaks a defended target.**
`workshop/targets/transcript-is-the-whole-truth.md:15-19` makes the Markdown
file "the complete state of the conversation … what the tools did", and
`atlas/chat/transcript_truth.md:3-4,17-18` allows only advisory sidecars. Image
assets are the one existing exception: the transcript is their index, and a
missing image becomes a note in the request rather than a refusal
(`atlas/chat/attachments.md:59-61`).

**5. The image-asset pattern has lifecycle gaps that tool results would make
much worse**, because tool results are far more numerous than pasted images:
- Rename (timestamp-keyed folder) and move/tree-move/delete/tree export
  (`assets.lua:1216-1241`, `init.lua:3399`, `:3735-3747`, `exporter.lua:1030`)
  handle the folder.
- `ChatPrune` (`init.lua:4384-4413`), branch/drill-in (`init.lua:5317-5380`)
  and exchange cut/paste (`exchange_clipboard.lua`) copy link lines that still
  point into the parent's folder. They break when the parent is deleted or the
  child moves.
- Pandoc export doesn't handle assets (`exporter.lua:1088-1128`).
- Nothing garbage-collects orphans.
- `chat_history_search` only searches `*.md`
  (`chat_history_search.lua:80-92`), so moved-out payloads would stop being
  searchable.

### Options

- **A. Keep payloads inline; fix the flicker where it happens.** Build-then-swap
  fold repair that never touches an exchange's unchanged folds (#264, extended
  to the append path), plus writing each tool block in one piece. Close the
  column-0 marker gap by prefixing or indenting the lines of every tool
  result, not just some.
  *Pros:* fixes the reported symptom for every foldable kind (thinking,
  summary, tools); keeps the whole-truth target; no migration; no new file
  family.
  *Cons:* chats stay large when tools return big results (folded, but present
  in the file, in diffs, and in raw reading).
- **B. Store results in per-chat files beside the chat; keep arguments inline.**
  `📎: <name> id=<id>[ error=true] → assets/<chat-ts>/<id>.txt` plus a short
  preview line; bytes written before the reference line (like `paste_image`'s
  rollback order); context reconstruction reads the file, bounded, and a
  missing file becomes the text "result unavailable (file missing)", which
  degrades rather than refusing.
  *Pros:* small, readable transcripts; tool bodies never appear in the
  Markdown grammar.
  *Cons:* doesn't fix the flicker (Findings 1), so #264 is still needed; the
  target must be amended; prune, drill-in, exchange cut/paste, pandoc export
  and search must be made asset-aware first (fix the class, including for
  images); a new, much faster-growing file family whose only removal path is
  deleting the chat (ARCH-FUNERAL); old inline chats stay readable, giving two
  representations to parse indefinitely (ARCH-DRY cost).
- **C. Hybrid: inline below a size threshold, external above it.** Worst of
  both: two live representations chosen by size, with every consumer handling
  both.

### Recommendation

**A.** The reported problem is the flicker, and B doesn't fix it (Findings 1).
B's real benefit is smaller files, which is worth taking only as a deliberate
decision to amend the whole-truth target, and only after the asset lifecycle
gaps are closed for images too. If transcript size becomes the actual pain,
revisit B as its own issue, with this design as its starting point.

Follow-ups under A:
1. #264: extend its scope to the append path (clear-before-create in `apply()`),
   and add the streaming repro as a failing regression test: for each append
   shape above, an unchanged closed fold must never read open between steps.
2. New issue: write each tool block in one piece (skip the 4096-byte split for
   blocks, since result size is already capped at the source).
3. New issue: close the column-0 marker hazard for all tool results
   (`ls`/`find`/stderr), with fixtures of hostile result content.

## Done when

- Document the streaming expansion/collapse problem and the complexity of inline fenced payloads.
- Compare storage/presentation alternatives and record a recommended design with tradeoffs, including the existing per-chat image asset pattern.
- Define transcript references, result inspection, context reconstruction, file lifecycle and compatibility expectations for the chosen design.
- Specify a prototype/verification plan covering partial streams, fence-like result content, interruption/reopen and stable display; file implementation follow-ups after the design decision.

## Plan

- [x] Trace how streamed tool content reaches serialization, parsing and folding; reproduce the reported display instability.
- [x] Evaluate per-chat payload files and compact transcript references against inline fences.
- [x] Record the design decision, lifecycle/compatibility rules and verification plan.

## Log

### 2026-09-26

- 2026-09-26: Filed at user request. Preferred direction to investigate is storing tool results beside the chat, analogous to image assets; no implementation or migration authorized by this task capture.

### 2026-09-27
- 2026-09-27: closed — Design investigation, docs-only. Flicker reproduced headless (scratch spec: document + tool_folds.step per turn): an unchanged closed tool fold reads open 1 step per structural append (2 when a result spans two writes, 1 for a one-line reference) -> cause is fold repair, not storage. Operator chose design A (inline). Follow-ups filed: #290, #291; #264 revised with the streaming repro as its regression test. No code changed.; review verdict: SHIP
- Claimed. Two read-only exploration digests (tool pipeline; assets,
  lifecycle and authority) plus a headless fold repro. The repro spec was
  scratch-only; its shape is recorded in Findings 1, to be committed as a
  regression test under #264. Design recorded above; waiting for the
  operator to decide between A and B, and whether to amend the target.
- **Decision (operator, 2026-09-27): A.** Tool payloads stay inline; the
  whole-truth target is unchanged. Follow-ups: #264 extended to the streaming
  append path, with the repro as its regression test (see its Revisions);
  #290 (one write per tool block); #291 (serializer-level escape for column-0
  markers in results, reversing the bounded-exception decision). B (per-chat
  result files) is not pursued; its design and costs stay in Options above in
  case transcript size becomes the problem.
- Done-when coverage: (1) the streaming problem is in Findings 1 (reproduced)
  and the complexity of inline payloads in Findings 2-3; (2) alternatives A/B/C
  are compared in Options, including the image-asset pattern (Findings 5);
  (3) for A the transcript format is unchanged: inline blocks paired by `id=`,
  context rebuilt verbatim, the existing lifecycle kept (no new files), the
  compatibility rule for #291's escape (old chats parse as before) in #291;
  result inspection is unchanged: each call's arguments (`🔧` JSON), result
  (`📎` body), status and errors (`error=true` on the `📎` header, failure text as
  the body) stay in folded inline blocks, opened in place;
  (4) verification lives in the follow-ups: partial streams and stable
  display in #264's regression test and #290, fence-like and hostile content
  in #291's fixtures, and interruption/reopen already handled (unterminated
  block → synthetic dangling result, `chat_respond.lua:646`) and exercised by
  #290's one-write rule, which removes the half-written state.

