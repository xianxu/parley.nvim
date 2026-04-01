---
id: 000042
status: open
deps: []
created: 2026-03-31
updated: 2026-03-31
---

# inspect chat finder performance

can you start by describe existing cost. it should be:

1/ one pass in all files in the folder, read first 10 lines (for front matter), build index of things we need.
2/ store file last update time, avoid reading again if not changed.
3/ async prewarm cache, e.g. upon nvim start, kick off to populate chat/note finder.
4/ if lua support async/multithreading, kick multiple threads (configurable) to read, (assuming good SSD performance here)

any other ideas?

## Done when

- Analysis of current cost model complete
- Optimization plan agreed

## Plan

- [x] Analyze current chat finder implementation and cost model
- [ ] Propose optimizations

## Log

### 2026-03-31

#### Current Cost Model

For N files discovered by glob:

| Step | Operation | I/O per file |
|------|-----------|-------------|
| 1 | `vim.fn.glob()` across chat roots | 1-2 dir scans |
| 2 | `vim.loop.fs_stat()` per file | 1 stat call |
| 3 | Timestamp from filename (regex) or stat mtime | 0 (already have stat) |
| 4 | Recency cutoff filter — skip old files | 0 (pure CPU) |
| 5 | `vim.fn.readfile(file, "", 10)` — 10 lines | 1 read (~500B) |
| 6 | Parse frontmatter (topic, tags) | 0 (pure CPU) |
| 7 | Sort by timestamp | 0 (O(N log N) CPU) |

**Key files**: `chat_finder.lua:348-889`, `chat_parser.lua:34-55,141-425`

#### What's Already Optimized
- Only reads first 10 lines per file (not full content)
- Early exit on recency cutoff (skips readfile for old files)
- Timestamp extracted from filename before falling back to stat
- Dedup across multiple chat roots

#### What's NOT Optimized
- **No caching between invocations** — full rescan every time ChatFinder opens
- **No mtime-based cache invalidation** — could skip unchanged files
- **stat() called even for files that will be filtered by recency** — stat happens before cutoff check (line 414 vs 442)

