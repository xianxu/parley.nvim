---
id: 000434
status: open
deps: []
github_issue:
created: 2026-10-23
updated: 2026-10-23
estimate_hours:
card_mirror: '18d4e618a7c9428d04347d954d7ee3db7b3a4294' # card fields mirrored from issue-cards; edit via sdlc
---

# optional @@chat@@ tint within a render budget

## Problem

Optional semantic @@chat@@ tint exceeded the agreed interactive render budget during #419. The operator has not requested tint; TL b8c4f2df removed it from #419 rather than adding parsing machinery. Tags remain recognized, attached, protected and visible as ordinary text.

Measured with 50 samples on Neovim0.12.5: admitted512heading/2048line/30KiB fixture renderp95 58.462ms; subsequent profile render51.377ms/snapshot38.690ms/policy2.178ms. Even64heading/2048line/39KiB fixture measuredrender22.323ms/snapshot15.415ms/policy0.497ms, existingviewport9.183ms. These are failed qualification measurements under the observed host load, not a cross-runtime performance claim. 0.11.7 timing was not qualified before tint was removed.

Native source inspection disproved a copying hypothesis: installed get_node_text already uses source:sub at node byte offsets. A cosmetic wrapper rewrite was reverted. Markdown inline injection setup dominates the remaining structural snapshot cost; no new optimization was authorized or delivered for tint.

## Spec

Only implement if the operator wants optional tint. Keep source editable and ordinary behavior unchanged when optional work is outside its envelope. Reuse the existing structural/effect owners; no second parser grammar, watcher or state cache merely for a decoration. Establish the render-work admission bound from actual workload and qualify the complete added cost on both supported runtimes before shipping.

## Done when

- Operator wants the tint and approves its appearance and explicit size/work envelope.
- New decoration work stays within an agreed latency budget (previous proposal p95 under10ms) on Neovim0.12.5 and0.11.7, with measured baseline and added cost reported separately.
- Oversized or unavailable structure skips optional decoration visibly while editing and Couch submission remain usable; no per-heading whole-document work.
- Production-path tests cover source visibility, code exclusions, once-per-batch work and over-limit negative controls.

## Plan

No implementation assigned; revisit only on operator demand.

## Log

Filed unclaimed from parley.nvim:3 while #419 continues. Current #419 scope has no optional tint and no render-time chat-policy parse.
