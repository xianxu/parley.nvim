---
id: 000399
status: working
deps: []
github_issue:
created: 2026-10-19
updated: 2026-10-19
estimate_hours:
collaboration-mode: collaboration
card_mirror: 'c3db61378b3a78036e36cef690998219546e78a4' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-19T07:21:18-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "c9f41e98", done: "943f0073"}
---

# fd leak: embedded session-file nvim leaks a unix socket per session-sync reload/lease, hits the 256 limit overnight

## Problem

On 2026-10-19 the operator's embedded nvim for the TL session file (pid 40815, `nvim --embed teams/devinfra/tl-status-xian-xu.md`, started 10-18 20:02) hit the macOS per-process fd limit (256) and became unrecoverable. Every BufEnter then failed with `E903: Process failed to start: too many open files: "/usr/bin/git"` (lualine git_diff), inside session_sync.reload (session_sync.lua:321-323, with_buffer_read:189). lsof at the time: 262 descriptors, of which 237 unix sockets, 231 of them with peer `->(none)` (the other end closed, ours never closed). On macOS, libuv/vim.system stdio pipes are socketpairs, so this is the signature of child-process pipes left open after the child exits. Overnight the hub wrote the session file and side docs hundreds of times (session-sync), so the leak is roughly one handle per external write or reload. Evidence: lsof and ps captured at /var/folders/07/b9wcwwld4_v2w9r3hk525bm80000gn/T/nvim-fd-leak.c719BR/.

Prime suspect (unconfirmed): `lua/parley/document_lease.lua:24` runs `vim.system(command, {stdin=..., text=true}):wait(2500)` on each lease operation. Check what happens to its pipes on timeout or when the process outlives the wait, and every other vim.system/jobstart/uv.spawn in the session-sync, reload and attention paths.

## Spec

Find the leaking spawn with a counted reproduction: open fds before and after N simulated external writes and reloads of a session-sync document must be equal. Fix it at the root: every child's stdin, stdout and stderr closed on every path, including timeout and kill. Add a regression that counts the nvim process's own fds across 200 reloads (or the lease calls) and fails if they grow.

## Done when

- Past the threshold, the editor writes a capture holding the count, its live children and the full `lsof`, and warns once naming the file; a spec shows it with stand-in lsof and ps, and that it stays quiet below the threshold and at 0.
- Two fake-backed guards keep parley's session-sync path flat over 200 agent writes and a 50-doc rename storm.
- The root cause is filed as its own issue once the first capture (or the live sampler on pid 28410) records an onset. (Revised 2026-10-19; was a red-then-green 200-cycle regression of a reproduced leak.)

## Plan

- [x] Measure every candidate spawn path before changing code (all flat; see Log).
- [x] Fake-backed guards in `session_sync_spec`: 200 agent writes with reloads and probes, and a rename storm of 50 registered docs.
- [x] `lua/parley/fd_watchdog.lua`: past `fd_watchdog_threshold` (200) open descriptors, capture `lsof -p` and the live children to `<state_dir>/fd-captures/fd-<stamp>-<pid>.txt` and warn once naming it; keep the newest 5; pure `crossed`/`children`/`report`/`stale` with unit tests, the shell with an integration spec using stand-in lsof and ps.
- [x] atlas/infra/fd_watchdog.md, index and traceability.

## Revisions

- 2026-10-19, hub rescope: #399 becomes "detect and capture". The overnight leak does not reproduce, so it ships the watchdog plus the two fake-backed guards; the root cause goes to a new issue opened from the first capture. Bounded `couch.run` deadlines moved to #400 (unclaimed). Done when below is revised: the original "red before, green after over 200 cycles" needs a reproduced leak.

## Log

### 2026-10-19
- Measured flat (open fds before = after; /dev/fd count in-process, lsof for peers):
  - Core nvim 0.11.7 `vim.system`: callback, `:wait`, `stdin` string and `true` (closed or not), timeout expiry, `:kill`, `:wait(20)` timeout, a grandchild holding stdout, spawn failure; `jobstart` with/without callbacks, `jobstop` before/after exit (lualine's pattern); `vim.fn.system`.
  - Real `couch --session-sync status --json` and `couch --actors --json` through `parley.couch.run`, 30 each, with and without `timeout`.
  - Parley's reload/probe path with the fake couch: 200 agent writes, each reloaded, status probes on (new `session_sync_spec` case).
  - The operator's full config (headless, isolated state, `COUCH_ISOLATED_ROOT`), 60 external writes: 3 orphans appear at startup and stay 3.
  - The restarted live session nvim (pid 28410, 07:21) across hub writes: 0 orphans.
- `document_lease.lua:24` spawns only for an identity containing NUL, so it is not on the per-write path.
- Overnight rate: 231 orphans over ~11 h, about one socket per hub write. One socket per event fits a `vim.system` output pipe left open, which in nvim 0.11 happens when a stdout/stderr handler raises before `pipe:close()` (`_system.lua` `handler_with_close`). It does not fit a whole leaked job (3 sockets).
- Mistake: a first headless run of the full config used owner `ops:0` with no `COUCH_ISOLATED_ROOT`, so parley sent a real session-sync ping to the hub. `forget` reported it was never registered. All later runs are isolated with a fake owner.
- Hub facts on the window (pid 40815, 10-18 20:02 to about 07:15): no Couch restart (the supervisor has run since 18:28); a session-sync write every 5-15 minutes all night; at about 01:30 the ariadne#455 migration moved 156 answer docs into `tl-status-xian-xu.side/`, renamed 43 registrations and rewrote the session file in one apply.
- Also flat: couch calls with no supervisor running (an empty `COUCH_ISOLATED_ROOT`, exit 1); a rename storm in parley alone (50 registered docs, 10 loaded, moved and renamed in the fake registry, plus one session-file rewrite; new `session_sync_spec` case); the same storm under the operator's full config with the fake couch on PATH (orphans move between 0 and 3 while a job is in flight, never accumulating).
- Next: a read-only sampler on the live session nvim (pid 28410) logs orphans, total fds, the status-file mtime and live children each minute, plus a full lsof whenever the orphan count changes. What headless runs can't exercise: an attached UI (statusline evaluation, redraw-driven plugins) and many hours of uptime.
- Close review round 1 (FIX-THEN-SHIP, 3 Important + 2 Minor), all addressed:
  - BR-1: the capture would have written child command lines, and parley's own curl children carry API keys and bearer tokens on argv. Fixed structurally (ARCH-SECURE): `ps` is asked for `comm=` (executable only), so no argument is ever read; the spec's stand-in ps answers anything but `comm=` with a secret-bearing command line and asserts the secret is absent.
  - BR-2: README documents `fd_watchdog_threshold`, the capture location and that arguments are never recorded.
  - BR-3: `notify` is injected per setup, so a late capture callback can't reach another spec's collector; the quiet spec asserts the exact (empty) warnings.
  - Minors: once per process now holds (the timer stops after a capture; setup doesn't re-arm; `_rearm` is spec-only), and `fd_watchdog.count` replaces three copies of the /dev/fd count in the specs (ARCH-DRY).
  - The full suite also caught a direct `vim.fn.mkdir` (`prepare_dir_spec` requires every production mkdir to go through `parley.fs`); it now uses `fs.ensure_dir`.

