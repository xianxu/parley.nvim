---
id: 000290
status: done
created: 2026-09-27
updated: 2026-09-27
estimate_hours:
github_issue:
started: 2026-09-27T15:41:00-07:00
actual_hours: 2.60
tracker:
    version: 1
    completion:
        token: close-86fe4cfc8585
        repository: github.com/xianxu/parley.nvim
        reviewed_head: 3e1560e54a2c26e542d60d99b41d1a09955efcc5
        evidence_commit: 634f2930567dffcdaed1d1403c2b9af4e4464772
        landed_commit: 1d68bfdce7d5521dd51e9b241afe39751c3d01c3
---

# Write each tool block in one append during streaming; fold tool blocks and summaries as written

## Problem

The runner writes at most 4096 bytes per scheduler turn
(`generation_runner.lua:418`). A tool result over 4 KB (100 KB by default, up
to 512 KB) therefore lands in several writes, and its closing fence arrives
in a later one. That switches the result's section kind
(`document/grammar.lua:120`, the `tool_body` lookahead) and forces another
fold repair of the whole exchange, so each large result flickers the
exchange's folds twice or more instead of once (#281 Findings 1). In
between, the buffer also holds an unterminated block, which every parser
consumer then has to tolerate.
