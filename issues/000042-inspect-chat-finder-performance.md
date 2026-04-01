---
id: 000042
status: working
deps: []
created: 2026-03-31
updated: 2026-04-01
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
- [x] Propose optimizations
- [x] Implement mtime-based metadata cache
- [x] Skip stat for old files with parseable filenames
- [x] Add prewarm on setup with wait-for-prewarm in open()
- [x] Cache eviction on delete/move via `M.invalidate_path`
- [x] Hoist per-root resolves out of per-file loop
- [x] All tests pass, perf benchmark confirms improvement
- [x] Apply same optimizations to note_finder (DRY: same cache/prewarm/wait pattern)
- [x] Apply mtime cache to issue_finder via `issues.lua:scan_dir_issues`

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

### 2026-04-01

#### Implemented Optimizations

1. **Mtime-based metadata cache** (`_file_cache` in `chat_finder.lua`)
   - Cache keyed by resolved path, stores `{ mtime, topic, tags }`
   - On open: compare `stat.mtime.sec` with cached mtime → skip `readfile` + `parse_chat` if unchanged
   - Stale entries pruned when files disappear from glob
   - Cache evicted on delete/move via `M.invalidate_path(path)`

2. **Recency filter before stat** (for files with parseable filenames)
   - Timestamp extracted from filename (pure string op) → recency check → skip stat entirely for old files
   - Only falls back to stat when filename isn't in `YYYY-MM-DD-HH-MM-SS` format

3. **Prewarm on startup** (`M.prewarm()` called from `setup()`)
   - Deferred via `vim.defer_fn(fn, 0)` — runs after Neovim finishes init
   - Populates `_file_cache` for all files (no recency filter)
   - If ChatFinder opens during prewarm, it waits for completion via callback queue

4. **Hoisted per-root resolves** out of per-file loop
   - `resolved_primary_dir` computed once, `resolved_root_dir` once per root (was N times per file)

5. **Extracted scan loop** (`scan_chat_files()`) shared by `M.open()` and `M.prewarm()`

**Skipped**: Parallel async reads with libuv — cache eliminates most reads; complexity not justified.

#### Applied to all three finders

Same mtime-based cache pattern applied across all finder UIs:

| Finder | Cache location | What's cached | Prewarm | Key difference |
|---|---|---|---|---|
| **ChatFinder** | `chat_finder.lua:_file_cache` | `{ mtime, topic, tags }` | Yes | Skips `readfile` + `parse_chat`; filename-based recency skip before stat |
| **NoteFinder** | `note_finder.lua:_file_cache` | `{ mtime, classification, inferred_time }` | Yes | Skips classify + infer; hoisted root resolve out of per-file loop |
| **IssueFinder** | `issues.lua:_file_cache` | `{ mtime, issue_data }` | No (few files) | Skips full-file `readfile` + `parse_frontmatter`; evicts on status cycle |

All finders expose `clear_cache()`, `get_cache()`, `invalidate_path(path)`. Chat and note finders also have `prewarm()` + wait-for-prewarm in `open()`.

#### Benchmark (user's machine, 10K chat files)

| Scenario | Old | New | Change |
|---|---|---|---|
| Cold scan | 679ms | 929ms* | +37% |
| Warm scan (cached) | 670ms | 367ms | **-45%** |
| 6mo recency cold | 302ms | 422ms* | +40% |
| 6mo recency warm | 290ms | 291ms | same |

*Cold regression was from double `vim.fn.resolve()` — fixed by passing resolved path through. Re-benchmark on sandbox showed cold scan on par with baseline after fix.

#### Benchmark (sandbox, after resolve fix, 10K files)

| Scenario | Old | New | Change |
|---|---|---|---|
| Cold scan | 272ms | 282ms | ~same |
| Warm scan (cached) | 255ms | 155ms | **-39%** |
| 6mo recency cold | 154ms | 128ms | **-17%** |
| 6mo recency warm | 145ms | 100ms | **-31%** |

