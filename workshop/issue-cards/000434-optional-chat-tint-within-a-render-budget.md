---
id: 000434
status: open
created: 2026-10-23
updated: 2026-10-23
estimate_hours:
github_issue:
---

# optional @@chat@@ tint within a render budget

## Problem

Optional semantic @@chat@@ tint exceeded the agreed interactive render budget during #419. The operator has not requested tint; TL b8c4f2df removed it from #419 rather than adding parsing machinery. Tags remain recognized, attached, protected and visible as ordinary text.

Measured with 50 samples on Neovim0.12.5: admitted512heading/2048line/30KiB fixture renderp95 58.462ms; subsequent profile render51.377ms/snapshot38.690ms/policy2.178ms. Even64heading/2048line/39KiB fixture measuredrender22.323ms/snapshot15.415ms/policy0.497ms, existingviewport9.183ms. These are failed qualification measurements under the observed host load, not a cross-runtime performance claim. 0.11.7 timing was not qualified before tint was removed.

Native source inspection disproved a copying hypothesis: installed get_node_text already uses source:sub at node byte offsets. A cosmetic wrapper rewrite was reverted. Markdown inline injection setup dominates the remaining structural snapshot cost; no new optimization was authorized or delivered for tint.
