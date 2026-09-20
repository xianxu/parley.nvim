# Reap test fixture processes — Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A test run — completed, failed, or interrupted — leaves no `fake_cliproxy`
and no harness `nvim --headless` process behind, and the suite fails loudly if one
survives.

**Architecture:** Three independent reaping layers plus one measurement, each placed
at the single chokepoint its class of process passes through (ARCH-DRY,
ARCH-FUNERAL). (1) Every long-lived HTTP fixture is constructed through
`LoopbackHTTPServer`, so the parent-death watchdog moves into that constructor and
covers every present and future fixture server — including one that production code
spawned detached, where no spec holds a handle. (2) Every harness Neovim — the
`make` parent and every plenary spec child — loads `tests/minimal_init.vim`, so the
same parent-death rule goes there. (3) Every process a spec starts goes through
`tests.helpers.fixture_process`, so the registry and the `VimLeavePre` reap live
there and the eight copy-pasted spec-local registries collapse into it.
(4) `scripts/reap-test-orphans.py` is the measurement: it reads the real process
table with `ps` (never `pgrep`, which does not match these on macOS), reaps this
checkout's survivors, and fails the suite when it found any.

**Tech Stack:** Python 3 (fixtures + the census script), Lua/Neovim (harness
helpers, specs), plenary.nvim (busted runner), GNU/BSD make.

> **This issue cannot be closed from inside an agent sandbox.** The sandbox refuses
> `ps` with EPERM (measured), and three of the four Done-when proofs — M2 Task 5
> Steps 4, 5 and 6 — need a real process table. Everything else, including every
> spec, runs sandboxed: liveness in the specs is probed with `uv.kill(pid, 0)`, and
> the census's selector is tested through an injected process table.

---

## Why the current arrangement leaks

Measured on this machine while planning (2026-09-19): 12 orphaned `fake_cliproxy`
and 13 orphaned `nvim --headless`, oldest 2 days, all `ppid 1`.

The process tree of one spec file is:

```
make → sh (RUN_SPEC) → nvim (parent, -c PlenaryBustedFile) → nvim (plenary child) → python3 fake_cliproxy
```

`nvim --headless` does **not** exit on SIGINT — it treats it as an interrupt. So a
Ctrl-C'd or killed `make` leaves both Neovims running; they reparent to init and sit
idle forever. A wedged child Neovim keeps its fixture's parent alive, so
`fixture_watchdog.py` can never fire. This is why the log's dominant case is the
*interrupted* run and why a teardown on the normal path cannot fix it.

**The defect the prototype found.** `fixture_watchdog.py` exits when
`os.getppid()` *changes* from the value sampled at startup. When a process is
orphaned **before** it samples — the common case, because the harness dies while the
child is still booting — the sample is already `1` and the watchdog never fires.
Reproduced directly, with the flag that is supposed to enable it:

```
PARLEY_FAKE_EXIT_WITH_PARENT=1, parent exits immediately
  change-only rule:              STILL ALIVE at t=4s
  ppid == 1 or ppid != parent:   GONE by t=3s
```

An `nvim` prototype behaved identically. Both watchdogs carry the corrected rule.

---

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `parse_ps` | `scripts/reap-test-orphans.py` | new |
| `select_orphans` | `scripts/reap-test-orphans.py` | new |
| `ancestry` | `scripts/reap-test-orphans.py` | new |
| `orphaned` | `tests/fixtures/fixture_watchdog.py` | new |

- **parse_ps** — turns `ps -Ao pid=,ppid=,args=` text into `[{pid, ppid, args}]`.
  - **Relationships:** 1:N with the rows it yields; no ownership.
  - **DRY rationale:** first occurrence. `tests/fixtures/fake_ps` is *not* reusable
    here: it stands in for `ps ax -o pid,lstart,command` behind
    `cliproxy._set_process_tools`, a different column set read by production code
    for peer detection. This census needs `ppid` (for `ancestry`) and reads `ps`
    from a shell, not from Lua. Two mechanisms, two shapes, no shared consumer.
  - **Future extensions:** an `etime`/`rss` column, if a report ever wants age or
    resident size (the issue log quotes both).

- **select_orphans** — given parsed rows, a checkout root, and pids to exclude,
  returns the rows that belong to that checkout's test harness. A row qualifies
  when its `args` contain `<root>/tests/` **and** it is either a headless Neovim
  (`--headless` in `args`) or a fixture (`<root>/tests/fixtures/` in `args`).
  - **Relationships:** N:1 with a checkout root.
  - **DRY rationale:** one definition of "this checkout's test process", shared by
    the pre-run sweep and the post-run gate.
  - **Why two clauses.** `<root>/tests/` alone is what keeps the rule free of an
    enumeration — it matches every shape the harness *itself* produces (a fixture, a
    plenary spec child carrying an absolute spec path, the `make` parent carrying an
    absolute `-u`) without listing them, and a stale enumeration is what let this go
    unmeasured. But alone it also matches an operator's editor sitting on a spec
    file, and this script sends SIGKILL. The second clause is what makes it safe to
    do that: an interactive `nvim tests/unit/x_spec.lua` has no `--headless` and is
    not under `tests/fixtures/`, so it is never selected.
  - **What it deliberately does NOT select.** `cliproxy_conformance_spec.lua:117`
    spawns the **real** cliproxyapi — `<binary> -config <tmp>.yaml`, with no
    checkout path in its argv — and the census cannot see it. That is correct
    rather than a hole to plug: `lua/parley/cliproxy.lua` spawns that binary
    detached *by design*, so that it outlives Neovim and is shared across
    instances (declared as an intentional open spawn in
    `tests/arch/spawn_seam_spec.lua`'s `OUTSIDE` table). A surviving real proxy is
    product behaviour, not a leak. The registry still gives it a best-effort stop at
    `after_each` and `VimLeavePre`; only a SIGKILLed maintainer-only conformance run
    leaves one, and the atlas names that case rather than the census claiming it.
    Making the census see it would mean writing its config inside the tree, which
    `tests/arch/scratch_placement_spec.lua` forbids (#202).
  - **Future extensions:** a second root, if the fleet ever sweeps every worktree
    at once rather than the one it is running in.

- **ancestry** — the caller's pid and every ancestor of it, walked through the same
  parsed rows. Load-bearing, not defensive: after the `-u` is made absolute, the
  `sh` running a test recipe carries both `--headless` and `<root>/tests/` in its
  own argv, so the census would otherwise SIGKILL the recipe that invoked it.
  - **Relationships:** reads the same rows `select_orphans` filters.

- **orphaned(parent)** — the shared rule, stated identically in Python and in Lua:
  a process is orphaned when `getppid() == 1` or `getppid() ~= parent`.
  - **DRY rationale:** cannot be single-sourced across the language boundary; each
    copy carries the same comment naming the other, and
    `tests/arch/fixture_lifecycle_spec.lua` asserts both copies test against `1`, so
    one cannot silently drift back to change-only.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `LoopbackHTTPServer` | `tests/fixtures/loopback_http.py` | modified | a bound TCP listener |
| `exit_with_parent` (Lua) | `tests/helpers/exit_with_parent.lua` | new | `uv` timer + `os.exit` |
| `fixture_process` | `tests/helpers/fixture_process.lua` | modified | `uv.spawn` |
| `orphan_me.sh` | `tests/fixtures/orphan_me.sh` | new | `sh` job control |
| `reap-test-orphans` | `scripts/reap-test-orphans.py` | new | `ps` and `kill` |

- **LoopbackHTTPServer** — the base class every HTTP fixture already constructs.
  Gains an `__init__` that installs the parent-death watchdog before binding.
  Binding a port *is* the act of becoming long-lived, so this is the chokepoint for
  every fixture **server**.
  - **Injected into:** `fake_cliproxy`, `fake_github_releases`, `fake_sse_server`.
  - **It is not the only blocking shape.** Two fixtures block without ever binding:
    `fake_cliproxy`'s `run_login` (`PARLEY_FAKE_LOGIN_MODE=hangs` sleeps 300 s,
    driven by `tests/integration/cliproxy_login_spec.lua:58` and `:183` — through
    *production* `cliproxy.run_login`, not a direct spawn, which is why that spec is
    absent from Task 3's conversion set but must be in Task 2's verification list)
    and `fake_sips` (`slow` mode, `:16`, sleeps 30 s). Each calls
    `exit_with_parent()` directly. The invariant is
    therefore "every executable fixture reaches `exit_with_parent`, or is declared
    as one that cannot block" — Task 7 invariant 2 — and the constructor is how
    most of them get there, not the whole rule.
  - **Future extensions:** any new HTTP fixture is covered by construction; a new
    blocking non-HTTP fixture fails the guard until it calls the watchdog or is
    declared.

- **exit_with_parent (Lua)** — the Neovim-side twin of `fixture_watchdog.py`. An
  unref'd 1 s `uv` timer; on `orphaned` it calls `os.exit(1)`. Unref'd so it never
  keeps the loop alive or delays a normal exit. `os.exit` is deliberate rather than
  `qa!`: the timer runs in a fast-event context and must not depend on a main loop
  that may be wedged — the orphans measured had each burned 0.05 s of CPU and never
  run a spec. It therefore skips `VimLeavePre`, which is why the fixture layer is
  independent: a fixture reparented by this exit is reaped by its *own* watchdog
  within one poll.
  - **Injected into:** `tests/minimal_init.vim`, which the `make` parent and every
    plenary spec child load.

- **fixture_process** — gains a module-level registry of live handles, a `mark()`
  that names a point in it, a `reap(opts)` that kills what it tracks, and one
  `VimLeavePre` autocmd that calls it. Every spec's spawn is registered by the act
  of spawning.
  - **Injected into:** the eight specs that today keep a private `started` table
    and a private `after_each` reap loop.
  - **Why `mark()` and not a bare `reap()`.** Two specs start a fixture at **file
    scope** and every case depends on it: `cliproxy_update_spec.lua:14` and
    `cliproxy_download_spec.lua:11` each do `local server = fake_releases.start()`
    and point every case at `server.url`. A blanket `reap()` in `after_each` would
    kill it and break every case after the first — which is exactly why
    `cliproxy_update_spec`'s private `reap()` (`:41-53`) deliberately spares it and
    reaps only its per-case `spawned` and `servers` lists. So the registry carries a
    monotonic sequence number per entry; a spec takes `mark()` in `before_each` and
    calls `reap({ since = mark })` in `after_each`. Sequence numbers rather than
    indices, because an entry that exits on its own is pruned and would shift them.
  - **Future extensions:** `reap()` is exported so a spec that needs per-case
    reaping (a port must be free again before the next case) calls it in
    `after_each` instead of rebuilding a registry.

- **orphan_me.sh** — starts a command detached from any surviving parent and
  publishes its pid. The test harness for every orphaning case: it exits at once, so
  the command reparents to init *while it is still booting* — precisely the race the
  change-only rule missed.
  - **Future extensions:** none; it is four lines and deliberately dumb.

- **reap-test-orphans** — `ps`-based census. Two phases: `before` reaps what an
  earlier run left and exits 0; `after` reports and reaps and exits 1. Both print
  every row they act on — it sends SIGKILL, so what it killed is never a number
  alone.
  - **`after` re-polls before it accuses (ARCH-ORDER).** Liveness at one instant is
    not proof of a leak: a fixture reaped at `VimLeavePre` takes a moment to die,
    and `cliproxy_update_spec:486` sets `PARLEY_FAKE_EXIT_DELAY_MS = "4000"`, so
    that fake deliberately keeps serving for 4 s after its SIGTERM. If that spec
    finishes last under `-P 8`, a zero-grace census fails a run that leaked nothing.
    So `after` takes the candidate set, re-samples once a second for `--grace`
    seconds (default 8, above that 4 s delay plus the ~2 s two-layer watchdog
    latency), and reports only the pids present in every sample. A clean run finds
    no candidates and pays nothing.
  - **A `ps` it cannot parse is a failure, not a pass (ARCH-MOCK).** `ps` succeeding
    with columns this script does not understand would parse to zero rows and exit
    0 — the same "remedy that no-ops and reads as success" this issue exists to
    kill, and the failure mode that let `pgrep` hide 89 orphans. So a *successful*
    `ps` must parse at least one row and must contain the census's own pid;
    otherwise it says the census is broken and fails (in `after`). A live
    conformance case runs the real `ps` and asserts exactly that, in the house form
    of `tests/integration/process_group_conformance_spec.lua` — `pending()` where
    `ps` is refused, never a silent skip.
  - **Injected into:** `Makefile.parley`, through one `ORPHANS` variable.
  - **Concurrency:** it cannot distinguish this run's live processes from a second
    concurrent run's in the same checkout. TOOLING.md already requires one `make
    test` per checkout (the scratch root is keyed the same way); this adds a second
    reason and says so.
  - **Future extensions:** `--ps-from FILE` injects a process table for tests and
    signals nothing, which is also the seam a fleet-wide sweep would reuse.

### Test surface

| What | Where | Kind |
|------|-------|------|
| `parse_ps` / `select_orphans` / `ancestry` over a recorded `ps` table | `tests/unit/reap_test_orphans_spec.lua` | drives the script with `--ps-from`, so nothing is signalled |
| a fixture server outlives nothing: orphan it, watch it die | `tests/integration/fixture_reaping_spec.lua` | real process, real orphaning |
| a spec-child Neovim outlives nothing: same | `tests/integration/fixture_reaping_spec.lua` | real process, real orphaning |
| `fixture_process` registers, reaps, and forgets | `tests/integration/fixture_reaping_spec.lua` | real process |
| no spec spawns outside the seam; every server-shaped fixture reaches `LoopbackHTTPServer`; both watchdogs test against `1` | `tests/arch/fixture_lifecycle_spec.lua` | executable enumeration + counterfactual |

Liveness is probed with `uv.kill(pid, 0)`, never `ps` — the specs must pass where
`ps` is refused.

---

## Milestones

Two review boundaries. They are genuinely separable: M1 stops the leak and is
provable on its own; M2 measures it, guards it, and writes it down.

- **M1** — the three reaping layers and the census (Tasks 1–4): everything that
  exists as a *thing*.
- **M2** — wiring, docs, guard (Tasks 5–7): nothing new to name.

**Why the census is in M1 and not with its wiring.**
`tests/arch/single_source_sweeps_spec.lua`'s "every symbol the Spec and plan
tables name exists in the tree" guard reads the whole plan's Core-concepts table
on any issue branch. With the census in M2, `select_orphans` and `ancestry` do not
exist yet at M1's boundary and that guard is red — measured, not predicted. A
boundary a guard cannot be green at is not a boundary. M2 adds no Core-concepts
entity, so the table is fully realized at M1 and stays so.

---

# M1 — Stop the leak, and measure it

### Task 1: The shared orphan rule, in both watchdogs

**Files:**
- Create: `tests/fixtures/orphan_me.sh`
- Modify: `tests/fixtures/fixture_watchdog.py`
- Create: `tests/helpers/exit_with_parent.lua`
- Modify: `tests/minimal_init.vim`
- Create: `tests/integration/fixture_reaping_spec.lua`
- Modify: `atlas/traceability.yaml`

- [ ] **Step 1: Write the orphaning harness, and make it executable**

`tests/fixtures/orphan_me.sh`:

```sh
#!/bin/sh
# Start "$@" detached from any surviving parent; write its pid to $1 (#220).
#
# This script EXITS IMMEDIATELY, so the child reparents to init while it is still
# booting. That is the case the change-only watchdog rule misses: by the time the
# child samples its parent, the sample is already 1.
#
# stdio goes to /dev/null because the child would otherwise INHERIT the caller's
# pipes and hold them open after this script exits — a `vim.system(...):wait()` on
# this script then blocks until its timeout and returns nil. It is also what an
# orphan actually looks like.
pidfile="$1"
shift
"$@" >/dev/null 2>&1 &
echo $! > "$pidfile"
exit 0
```

```bash
chmod +x tests/fixtures/orphan_me.sh
```

- [ ] **Step 2: Write the failing test for the Neovim watchdog**

`tests/integration/fixture_reaping_spec.lua`:

```lua
-- #220: a harness process whose parent is gone must exit on its own. Every
-- assertion here orphans a REAL process and waits for it to die; liveness is
-- probed with uv.kill(pid, 0), never `ps`, which an agent sandbox refuses.
local uv = vim.uv or vim.loop
local ROOT = vim.fn.getcwd()
local ORPHAN = ROOT .. "/tests/fixtures/orphan_me.sh"

--- True once `pid` no longer exists. Signal 0 checks for existence only, and
--- ESRCH is the answer that means "no such process" — EPERM would mean it lives
--- and is merely unsignallable. Same form as
--- tests/integration/process_group_conformance_spec.lua:9.
local function gone(pid)
    local _, _, name = uv.kill(pid, 0)
    return name == "ESRCH"
end

--- Start `argv` orphaned; return its pid.
local function orphan(argv)
    local pidfile = vim.fn.tempname()
    -- :wait(ms) always returns a table — on timeout it kills and reports 124 —
    -- so the exit code is the only thing worth asserting on.
    local done = vim.system(vim.list_extend({ ORPHAN, pidfile }, argv)):wait(5000)
    assert.equals(0, done.code, "orphan_me.sh failed: " .. tostring(done.stderr))
    assert.is_true(vim.wait(3000, function() return vim.fn.filereadable(pidfile) == 1 end, 20),
        "no pid was published")
    local pid = tonumber(vim.trim(table.concat(vim.fn.readfile(pidfile), "")))
    assert.is_truthy(pid, "unreadable pid")
    return pid
end

--- Fail unless `pid` exits within `ms`; always reap it, so a FAILING assertion
--- here cannot itself leak the process it is complaining about.
local function dies_within(pid, ms, what)
    local died = vim.wait(ms, function() return gone(pid) end, 100)
    pcall(function() uv.kill(pid, "sigkill") end)
    assert.is_true(died, what .. " (pid " .. pid .. ") outlived its parent by " .. ms .. "ms")
end

describe("#220 a harness process exits when its parent is gone", function()
    it("a spec-child Neovim does", function()
        local pid = orphan({ "nvim", "-n", "--headless", "--noplugin",
            "-u", ROOT .. "/tests/minimal_init.vim",
            "-c", "lua vim.wait(60000, function() return false end, 100)" })
        dies_within(pid, 6000, "an orphaned harness Neovim")
    end)
end)
```

- [ ] **Step 3: Run it and watch it fail**

```
nvim -n --headless --noplugin -u tests/minimal_init.vim \
  -c "PlenaryBustedFile tests/integration/fixture_reaping_spec.lua" -c "qa!"
```

Expected: FAIL — "an orphaned harness Neovim (pid N) outlived its parent by 6000ms".

- [ ] **Step 4: Write the Lua watchdog**

`tests/helpers/exit_with_parent.lua`:

```lua
-- Exit a harness Neovim when the process that started it is gone (#220).
--
-- The Neovim-side twin of tests/fixtures/fixture_watchdog.py; the RULE below is
-- stated identically in both, and tests/arch/fixture_lifecycle_spec.lua holds them
-- to it.
--
-- `nvim --headless` treats SIGINT as an interrupt, not as an exit, so a Ctrl-C'd
-- or killed `make` leaves the parent AND every plenary spec child running. They
-- reparent to init and sit idle forever: #220 measured 145 of them, ~1.2 GB, some
-- two days old, every one having burned 0.05s of CPU — wedged at startup, never
-- having run a spec.
local uv = vim.uv or vim.loop

local M = {}

--- The rule: a process is orphaned when its parent is init, OR when its parent
--- changed. The `== 1` half is load-bearing and not redundant — a process orphaned
--- while it is still BOOTING samples 1 as its own starting parent, so a rule that
--- only watches for a change never fires for exactly the case that produces these.
--- Measured: a fixture orphaned during startup survived indefinitely under the
--- change-only rule and exited in under a second under this one.
function M.orphaned(parent)
    local ppid = uv.os_getppid()
    return ppid == 1 or ppid ~= parent
end

--- Start watching. Returns the timer, for tests.
---
--- os.exit, not `qa!`: the callback runs in a fast-event context and must not
--- depend on a main loop that may be wedged. That skips VimLeavePre, so this
--- does NOT reap child fixtures — they carry the same watchdog and reap
--- themselves within one poll of being reparented.
---
--- Skipping VimLeavePre also skips whatever cleanup lives there, so a caller with
--- durable state passes it as `before_exit`: it runs (pcall'd) on this path too.
--- tests/minimal_init.vim uses it for the per-process $PARLEY_QUERY_DIR, which
--- #261 M5 found would otherwise accumulate one directory per spec process.
---@param poll_ms integer|nil
---@param before_exit fun()|nil
function M.install(poll_ms, before_exit)
    poll_ms = poll_ms or 1000
    local parent = uv.os_getppid()
    local timer = uv.new_timer()
    timer:unref() -- never keeps the loop alive, never delays a normal exit
    timer:start(poll_ms, poll_ms, function()
        if M.orphaned(parent) then
            if before_exit then pcall(before_exit) end
            os.exit(1)
        end
    end)
    return timer
end

return M
```

- [ ] **Step 5: Install it from the init both the parent and every child load**

In `tests/minimal_init.vim`, at the top of the existing `lua << EOF` block of
harness-only guards:

```lua
-- Every harness Neovim — the `make` parent and every plenary spec child — loads
-- this file, so one call here covers both (#220).
require("tests.helpers.exit_with_parent").install()
```

The query-dir cleanup two blocks below (`:53-55`) must also run on the watchdog's
path, which bypasses `VimLeavePre`. Hoist it to a local and give it to both
triggers, so it stays one definition:

```lua
local function drop_query_dir()
    pcall(vim.fn.delete, vim.env.PARLEY_QUERY_DIR, "rf")
end
vim.api.nvim_create_autocmd("VimLeavePre", { callback = drop_query_dir })
require("tests.helpers.exit_with_parent").install(nil, drop_query_dir)
```

Order matters: `PARLEY_QUERY_DIR` is set just above, so `install` comes after it.

- [ ] **Step 6: Run the test again**

Same command as Step 3. Expected: PASS.

- [ ] **Step 7: Close the same hole in the Python watchdog**

In `tests/fixtures/fixture_watchdog.py`, replace the change-only check:

```python
def orphaned(parent):
    """A fixture is orphaned when its parent is init, OR when its parent changed.

    The `== 1` half is load-bearing and not redundant: a fixture orphaned while it
    is still starting samples 1 as its own parent, so a rule that only watches for
    a CHANGE never fires for exactly the case that produces these (#220). Measured
    with PARLEY_FAKE_EXIT_WITH_PARENT=1 and a parent that exits at once: alive at
    t=4s under the old rule, gone by t=3s under this one. Stated identically in
    tests/helpers/exit_with_parent.lua.
    """
    ppid = os.getppid()
    return ppid == 1 or ppid != parent


def exit_with_parent(poll_seconds=1.0):
    parent = os.getppid()

    def watch():
        while True:
            time.sleep(poll_seconds)
            if orphaned(parent):
                os._exit(0)

    threading.Thread(target=watch, daemon=True).start()
```

- [ ] **Step 8: Route the new spec in the traceability map**

`tests/arch/single_source_sweeps_spec.lua`'s "every spec this branch ADDED is routed
somewhere" guard fails on an issue branch for any added *or untracked* `*_spec.lua`
that routes nowhere. Under `atlas/traceability.yaml`'s `infra/test_harness` entry,
add to `code:`

```yaml
      - tests/helpers/exit_with_parent.lua
      - tests/fixtures/fixture_watchdog.py
      - tests/fixtures/orphan_me.sh
```

and to `tests:`

```yaml
      - tests/integration/fixture_reaping_spec.lua
```

- [ ] **Step 9: Run the traceability guard and the harness specs**

```
for s in tests/arch/single_source_sweeps_spec.lua \
         tests/integration/fixture_reaping_spec.lua \
         tests/unit/spec_runner_spec.lua; do
  nvim -n --headless --noplugin -u tests/minimal_init.vim \
    -c "PlenaryBustedFile $s" -c "qa!" || echo "FAILED: $s"
done
```

Expected: PASS for all three, no `FAILED:` line.

- [ ] **Step 10: Commit**

```bash
git add tests/helpers/exit_with_parent.lua tests/minimal_init.vim \
        tests/fixtures/fixture_watchdog.py tests/fixtures/orphan_me.sh \
        tests/integration/fixture_reaping_spec.lua atlas/traceability.yaml
git commit -m "#220 M1: a harness Neovim exits when its parent is gone"
```

---

### Task 2: Every fixture server exits with its parent, by construction

Today the watchdog is opt-in: `fake_cliproxy` installs it only under
`PARLEY_FAKE_EXIT_WITH_PARENT=1`, which two of its eight spawn sites set.
`fake_github_releases` calls it directly. `fake_sse_server` does not call it at all
and blocks forever in `handle_request()` when the spec that would have made the
request dies first. Binding a loopback port is what makes a fixture server
long-lived, and all three do that through `LoopbackHTTPServer` — so that
constructor is the chokepoint for the server shape (ARCH-DRY).

Two fixtures block **without** binding, and the constructor cannot reach them:
`fake_cliproxy`'s `run_login` (`:184`; `PARLEY_FAKE_LOGIN_MODE=hangs` sleeps 300 s)
and `fake_sips` (`slow` mode, `:16`, sleeps 30 s). Each gets a direct call, so the
rule the guard enforces is "reaches `exit_with_parent`", not "constructs
`LoopbackHTTPServer`".

The hangs login is driven by `tests/integration/cliproxy_login_spec.lua:58` and
`:183`, which call **production** `cliproxy.run_login` — not a direct spawn. So that
spec is correctly outside Task 3's conversion set, and correspondingly easy to leave
out of the verification list, which is the only list that would catch a regression
from `run_login`'s new call. It is in Step 6's list below.

**Files:**
- Modify: `tests/fixtures/loopback_http.py`
- Modify: `tests/fixtures/fake_cliproxy` (drop the opt-in gate and its docs; add the
  direct call in `run_login`)
- Modify: `tests/fixtures/fake_sips` (direct call; its drivers are
  `tests/unit/image_shrink_spec.lua` and `tests/integration/paste_image_spec.lua`,
  and `image_shrink_spec.lua:297` asserts a `[4.5, 8)` elapsed window against the
  `slow` mode this touches)
- Modify: `tests/fixtures/fake_github_releases` (drop the now-duplicate call)
- Modify: `tests/helpers/fake_releases.lua` (drop the env var from the wrapper)
- Modify: `tests/integration/cliproxy_update_spec.lua` (drop the env var)
- Modify: `atlas/providers/cliproxy-managed.md` (the flag it documents is gone)
- Modify: `workshop/issues/000242-*.md` (its requirement 5 names the flag)
- Modify: `tests/integration/fixture_reaping_spec.lua`
- Modify: `atlas/traceability.yaml`

- [ ] **Step 1: Write the failing test**

Add to `tests/integration/fixture_reaping_spec.lua`, inside the same `describe`.
Each fixture is given the arguments it actually requires — `fake_github_releases`
exits immediately with a usage message when `--root` is missing, which would make
its case pass no matter what the watchdog does:

```lua
    it("the fake_cliproxy fixture does", function()
        local port = require("tests.helpers.ready_port").free_port()
        local pid = orphan({ ROOT .. "/tests/fixtures/fake_cliproxy",
            "--port", tostring(port) })
        dies_within(pid, 6000, "an orphaned fake_cliproxy")
    end)

    it("the fake_github_releases fixture does", function()
        local port = require("tests.helpers.ready_port").free_port()
        local root = vim.fn.tempname()
        vim.fn.mkdir(root, "p")
        local pid = orphan({ ROOT .. "/tests/fixtures/fake_github_releases",
            "--port", tostring(port), "--root", root })
        dies_within(pid, 6000, "an orphaned fake_github_releases")
    end)

    it("the fake_sse_server fixture does, even with no request to answer", function()
        -- Its whole body is one blocking handle_request(); a spec that dies before
        -- making its request used to leave it waiting forever.
        local pid = orphan({ ROOT .. "/tests/fixtures/fake_sse_server",
            "normal", vim.fn.tempname() })
        dies_within(pid, 6000, "an orphaned fake_sse_server")
    end)

    it("the fake_cliproxy login path does, though it never binds a port", function()
        -- `hangs` sleeps 300s and returns before any bind, so LoopbackHTTPServer
        -- cannot cover it: run_login calls the watchdog itself.
        local pid = orphan({ ROOT .. "/tests/fixtures/fake_cliproxy", "-claude-login" },
            { PARLEY_FAKE_LOGIN_MODE = "hangs" })
        dies_within(pid, 6000, "an orphaned fake_cliproxy login")
    end)

    it("the fake_sips slow mode does, though it never binds a port", function()
        local pid = orphan({ ROOT .. "/tests/fixtures/fake_sips",
            "--out", vim.fn.tempname() }, { PARLEY_FAKE_SIPS = "slow" })
        dies_within(pid, 6000, "an orphaned fake_sips")
    end)
```

`orphan()` gains an optional second argument for environment, passed through to
`vim.system`'s `env`:

```lua
local function orphan(argv, env)
    local pidfile = vim.fn.tempname()
    local done = vim.system(vim.list_extend({ ORPHAN, pidfile }, argv),
        env and { env = env } or {}):wait(5000)
```

- [ ] **Step 2: Run, and check each case fails for the right reason**

Run the spec. Expected: `fake_cliproxy` (both cases), `fake_sse_server` and
`fake_sips` FAIL ("outlived its parent"); `fake_github_releases` PASSES already,
through its direct call.

Before proceeding, confirm that pass is real and not a usage-exit — the fixture
`sys.exit("usage: …")`s without `--root` (`:58-59`), which would make the case pass
whatever the watchdog does. Use an unprivileged port, since port 1 raises
`PermissionError` and so distinguishes neither outcome:

```sh
tests/fixtures/fake_github_releases --port 45998 --root "$(mktemp -d)" &
sleep 1; curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:45998/; kill %1
```

Expected: a status code, not a usage line — i.e. it was actually serving.

- [ ] **Step 3: Move the watchdog into the constructor**

`tests/fixtures/loopback_http.py`:

```python
"""HTTP fixtures bind numeric loopback addresses without consulting reverse DNS.

Binding a port is the moment a fixture becomes long-lived, and every fixture server
in this tree binds through this class — so this is also where they are given their
end (#220, ARCH-FUNERAL). A fixture reparented to init outlives its spec forever:
#220 measured 897 of them holding ~10 GB. Opting in per fixture is what left
fake_sse_server, and six of fake_cliproxy's eight spawn sites, uncovered.
"""
import os
import sys
from http.server import HTTPServer
from socketserver import TCPServer

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fixture_watchdog import exit_with_parent  # noqa: E402


class LoopbackHTTPServer(HTTPServer):
    def __init__(self, *args, **kwargs):
        exit_with_parent()
        HTTPServer.__init__(self, *args, **kwargs)

    def server_bind(self):
        # HTTPServer.server_bind calls getfqdn(), which can block in the guest's
        # mDNS resolver before listen(). These fixtures need only literal identity.
        TCPServer.server_bind(self)
        self.server_name, self.server_port = self.server_address[:2]
```

- [ ] **Step 4: Delete the now-duplicate opt-ins, and every mention of the flag**

In `tests/fixtures/fake_cliproxy`: remove the `if
os.environ.get("PARLEY_FAKE_EXIT_WITH_PARENT") == "1": exit_with_parent()` block and
the `from fixture_watchdog import exit_with_parent` import; replace the docstring
sentence "With PARLEY_FAKE_EXIT_WITH_PARENT=1 the fake exits when its parent does
(#220)." with "It exits when its parent does, through LoopbackHTTPServer (#220)."

Also in `tests/fixtures/fake_cliproxy`, add the direct call at the top of
`run_login` (`:184`), with a comment saying why it cannot come from the
constructor:

```python
def run_login(login_mode, auth_store):
    # This path never binds, so LoopbackHTTPServer cannot give it its end (#220):
    # `hangs` sleeps 300s and returns. Call the watchdog here instead.
    exit_with_parent()
```

which means `fake_cliproxy` keeps its `from fixture_watchdog import
exit_with_parent` — only the env-gated call at the top of `main()` goes.

Add the same call to `tests/fixtures/fake_sips`, guarded to its blocking mode, with
the import and `sys.path` line it needs.

In `tests/fixtures/fake_github_releases`: remove the `exit_with_parent()` call and
its import, leaving a one-line comment pointing at `LoopbackHTTPServer`.

In `tests/helpers/fake_releases.lua`'s wrapper script, remove the
`PARLEY_FAKE_EXIT_WITH_PARENT=1` assignment line and its comment, and **edit** —
do not delete — the export line:

```lua
        "PARLEY_FAKE_CPA_VERSION=" .. vim.fn.shellescape(ver),
        "export PARLEY_FAKE_CPA_VERSION",
```

Line 81 today reads `"export PARLEY_FAKE_CPA_VERSION PARLEY_FAKE_EXIT_WITH_PARENT"`
and also exports the version that the `X-Cpa-Version` observation in #237's update
specs depends on; deleting the whole line would break them.

In `tests/integration/cliproxy_update_spec.lua`'s `spawn_fake`, the
`vim.tbl_extend` collapses to `env or {}`.

Two documents name the flag and go stale:
`atlas/providers/cliproxy-managed.md:479` and
`workshop/issues/000242-arch-mock-stateful-fake-per-chat-provider.md:103`
(requirement 5, "Every spawned fake uses `PARLEY_FAKE_EXIT_WITH_PARENT=1`") — the
latter is an open issue whose requirement is now satisfied by construction, so
restate it as such rather than deleting it.

- [ ] **Step 5: Confirm the name is gone**

```
grep -rn PARLEY_FAKE_EXIT_WITH_PARENT . --exclude-dir=.git --exclude-dir=history
```

`--exclude-dir` matches a directory **name**, not a path, so `workshop/history`
would not work — and `workshop/history/plans/000237-proxy-update-latest-plan.md`
carries seven live mentions that would otherwise look like misses.

Expected: matches only in `workshop/issues/000220-*.md`,
`workshop/plans/000220-*.md` and `workshop/issues/000242-*.md` (as this issue's own
prose and #242's restated requirement), and nowhere in `tests/`, `lua/`, `scripts/`
or `atlas/`.

- [ ] **Step 6: Run the reaping spec and every spec that drives a fixture server**

**Derive the list, do not type it.** Every spec list in this plan is computed by a
command the plan states — a typed one is how `cliproxy_auth_login_spec` and
`image_shrink_live_spec` got named as drivers of fixtures they never touch. The
set is "every spec that drives a fixture this task changed", and each fixture is
selected by the thing that selects its behaviour:

```sh
# The three servers, by the class they now inherit their end from,
# plus the two blocking modes, by the variable that selects each.
grep -rl 'fake_cliproxy\|fake_github_releases\|fake_sse_server' tests/ --include='*_spec.lua'
grep -rl 'PARLEY_FAKE_LOGIN_MODE\|PARLEY_FAKE_SIPS' tests/ --include='*_spec.lua'
```

At the time of writing the second grep yields `tests/integration/cliproxy_login_spec.lua`
(the hangs login, `:58` and `:183`) and `tests/unit/image_shrink_spec.lua` plus
`tests/integration/paste_image_spec.lua` (`fake_sips`). Those three matter most:
they drive the two modes whose watchdog call is **new**, so a fixture that now
exits on its own could break a spec that relied on it blocking.
`image_shrink_spec.lua:297` is the sharp one — it asserts a 124 exit and an elapsed
time in `[4.5, 8)` against `fake_sips` `slow`, which is exactly the timing a new
`exit_with_parent()` could perturb.

```
for s in $(grep -rl 'fake_cliproxy\|fake_github_releases\|fake_sse_server\|PARLEY_FAKE_LOGIN_MODE\|PARLEY_FAKE_SIPS' \
             tests/ --include='*_spec.lua' | sort -u) \
           tests/integration/fixture_reaping_spec.lua; do
  nvim -n --headless --noplugin -u tests/minimal_init.vim \
    -c "PlenaryBustedFile $s" -c "qa!" || echo "FAILED: $s"
done
```

Expected: no `FAILED:` line. A spec that `pending()`s (a live-only case) is not
evidence — check that `image_shrink_spec`'s slow-child case actually ran.

- [ ] **Step 7: Commit**

Add `tests/fixtures/loopback_http.py` and `tests/fixtures/fake_sips` to
`atlas/traceability.yaml`'s `infra/test_harness` `code:` list first — Task 1 routed
the watchdog and the orphaning harness, these two are the rest of the corpus this
issue touches.

```bash
git add tests/fixtures/loopback_http.py tests/fixtures/fake_cliproxy \
        tests/fixtures/fake_sips \
        tests/fixtures/fake_github_releases tests/helpers/fake_releases.lua \
        tests/integration/cliproxy_update_spec.lua \
        tests/integration/fixture_reaping_spec.lua \
        atlas/providers/cliproxy-managed.md atlas/traceability.yaml \
        workshop/issues/000242-arch-mock-stateful-fake-per-chat-provider.md
git commit -m "#220 M1: a fixture server gets its end from LoopbackHTTPServer"
```

---

### Task 3: One registry for every process a spec starts

Eight specs keep a private `started` table, a private `start_fake`, and a private
`after_each` reap loop — near-identical, and every one of them reaches `uv.spawn`
directly rather than through `tests.helpers.fixture_process`, so none gets the
merged environment or the `PYTHONDONTWRITEBYTECODE` guard the seam provides. `#237`'s
review deferred this consolidation (BR-5) to this issue.

Enumerate the set at the moment you start, rather than reading a list that drifted
while Tasks 1 and 2 landed:

```sh
grep -rln 'uv\.spawn(' tests/ | grep -v tests/helpers/fixture_process.lua
```

At the time of writing that is eight specs — `cliproxy_lifecycle` (4 sites),
`cliproxy_catalog` (6), `cliproxy_dispatch`, `cliproxy_caller_teardown`,
`cliproxy_recovery_e2e`, `cliproxy_auth_login`, `openai_tool_loop`, and
`cliproxy_conformance` (1 each) — plus `query_cache_spec`, which only saves and
restores `uv.spawn` and is not a call. Re-run the grep after each conversion; it
reaching empty is the completion condition, and Task 7 invariant 1 is what keeps it
empty afterwards.

`cliproxy_conformance_spec` spawns the **real** cliproxyapi, not a fake. It belongs
here for exactly that reason: a real binary cannot be given a watchdog, so the
registry is the only layer that can reap it, and it currently has no coverage beyond
a normal `after_each`.

**Files:**
- Modify: `tests/helpers/fixture_process.lua`
- Modify: the eight specs above, plus `tests/integration/cliproxy_update_spec.lua`
  (already on the seam; it gains `reap()` in place of its private registry)
- Modify: `tests/integration/fixture_reaping_spec.lua`

- [ ] **Step 1: Write the failing test**

Add to `tests/integration/fixture_reaping_spec.lua`:

```lua
describe("#220 census conformance, against the real ps", function()
    -- ARCH-MOCK: --ps-from is the seam and ps_test_orphans.txt is the recorded
    -- state, but a recording cannot notice the day the real ps changes shape. This
    -- is the live half: the census must find ITSELF in a real process table.
    local SCRIPT = ROOT .. "/scripts/reap-test-orphans.py"

    it("reads a real ps, or says why it cannot", function()
        if vim.fn.executable("ps") == 0 then
            return pending("ps is not executable here")
        end
        -- --grace 0: nothing is expected to be found, and a grace window would only
        -- slow the case if something were.
        local out = vim.system({ "python3", SCRIPT, "--root", vim.fn.tempname(),
            "--phase", "after", "--grace", "0" }, { text = true }):wait(30000)
        assert.equals(0, out.code, out.stdout)
        if out.stdout:find("skipped", 1, true) then
            return pending("ps is refused here (an agent sandbox); census not exercised")
        end
        assert.is_falsy(out.stdout:find("BROKEN", 1, true),
            "the real ps produced columns parse_ps cannot read:\n" .. out.stdout)
    end)
end)

describe("#220 the fixture seam owns every process it starts", function()
    local fixture_process = require("tests.helpers.fixture_process")
    local ready_port = require("tests.helpers.ready_port")

    -- Each case starts from an empty registry, so the absolute live() assertions
    -- below do not depend on the case before them having reaped.
    before_each(function() fixture_process.reap() end)

    local function start()
        local port = ready_port.free_port()
        local handle, _, err, pid = fixture_process.spawn(
            ROOT .. "/tests/fixtures/fake_cliproxy", { "--port", tostring(port) })
        assert.is_truthy(handle, tostring(err))
        assert.is_true(ready_port.wait_listening(port), "the fake never came up")
        return pid
    end

    it("reap() kills what spawn() started, and forgets it", function()
        local before = fixture_process.live()
        local pid = start()
        assert.equals(before + 1, fixture_process.live())

        fixture_process.reap()
        assert.equals(0, fixture_process.live())
        assert.is_true(vim.wait(5000, function() return gone(pid) end, 50),
            "reap() left pid " .. tostring(pid) .. " alive")
    end)

    it("reap({since = mark}) spares what was started before the mark", function()
        -- The case two specs actually need: cliproxy_update_spec:14 and
        -- cliproxy_download_spec:11 each start a release server at FILE scope and
        -- point every case at it. A blanket reap in after_each kills it and breaks
        -- every case after the first.
        local kept = start()
        local mark = fixture_process.mark()
        local transient = start()

        fixture_process.reap({ since = mark })
        assert.is_true(vim.wait(5000, function() return gone(transient) end, 50),
            "the marked reap left pid " .. tostring(transient) .. " alive")
        assert.is_false(gone(kept), "the marked reap killed a file-scope fixture")
        assert.equals(1, fixture_process.live())

        fixture_process.reap()
        assert.is_true(vim.wait(5000, function() return gone(kept) end, 50))
    end)

    it("forgets a process that exited on its own, so live() cannot over-count", function()
        -- `crash` mode exits(1) at startup. Without pruning on exit, live() would
        -- keep counting it and a spec asserting "I left nothing behind" would fail
        -- for a process that is already gone.
        local handle, exited = fixture_process.spawn(
            ROOT .. "/tests/fixtures/fake_cliproxy", { "--port", "1", "--mode", "crash" })
        assert.is_truthy(handle)
        assert.is_true(vim.wait(5000, exited, 50), "the crash-mode fake never exited")
        assert.equals(0, fixture_process.live())
    end)

    it("reaps with the signal the caller asks for", function()
        -- cliproxy_update_spec's restart-race cases need SIGTERM: fake_cliproxy
        -- models graceful shutdown under PARLEY_FAKE_EXIT_DELAY_MS, and SIGKILL
        -- would make that window unobservable.
        local pid = start()
        fixture_process.reap({ signal = "sigterm" })
        assert.is_true(vim.wait(5000, function() return gone(pid) end, 50),
            "sigterm did not stop pid " .. tostring(pid))
    end)
end)
```

- [ ] **Step 2: Run and watch it fail**

Expected: FAIL — `fixture_process.live` is nil, and `spawn` returns no pid.

- [ ] **Step 3: Give the seam a registry**

In `tests/helpers/fixture_process.lua`, extend the header comment and add:

```lua
-- Every process started here is registered and killed at VimLeavePre, so a spec
-- that never reaches its own teardown — a failing assertion, an error at load —
-- cannot orphan one (#220). Eight specs each kept a private copy of this table and
-- this loop, and every one of them bypassed this seam; the registry lives with the
-- spawn so a new spec inherits it rather than remembering it (ARCH-DRY).
--
-- This is the normal-exit half only. A killed or wedged Neovim never runs
-- VimLeavePre, and that is the dominant case: the fixtures carry their own
-- parent-death watchdog for it (tests/fixtures/fixture_watchdog.py). The one
-- process here that CANNOT — the real cliproxyapi, spawned by
-- cliproxy_conformance_spec — is why this layer exists at all rather than being
-- subsumed by the watchdog.
-- Entries carry a monotonic sequence number, not an index: a process that exits on
-- its own is pruned, and indices would shift under a mark taken before it.
local registry = {}   -- { { handle = <uv handle>, seq = <integer> }, … }
local last_seq = 0

--- A point in the registry. Everything spawned AFTER it is reaped by
--- `reap({ since = mark })`; everything before is spared.
---
--- Two specs need this: cliproxy_update_spec and cliproxy_download_spec each start
--- a release server at FILE scope and point every case at it, so a blanket reap in
--- after_each would break every case after the first.
function M.mark()
    return last_seq
end

--- How many spawned processes are still running and tracked (after `since`).
function M.live(since)
    local n = 0
    for _, entry in ipairs(registry) do
        if not since or entry.seq > since then n = n + 1 end
    end
    return n
end

--- Kill tracked processes and forget them. Idempotent.
---
--- SIGKILL by default, because this is teardown: nothing downstream observes the
--- shutdown. A spec that needs a graceful stop to be observable passes
--- `signal = "sigterm"` (fake_cliproxy models graceful shutdown under
--- PARLEY_FAKE_EXIT_DELAY_MS).
---@param opts { since: integer|nil, signal: string|nil }|nil
function M.reap(opts)
    opts = opts or {}
    local kept = {}
    for _, entry in ipairs(registry) do
        if opts.since and entry.seq <= opts.since then
            kept[#kept + 1] = entry
        else
            pcall(function()
                if not entry.handle:is_closing() then
                    entry.handle:kill(opts.signal or "sigkill")
                end
            end)
        end
    end
    registry = kept
end

vim.api.nvim_create_autocmd("VimLeavePre", { callback = function() M.reap() end })
```

In `M.spawn`, register the handle, prune it on exit, and return the pid as a fourth
value:

```lua
    local exited = false
    local handle, pid, err
    handle, pid = uv.spawn(script, { args = args, env = env }, function()
        exited = true
        for i, entry in ipairs(registry) do
            if entry.handle == handle then
                table.remove(registry, i)
                break
            end
        end
        if handle and not handle:is_closing() then
            handle:close()
        end
    end)
    if not handle then
        -- On failure libuv returns nil plus the message; `pid` holds it.
        err = pid
        return nil, function() return true end, err
    end
    last_seq = last_seq + 1
    registry[#registry + 1] = { handle = handle, seq = last_seq }
    return handle, function() return exited end, nil, pid
```

`handle` is pre-declared as a local, so the exit callback's upvalue is bound by the
time libuv runs it; `reap` rebinds `registry` to a fresh table, so a callback that
fires after a reap searches the new table and harmlessly finds nothing. The table is
`registry`, not `live`, so it does not read as a shadow of the `M.live` function.

Update the `@return` doc comment. Note for reviewers: on the SUCCESS path the third
value changes from libuv's pid to `nil`. All four existing callers
(`cliproxy_update_spec:34`, `fixture_ready_publish_spec:37`, `query_cache_spec:40`,
`fake_releases.lua:40`) bind it only to feed an assert message, so none needs a
change — but the contract did move, and the doc comment must say so.

- [ ] **Step 4: Run the test**

Expected: PASS, all four cases (reap / marked reap / prune-on-exit / sigterm).

- [ ] **Step 5: Move each spec onto the seam, one spec per commit**

For each of the nine specs, replace the private `uv.spawn`/`started`/reap trio.
Worked example — `tests/integration/cliproxy_catalog_spec.lua`:

```lua
local fixture_process = require("tests.helpers.fixture_process")

local function start_fake(port)
    local handle, _, err, pid = fixture_process.spawn(FAKE, { "--port", tostring(port) })
    assert(handle, "failed to spawn fake_cliproxy: " .. tostring(err))
    assert(ready_port.wait_listening(port), "fake never came up")
    return pid
end
```

and every `for _, p in ipairs(started) do ... end; started = {}` becomes a reap.
Five rules for the conversion:

1. **Take a mark, reap since it.** Add `local mark` at file scope, `mark =
   fixture_process.mark()` in `before_each`, and `fixture_process.reap({ since =
   mark })` in `after_each`. A bare `reap()` is only correct for a spec that starts
   nothing at file scope — and `cliproxy_update_spec:14` and
   `cliproxy_download_spec:11` both do (`local server = fake_releases.start()`),
   so get this right before converting either. Note the asymmetry:
   `cliproxy_update_spec` has a reap loop to convert, while
   `cliproxy_download_spec` has **none** — it relies entirely on the per-server
   `VimLeavePre` autocmd this step deletes, so for that spec the conversion is the
   registry taking that job over, and there is no loop to go looking for.
2. Where a spec sends `sigterm` deliberately (`cliproxy_update_spec:45`), pass it:
   `fixture_process.reap({ since = mark, signal = "sigterm" })`.
3. `cliproxy_update_spec`'s **third** teardown list — `servers`, populated at `:592`
   and stopped with `fake_releases.stop` — also goes: those servers come from
   `fake_releases.start`, which spawns through the seam (`fake_releases.lua:40`), so
   the marked reap already covers them. Delete the list, not just the loop.
4. Where a spec also reaps `cliproxy.spawned_pids()` — the proxies *production*
   code spawned detached — keep that loop. Those have no handle here, which is
   precisely why Task 2's constructor-level watchdog is the layer that covers them.
5. `cliproxy_conformance_spec.lua` spawns the real binary and keeps its `proc`
   variable for the cases that read it; only the spawn and the teardown move. Note
   that this one is beyond the census's reach by design — see `select_orphans`'s
   "What it deliberately does NOT select".

While here, delete the per-server `VimLeavePre` autocmd in `fake_releases.start`
(`tests/helpers/fake_releases.lua:49-54`): the registry now owns that, and one
autocmd per started server is its own small accumulation (ARCH-DRY, ARCH-FUNERAL).

Run each spec after converting it:

```
nvim -n --headless --noplugin -u tests/minimal_init.vim \
  -c "PlenaryBustedFile tests/integration/<spec>.lua" -c "qa!"
```

Expected: PASS.

- [ ] **Step 6: Commit per spec**

```bash
git add tests/helpers/fixture_process.lua tests/integration/<spec>.lua
git commit -m "#220 M1: <spec> reaps through the fixture seam"
```

---

### Task 4: The census — find survivors with `ps`, and fail

**Files:**
- Create: `scripts/reap-test-orphans.py`
- Create: `tests/fixtures/ps_test_orphans.txt`
- Create: `tests/unit/reap_test_orphans_spec.lua`
- Modify: `atlas/traceability.yaml`

- [ ] **Step 1: Record a process table to select against**

`tests/fixtures/ps_test_orphans.txt` — real row shapes, from the measurement taken
while planning, plus the three near-misses the selector must get right. Columns are
`pid ppid args`, as `ps -Ao pid=,ppid=,args=` prints them.

```
 7458     1 /opt/homebrew/.../Python /Users/x/workspace/parley.nvim/tests/fixtures/fake_cliproxy --port 55546
27095     1 /opt/homebrew/opt/nvim-0.11/bin/nvim --headless -c set rtp+=.,/Users/x/.local/share/nvim/lazy/plenary.nvim | runtime plugin/plenary.vim --noplugin -u tests/minimal_init.vim -c lua require("plenary.busted").run("/Users/x/workspace/parley.nvim/tests/unit/refusal_spec.lua")
31000     1 /opt/homebrew/opt/nvim-0.11/bin/nvim --headless -c lua require("plenary.busted").run("/Users/x/workspace/other-repo/tests/unit/a_spec.lua")
31001   999 /usr/bin/nvim /Users/x/workspace/parley.nvim/tests/unit/refusal_spec.lua
99999   888 /bin/sh -c nvim -n --headless --noplugin -u /Users/x/workspace/parley.nvim/tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/a_spec.lua" -c "qa!"
99998 99999 python3 /Users/x/workspace/parley.nvim/scripts/reap-test-orphans.py --root /Users/x/workspace/parley.nvim --phase after --ps-from /Users/x/workspace/parley.nvim/tests/fixtures/ps_test_orphans.txt
```

Row 99998 carries `--ps-from <root>/tests/fixtures/…` deliberately: that is how the
test actually invokes it, and it makes the row satisfy **both** selection clauses,
so excluding it is the self-pid check doing real work rather than the path rule
passing it over by accident.

What each row pins:

| Row | Shape | Selected? | Why |
|---|---|---|---|
| 7458 | orphaned fixture | yes | under `<root>/tests/fixtures/` |
| 27095 | orphaned plenary spec child | yes | `--headless` + the absolute spec path |
| 31000 | another checkout's spec child | no | its path is not under this root |
| 31001 | **the operator's editor, open on a spec file** | no | names a path under `<root>/tests/` but is not headless and not a fixture — this row is why the selector has a second clause, because the census sends SIGKILL |
| 99999 | the recipe `sh` that invoked the census | no | matches on both clauses, and is excluded only by `ancestry` — this is the row that would otherwise make `make` kill its own recipe |
| 99998 | the census itself, a child of 99999 | no | matches on both clauses; excluded as the first element of the same walk |

- [ ] **Step 2: Write the failing test**

`tests/unit/reap_test_orphans_spec.lua`:

```lua
-- #220: the census that makes the leak visible. Driven with --ps-from, which
-- injects a process table and signals nothing, so this spec can never kill a
-- real pid (the recorded pids WOULD be real pids on some machine).
local SCRIPT = vim.fn.getcwd() .. "/scripts/reap-test-orphans.py"
local TABLE = vim.fn.getcwd() .. "/tests/fixtures/ps_test_orphans.txt"
local ROOT = "/Users/x/workspace/parley.nvim"

local function run(root, phase, extra)
    local argv = { "python3", SCRIPT, "--root", root, "--phase", phase,
        "--ps-from", TABLE, "--self-pid", "99998" }
    return vim.system(vim.list_extend(argv, extra or {}), { text = true }):wait(10000)
end

describe("#220 orphan census", function()
    it("selects exactly this checkout's leaked harness processes", function()
        local out = run(ROOT, "after")
        assert.equals(1, out.code, "survivors must fail the run")
        -- The COUNT pins the whole selection; naming members alone would let a
        -- future narrowing drop one silently.
        assert.is_truthy(out.stdout:find("2 test process(es)", 1, true), out.stdout)
        assert.is_truthy(out.stdout:find("7458", 1, true), "the fixture orphan")
        assert.is_truthy(out.stdout:find("27095", 1, true), "the spec-child orphan")
    end)

    it("leaves another checkout's processes alone", function()
        assert.is_falsy(run(ROOT, "after").stdout:find("31000", 1, true))
    end)

    it("leaves an editor open on a spec file alone", function()
        -- It names a path under <root>/tests/, so the path rule alone would
        -- SIGKILL the operator's editor.
        assert.is_falsy(run(ROOT, "after").stdout:find("31001", 1, true))
    end)

    it("never selects itself or the recipe that invoked it", function()
        -- 99999 is a headless-Neovim recipe line under this root: it matches both
        -- clauses and is excluded only by walking the caller's ancestry.
        local out = run(ROOT, "after")
        assert.is_falsy(out.stdout:find("99999", 1, true), "the invoking recipe")
        assert.is_falsy(out.stdout:find("99998", 1, true), "the census itself")
    end)

    it("passes when the table holds none of this checkout's", function()
        assert.equals(0, run("/Users/x/workspace/elsewhere", "after").code)
    end)

    it("reports but never fails the run in the before phase", function()
        local out = run(ROOT, "before")
        assert.equals(0, out.code)
        assert.is_truthy(out.stdout:find("earlier run", 1, true))
        -- It SIGKILLs, so it says what it killed in both phases.
        assert.is_truthy(out.stdout:find("7458", 1, true), out.stdout)
    end)

    it("fails loudly when ps RAN but its columns cannot be read", function()
        -- Not the same as ps being absent. A successful ps this script cannot
        -- parse yields zero rows and would otherwise exit 0 — a census reporting
        -- no leaks forever, which is the pgrep failure shape all over again.
        local garbage = vim.fn.tempname()
        vim.fn.writefile({ "USER PID %CPU COMMAND", "xianxu 1 0.0 /sbin/launchd" }, garbage)
        local out = vim.system({ "python3", SCRIPT, "--root", ROOT, "--phase", "after",
            "--ps-from", garbage, "--self-pid", "99998" }, { text = true }):wait(10000)
        assert.equals(1, out.code)
        assert.is_truthy(out.stdout:find("BROKEN", 1, true), out.stdout)
    end)

    it("skips visibly, and passes, where ps is refused", function()
        -- The agent sandbox refuses ps with EPERM. A gate that failed there would
        -- be turned off; a gate that passed silently would report nothing.
        local out = vim.system({ "python3", SCRIPT, "--root", vim.fn.getcwd(),
            "--phase", "after", "--ps-command", "/nonexistent/ps" },
            { text = true }):wait(10000)
        assert.equals(0, out.code)
        assert.is_truthy(out.stdout:lower():find("skipped", 1, true))
    end)
end)
```

- [ ] **Step 3: Run it and watch it fail**

```
nvim -n --headless --noplugin -u tests/minimal_init.vim \
  -c "PlenaryBustedFile tests/unit/reap_test_orphans_spec.lua" -c "qa!"
```

Expected: FAIL — the script does not exist.

- [ ] **Step 4: Write the script**

`scripts/reap-test-orphans.py`:

```python
#!/usr/bin/env python3
"""Find and reap test processes this checkout left behind (#220).

`pgrep -f` does NOT match these on macOS — measured twice, five days apart:
`pgrep -fc fake_cliproxy` answered 0 while `ps -Ao args= | grep -c '[f]ake_cliproxy'`
answered 91. So the census reads `ps` and nothing else; any remedy written with
pgrep silently no-ops and reads as success.

Selection is by PATH, plus one narrowing clause. A row belongs to this checkout
when its arguments mention `<root>/tests/` AND it is either a headless Neovim or a
process under `<root>/tests/fixtures/`.

The path rule is what keeps this free of an enumeration: it matches every shape the
harness produces — a fixture, a plenary spec child carrying an absolute spec path,
the `make` parent carrying an absolute -u — without listing them, and a stale
enumeration is what let this leak go unmeasured. The second clause exists because
this script sends SIGKILL: without it, an operator's editor sitting on a spec file
would be selected and killed.

The caller's own pid and its ancestors are excluded. That is load-bearing, not
defensive: a test recipe's `sh` carries the whole `nvim --headless ... -u
<root>/tests/minimal_init.vim` command line in its own argv, so the census would
otherwise kill the recipe that invoked it.

This cannot tell one run's live processes from a concurrent run's in the same
checkout. TOOLING.md already requires one `make test` per checkout — the scratch
root is keyed the same way — and this is the second reason.

Phases (both print every row they act on, because both SIGKILL):
  before  reap what an earlier run left; exit 0. Runs before every suite.
  after   report each survivor, reap it, exit 1. A run must leave none.

`after` re-samples for --grace seconds before accusing anything. Liveness at one
instant is not proof of a leak: a VimLeavePre reap takes a moment to land, and
cliproxy_update_spec sets PARLEY_FAKE_EXIT_DELAY_MS=4000 so that fake deliberately
keeps serving for four seconds after its SIGTERM. Only a pid present in every
sample is reported. A clean run finds no candidates and pays nothing.

Two ways this can fail, and they are not the same:
  ps could not RUN      an agent sandbox refuses it with EPERM. Say so, exit 0 —
                        a gate that failed there would just be switched off.
  ps ran, we cannot     its columns drifted. That is a BROKEN census, and it must
  read it               not look like a clean run: a successful ps must parse at
                        least one row and must contain our own pid, or `after`
                        fails. This is the same failure shape as the pgrep remedy
                        that answered 0 while 91 orphans were resident.
"""
import argparse
import os
import signal
import subprocess
import sys
import time

PS_ARGV = ["ps", "-Ao", "pid=,ppid=,args="]


def parse_ps(text):
    """Rows of `ps -Ao pid=,ppid=,args=` as [{"pid": int, "ppid": int, "args": str}]."""
    rows = []
    for line in text.splitlines():
        parts = line.split(None, 2)
        if len(parts) < 3:
            continue
        try:
            rows.append({"pid": int(parts[0]), "ppid": int(parts[1]), "args": parts[2]})
        except ValueError:
            continue  # a header, or a row whose pid column is not a number
    return rows


def select_orphans(rows, root, exclude=()):
    """Rows belonging to `root`'s test harness, excluding `exclude` pids."""
    tests = os.path.join(root, "tests") + os.sep
    fixtures = os.path.join(tests, "fixtures") + os.sep
    exclude = set(exclude)
    chosen = []
    for row in rows:
        if row["pid"] in exclude or tests not in row["args"]:
            continue
        if "--headless" in row["args"] or fixtures in row["args"]:
            chosen.append(row)
    return chosen


def ancestry(rows, pid):
    """`pid` and every ancestor of it, so the census never reports itself or the
    recipe that invoked it."""
    by_pid = {row["pid"]: row for row in rows}
    seen = []
    while pid and pid not in seen:
        seen.append(pid)
        row = by_pid.get(pid)
        pid = row["ppid"] if row else None
    return seen


def read_process_table(ps_command, ps_from):
    """The process table, or None when it cannot be read."""
    if ps_from:
        with open(ps_from, encoding="utf-8") as handle:
            return handle.read()
    argv = list(PS_ARGV)
    argv[0] = ps_command
    try:
        done = subprocess.run(argv, capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.SubprocessError):
        return None  # refused (an agent sandbox), missing, or hung
    if done.returncode != 0:
        return None
    return done.stdout


def sample(ps_command, ps_from, self_pid):
    """One reading of the process table: (rows, why_not).

    `why_not` is "unreadable" when ps could not run at all — a skip — and
    "unparsable" when it RAN and produced something this script cannot read. The
    second is a broken census, not an absent one, and must never look like a pass:
    a successful ps that yields no rows, or one that does not contain our own pid,
    means the column format drifted out from under parse_ps.
    """
    text = read_process_table(ps_command, ps_from)
    if text is None:
        return None, "unreadable"
    rows = parse_ps(text)
    if not rows or not any(row["pid"] == self_pid for row in rows):
        return None, "unparsable"
    return rows, None


def reap(rows):
    for row in rows:
        try:
            os.kill(row["pid"], signal.SIGKILL)
        except OSError:
            pass  # it exited between the census and the signal


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", required=True, help="the checkout to sweep")
    parser.add_argument("--phase", required=True, choices=("before", "after"))
    parser.add_argument("--ps-from", help="read the process table from a file and "
                                          "signal nothing (for tests)")
    parser.add_argument("--ps-command", default="ps")
    parser.add_argument("--self-pid", type=int, default=os.getpid(),
                        help="the pid to treat as this census's own; only "
                             "meaningful with --ps-from, which signals nothing")
    parser.add_argument("--grace", type=float, default=8.0,
                        help="seconds to keep re-sampling before calling a "
                             "candidate a leak; 0 disables (default 8)")
    args = parser.parse_args()

    root = os.path.realpath(args.root)
    dry_run = args.ps_from is not None

    def census():
        rows, why_not = sample(args.ps_command, args.ps_from, args.self_pid)
        if rows is None:
            return None, why_not
        return select_orphans(rows, root, exclude=ancestry(rows, args.self_pid)), None

    orphans, why_not = census()
    if why_not == "unreadable":
        print("orphan check skipped: `ps` is unavailable here, so surviving test "
              "processes cannot be counted")
        return 0
    if why_not == "unparsable":
        print("orphan check BROKEN: `%s` ran but produced no row this script can "
              "read (not even its own pid %d)." % (args.ps_command, args.self_pid))
        print("parse_ps expects `pid ppid args` columns. A census that cannot read "
              "ps reports zero leaks forever — see TOOLING.md.")
        return 0 if args.phase == "before" else 1

    # Liveness at one instant is not proof of a leak: a VimLeavePre reap takes a
    # moment, and a fake under PARLEY_FAKE_EXIT_DELAY_MS keeps serving for seconds
    # after its SIGTERM on purpose. Only a pid present in EVERY sample is a leak.
    if orphans and args.phase == "after" and not dry_run:
        deadline = time.monotonic() + args.grace
        while orphans and time.monotonic() < deadline:
            time.sleep(1)
            again, why_not = census()
            if why_not:
                break
            still = {row["pid"] for row in again}
            orphans = [row for row in orphans if row["pid"] in still]

    if not orphans:
        return 0

    if args.phase == "before":
        print("reaped %d test process(es) left by an earlier run:" % len(orphans))
    else:
        print("LEAKED: %d test process(es) survived the run, and are being reaped "
              "now." % len(orphans))
        print("A run must leave none — see TOOLING.md, \"Orphaned test processes\".")
    for row in orphans:
        print("  %7d %s" % (row["pid"], row["args"][:160]))
    if not dry_run:
        reap(orphans)
    return 0 if args.phase == "before" else 1


if __name__ == "__main__":
    sys.exit(main())
```

```bash
chmod +x scripts/reap-test-orphans.py
```

- [ ] **Step 5: Run the test**

Expected: PASS, all eight cases.

- [ ] **Step 6: Route it in the traceability map**

Under `infra/test_harness`, add `scripts/reap-test-orphans.py` and
`tests/fixtures/ps_test_orphans.txt` to `code:`, and
`tests/unit/reap_test_orphans_spec.lua` to `tests:`.

- [ ] **Step 7: Commit**

```bash
git add scripts/reap-test-orphans.py tests/fixtures/ps_test_orphans.txt \
        tests/unit/reap_test_orphans_spec.lua atlas/traceability.yaml
git commit -m "#220 M1: a ps-based census of this checkout's surviving test processes"
```

---

- [ ] **Step 8: Close the milestone**

```bash
sdlc milestone-close --issue 220 --milestone M1
```

Fix Critical/Important findings before crossing; log the verdict in `## Log`.

---

# M2 — Wire it in, write it down, guard it

### Task 5: Wire the census into the suite

**Files:**
- Modify: `Makefile.parley` — `PREP_TEST_ENV` (`:51-53`), `RUN_SPEC` (`:77`),
  `test-unit` / `test-integration` (`:80-109`), `test-spec` (`:127`),
  `test-changed` (`:182`), `perf` (`:200`), `fixtures` (`:215`)

- [ ] **Step 1: Make the parent Neovim identifiable by path**

The plenary spec *child* already carries an absolute spec path in its argv; the
`make` parent carries only relative paths, so the census cannot see it. Change every
`-u tests/minimal_init.vim` in `Makefile.parley` to
`-u "$(CURDIR)/tests/minimal_init.vim"` — **five** sites: `:77` (`RUN_SPEC`),
`:127` (`test-spec`), `:182` (`test-changed`), `:200` (`perf`), `:215` (`fixtures`).
Confirm the count with `grep -c 'u tests/minimal_init.vim' Makefile.parley` before
and after.

**Use `$(CURDIR)`, not `$$PWD`.** They disagree under a symlinked cwd: entering the
repo through a symlink, make reports `CURDIR=/Users/xianxu/workspace/parley.nvim`
while the recipe's `$PWD=/tmp/claude-501/plink`. The census calls
`os.path.realpath(--root)`, so with `$$PWD` the parent's argv would never contain
the needle and the `make` parent would stay invisible — and on macOS `/tmp` is a
symlink to `/private/tmp`, where the issue log says the dominant orphan source lives
(`/private/tmp/claude-501/rv224` and friends). `tests/arch/scratch_placement_spec.lua`'s
`canonical()` already carries this lesson. `$(CURDIR)` expands before `sh` sees the
single-quoted `RUN_SPEC` string, and the surrounding double quotes protect a path
containing spaces.

- [ ] **Step 2: Add one owner for the gate**

Near the `TEST_ENV` block:

```make
# The orphan gate (#220). `before` reaps what an earlier, interrupted run left;
# `after` reports this run's survivors and fails. One owner, so a new test target
# gets the gate by adding a line rather than by restating the command.
ORPHANS = python3 scripts/reap-test-orphans.py --root "$(CURDIR)"
```

The default `--grace` (8 s) is deliberate and belongs to the script, not here: a
target that overrode it would be the one place the gate could start failing clean
runs again.

Extend `PREP_TEST_ENV` — it is the chokepoint every test target already calls, so
the sweep is inherited rather than repeated. Keep it one line: it is used as
`@$(PREP_TEST_ENV)`, and only the first line of a multi-line define is silenced.

```make
define PREP_TEST_ENV
mkdir -p "$(TEST_HOME)" "$(TEST_XDG)/data" "$(TEST_XDG)/state" "$(TEST_XDG)/cache" "$(TEST_TMP)" && $(ORPHANS) --phase before
endef
```

- [ ] **Step 3: Fail every test target on survivors**

In `test-unit` and `test-integration`, fold the census into the existing `rc` so a
leak fails a suite that otherwise passed and does not mask a real test failure:

```make
	rm -f "$$FAILED_LOG"; \
	$(ORPHANS) --phase after || rc=1; \
	exit $$rc
```

`test-spec` and `test-changed` need the same *structure*, not the same line: both
today exit early on the first failing spec (`|| exit $$?` at `:129` and `:184`) and
at several `exit 0` / `exit 1` branches, so an appended line would be skipped on
exactly the failing runs the issue log names as the dominant leak case. Convert each
loop to record a failure and fall through:

```make
	rc=0; \
	for test_file in $$tests; do \
		echo "Running $$test_file"; \
		$(TEST_ENV) nvim -n --headless --noplugin -u "$(CURDIR)/tests/minimal_init.vim" \
		  -c "PlenaryBustedFile $$test_file" \
		  -c "qa!" || rc=$$?; \
	done; \
	$(ORPHANS) --phase after || rc=1; \
	exit $$rc
```

Apply the same shape to every early-exit branch in `test-changed`.

`perf` (`:198-204`) and `fixtures` (`:213-217`) also call `PREP_TEST_ENV`, so they
already inherit the `before` sweep; give them the `after` phase too. Both start a
headless Neovim under the harness init and can leak exactly the same way, and an
asymmetric gate is one somebody will later "fix" by removing it from the targets
that have it.

- [ ] **Step 4: Prove the gate is not vacuous**

Two things this step gets wrong if written casually, and both make it silently
useless:

- **The leak must not reap itself.** After Task 2 the fake exits within a poll of
  being orphaned, so leaking it with `orphan_me.sh` means it is long gone before
  `--phase after` runs, and the step reads as a broken gate. Leak it from a parent
  that stays alive — the proof shell itself — so no watchdog fires.
- **The leak must carry an absolute path.** `tests/fixtures/fake_cliproxy` puts a
  *relative* path in argv, which `select_orphans` cannot match.

`make test-spec SPEC=` takes an **atlas doc key**, not a path
(`scripts/spec_test_map.sh` normalizes it to `atlas/<key>.md`), so use the key the
new specs are now routed under:

```sh
ROOT=$(pwd -P)
# Leak one on purpose, from THIS shell (which stays alive, so the watchdog never
# fires), after the target's `--phase before` has already run.
make test-spec SPEC=infra/test_harness & TARGET=$!
sleep 5
"$ROOT/tests/fixtures/fake_cliproxy" --port 45999 & LEAK=$!
wait $TARGET; echo "rc=$?"
kill -9 $LEAK 2>/dev/null
```

Expected: the target prints `LEAKED: 1 test process(es) …` naming pid `$LEAK` and
its command line, and `rc=1`.

Then re-run the target with nothing leaked and confirm `rc=0` and no `LEAKED:`
line — a gate that fires unconditionally is as useless as one that never fires.

- [ ] **Step 5: Run the whole suite and confirm it is clean**

`$(pwd -P)`, not `$PWD`: the physical path is what make's `CURDIR` holds and what
the census realpaths, and under a symlinked cwd (`/tmp → /private/tmp` on macOS, the
issue log's dominant orphan source) `$PWD` would match nothing.

```sh
ROOT=$(pwd -P)
make test; echo "rc=$?"
ps -Ao pid=,ppid=,args= | grep "$ROOT/tests/" | grep -v grep
```

Expected: `rc=0`, no `LEAKED:` line, and the `ps` check prints nothing.
**Needs a machine where `ps` is permitted.**

- [ ] **Step 6: Prove the interrupted case**

The Done-when criterion that no teardown can satisfy. Run the suite in its **own
process group** so SIGINT reaches the whole tree the way Ctrl-C does in a terminal —
in a non-interactive shell job control is off, so `make` would otherwise share this
shell's group and `kill -INT -$!` would fail silently. And wait for the fan-out to
actually be running: `test-clean-env` and `lint` come first, so a fixed `sleep` can
signal before any Neovim exists, which would make the check vacuous.

```sh
ROOT=$(pwd -P)
python3 -c 'import os,sys; os.setpgrp(); os.execvp(sys.argv[1], sys.argv[1:])' \
  make test-integration & GROUP=$!
until ps -Ao args= | grep -q -- "--headless.*$ROOT/tests/"; do sleep 1; done
kill -INT -$GROUP
sleep 10
ps -Ao pid=,ppid=,args= | grep "$ROOT/tests/" | grep -v grep
```

Expected: the `until` loop exits (proving Neovims were running when the signal
landed), and the final `ps` prints nothing — one watchdog poll for the Neovims, a
second for the fixtures they were holding, plus slack.
**Needs a machine where `ps` is permitted.**

- [ ] **Step 7: Commit**

```bash
git add Makefile.parley
git commit -m "#220 M2: the suite fails when it leaves a process behind"
```

---

### Task 6: Say where the remedy is

**Files:**
- Modify: `TOOLING.md` (after "Test Scratch Directories")
- Modify: `atlas/infra/test_harness.md`
- Modify: `workshop/lessons.md`

- [ ] **Step 1: TOOLING.md — the operator-facing remedy**

A new "Orphaned test processes" section: what the suite now does at both ends of a
run, the manual command, and the caveat.

```sh
# List what this checkout has left behind (never `pgrep -f`: on macOS it does not
# match these — measured twice, `pgrep -fc fake_cliproxy` = 0 while ps found 91).
ROOT=$(pwd -P)   # the physical path: the census realpaths its --root, and under a
                 # symlinked cwd (macOS /tmp -> /private/tmp) $PWD matches nothing
ps -Ao pid=,ppid=,args= | grep "$ROOT/tests/" | grep -v grep

# Reap them, and report what was reaped
python3 scripts/reap-test-orphans.py --root "$ROOT" --phase after
```

State the cost as the issue log measured it: ~11 GB resident and the memory
compressor working, not CPU — every orphan is idle, which is why this is invisible
until the machine swaps. Add the second reason for the existing "one `make test` per
checkout" rule: the census cannot tell a concurrent run's live processes from a
leak, and it sends SIGKILL.

- [ ] **Step 2: atlas/infra/test_harness.md — a "Process lifecycle" section**

The layers and which case each covers, as a table: normal exit and spec failure
(`fixture_process`'s `VimLeavePre`), killed or wedged harness (both watchdogs), a
process that can have no watchdog (the real cliproxyapi — the registry only), and
anything that still got through (the census). Name `LoopbackHTTPServer` and
`tests/minimal_init.vim` as the two chokepoints, so a reader adding a fixture knows
where the coverage comes from rather than having to arrange it.

- [ ] **Step 3: workshop/lessons.md — three rules**

```markdown
- #220 (a watchdog that only watches for a CHANGE misses the case it exists for):
  the fixture watchdog exited when `getppid()` differed from the value sampled at
  startup. A process orphaned while it is still BOOTING — which is what a killed
  harness produces — samples 1 as its own starting parent, so the rule never fired
  for the dominant case, and 897 fixtures accumulated under a watchdog that looked
  correct and was even switched on. When a guard compares against a value sampled at
  startup, ask what that sample reads when the condition is ALREADY true, and test
  that ordering: the prototype that found this orphaned the process during startup
  on purpose.
- #220 (an opt-in invariant is as complete as the list of sites that opted in):
  parent-death exit was a per-fixture env flag; two of eight spawn sites set it and
  `fake_sse_server` never called it at all. Moving it into `LoopbackHTTPServer` —
  the constructor every long-lived fixture already passes through — made it true by
  construction. When an invariant belongs to a CLASS of thing, put it in the
  constructor of that class, not in a checklist each member follows.
- #220 (a path-matching sweep that SIGKILLs needs a second clause): selecting every
  process whose argv names a path under `<root>/tests/` is what makes the census
  free of a stale enumeration — and it also matches the operator's editor sitting on
  a spec file. A rule broad enough to be complete is too broad to kill on. Pair it
  with a clause that says what KIND of process this is (`--headless`, or a path
  under `tests/fixtures/`), and exclude the caller's own ancestry — a make recipe's
  `sh` carries the whole nvim command line in its own argv.
```

- [ ] **Step 4: Commit**

```bash
git add TOOLING.md atlas/infra/test_harness.md workshop/lessons.md
git commit -m "#220 M2: document the reaping layers and the ps-based remedy"
```

---

### Task 7: A guard, so the next fixture inherits this

Four invariants hold the layers in place, and the fourth holds the documentation
to the same standard. Each follows
`tests/arch/single_source_sweeps_spec.lua`'s convention: the selection is asserted
non-empty (a matcher that selects nothing passes while checking nothing), the
assertion is `assert.same({}, offenders)`, and a counterfactual proves the matcher
would catch a reintroduction.

**Files:**
- Create: `tests/arch/fixture_lifecycle_spec.lua`
- Modify: `tests/arch/spawn_seam_spec.lua` (header cross-reference only)
- Modify: `atlas/traceability.yaml`

- [ ] **Step 1: Write invariant 1 — every spec spawn goes through the seam**

Open the file with the header that says what it is for, so a reader meets the
reasons before the matchers:

```lua
-- #220: every process the test harness starts names its end (ARCH-FUNERAL).
--
-- lua/ is covered by tests/arch/spawn_seam_spec.lua; this file is the tests/ half.
-- Four invariants, because three different things leaked and the remedy that would
-- have found them was documented with a command that does not work:
--   1. a spec spawns through tests.helpers.fixture_process, which registers and
--      reaps — eight specs had kept private copies and every one bypassed the seam;
--   2. a fixture reaches exit_with_parent, by constructing LoopbackHTTPServer or
--      by calling it — opting in per fixture is what left fake_sse_server, and
--      fake_cliproxy's login path, uncovered;
--   3. both watchdogs, Python and Lua, test for `ppid == 1` and not only for a
--      CHANGE of parent. They cannot share code across the language boundary, so
--      this is what keeps the two copies from drifting apart;
--   4. TOOLING.md's remedy uses ps. `pgrep -f` does not match these on macOS, so a
--      documented pgrep cleanup silently no-ops and reads as success — which is
--      how 89 orphans survived a sweep that appeared to work.
local arch = require("tests.arch.arch_helper")
```


The matcher must be **file-scoped, not argument-scoped**. Every bypassing spec today
writes `uv.spawn(FAKE, { args = … })` against a file-local
`FAKE = vim.fn.getcwd() .. "/tests/fixtures/fake_cliproxy"`, so a rule like "flags a
`uv.spawn(` whose argument names a path under `tests/fixtures/`" inspects call text
containing only `FAKE` and would match nothing — the vacuous-guard failure this
convention exists to prevent.

The rule: across `tests/**/*.lua`, with comment lines blanked, no `uv%.spawn%(`
outside `tests/helpers/fixture_process.lua`.

```lua
local SEAM = "tests/helpers/fixture_process.lua"

it("no spec or helper spawns outside the fixture seam", function()
    local offenders, seam_spawns = {}, 0
    local files = arch.worktree_files({ "tests/**/*.lua" })
    assert.is_true(#files > 0, "selected no files, so the guard would pass vacuously")
    for _, file in ipairs(files) do
        for i, raw in ipairs(vim.fn.readfile(file)) do
            if not raw:match("^%s*%-%-") and raw:find("uv%.spawn%(") then
                if file == SEAM then
                    seam_spawns = seam_spawns + 1
                else
                    offenders[#offenders + 1] = file .. ":" .. i
                end
            end
        end
    end
    -- A floor on the seam, so a matcher that stopped matching cannot pass.
    assert.equals(1, seam_spawns, SEAM .. " must hold exactly one uv.spawn")
    table.sort(offenders)
    assert.same({}, offenders,
        "spawn through tests.helpers.fixture_process, which registers and reaps it")
end)
```

No exemptions are needed. `tests/integration/query_cache_spec.lua` saves, stubs and
restores `uv.spawn` (lines 103, 107, 218) without ever calling it — the pattern is
anchored on the open paren, so `uv.spawn = function() … end` and
`original_spawn = uv.spawn` do not match. `tests/integration/document_fold_native_spec.lua:8`
uses `vim.fn.jobstart`, which Neovim terminates on exit and whose `--embed` child
exits when its stdin closes; it is not `uv.spawn` and is not matched. Verify both
claims by running the guard before writing invariant 2.

- [ ] **Step 2: Write invariant 2 — every fixture reaches `exit_with_parent`, or says why not**

The obvious form — "a fixture that mentions `HTTPServer` constructs
`LoopbackHTTPServer`" — is too narrow: it misses `fake_cliproxy`'s `run_login`
(sleeps 300 s, never binds) and `fake_sips` (`slow` sleeps 30 s). Threshold rules on
sleep durations are fiddly to grep and easy to slip past. Use the house form
instead, the `OUTSIDE`-table shape from `tests/arch/spawn_seam_spec.lua`:

> Every **executable** file under `tests/fixtures/` either reaches
> `exit_with_parent` — directly, or by constructing `LoopbackHTTPServer` — or is
> declared in an exemption table with a reason it cannot block.

Keyed by **repo-relative path**, as `spawn_seam_spec.lua`'s `OUTSIDE` table is —
not by basename, which cannot hold a name with a dot in it (`orphan_me.sh`).

```lua
-- A fixture that cannot block, and why. A declared entry that no longer exists
-- fails too, so this table cannot rot into prose.
local CANNOT_BLOCK = {
    ["tests/fixtures/fake_clipboard"] = "one conversion, bounded by PARLEY_FAKE_CLIPBOARD_DELAY_MS (300ms default)",
    ["tests/fixtures/fake_git_file_list"] = "prints a file list and exits",
    ["tests/fixtures/fake_packaging_curl"] = "one canned response",
    ["tests/fixtures/fake_packaging_upgrade_brew"] = "one canned upgrade transcript",
    ["tests/fixtures/fake_ps"] = "prints PARLEY_FAKE_PS_ROWS and exits",
    ["tests/fixtures/fake_sdlc"] = "one canned sdlc response",
    ["tests/fixtures/fake_tart"] = "one canned VM response",
    ["tests/fixtures/fake_vocabulary"] = "one canned export",
    ["tests/fixtures/orphan_me.sh"] = "exits immediately by design — it is what CREATES the orphan",
}
```

Corpus arithmetic, so the guard cannot go quietly vacuous: 13 executables under
`tests/fixtures/` after this issue = 9 declared above + 4 that reach
`exit_with_parent` (`fake_cliproxy`, `fake_github_releases`, `fake_sse_server`,
`fake_sips`). Assert that total in the guard.

Select by the **executable bit**, and say in the text that
`tests/fixtures/run_without_dns.py` and `run_packaging_vm.py` are mode 644 and so
out of the corpus — a note that stops the filter being loosened later without a
thought for what it would then pull in. Assert the selection is non-empty and holds
at least the three known servers.

- [ ] **Step 3: Write invariant 3 — both watchdogs test against `1`**

Read `tests/fixtures/fixture_watchdog.py` and `tests/helpers/exit_with_parent.lua`;
flag either if it lacks a comparison of a ppid against `1`, and flag either if it
does not name the other's path (the cross-reference is what makes the pair
discoverable, since the rule cannot be single-sourced across the language boundary).

- [ ] **Step 4: Write invariant 4 — the documented remedy uses `ps`**

Done-when's fourth criterion is about wording, and wording is the thing that rots
without a test. `TOOLING.md` must contain a `ps -Ao` listing command and name the
`pgrep` caveat, and must not offer a `pgrep -f` **remedy** — the failure mode the
issue records twice is a cleanup that silently no-ops and reads as success.

```lua
it("TOOLING.md's remedy uses ps, and warns about pgrep", function()
    local doc = table.concat(vim.fn.readfile("TOOLING.md"), "\n")
    assert.is_truthy(doc:find("ps %-Ao"), "no ps-based listing command")
    assert.is_truthy(doc:find("pgrep"), "no pgrep caveat")
    -- A pgrep command offered as the remedy, rather than named as the trap.
    assert.is_nil(doc:match("\n%s*pgrep %-f"), "TOOLING.md offers a pgrep remedy")
end)
```

- [ ] **Step 5: Run each counterfactual for real**

For each invariant: make the offending edit in the working tree, confirm the guard
fails naming the exact site, then revert.

1. Add `uv.spawn(FAKE, {}, function() end)` to a converted spec → invariant 1 fails
   naming that `file:line`.
2. Drop `exit_with_parent()` from `fake_sips` → invariant 2 fails naming it; and
   delete a `CANNOT_BLOCK` entry's fixture → it fails as a dead declaration.
3. Change `fixture_watchdog.py` back to `return ppid != parent` → invariant 3 fails.
4. Replace TOOLING.md's `ps -Ao` line with a `pgrep -f` one → invariant 4 fails.

A guard whose counterfactual was never run is a guard that may match nothing.

- [ ] **Step 6: Cross-reference from the production-side guard**

Add two lines to `tests/arch/spawn_seam_spec.lua`'s header comment pointing at
`tests/arch/fixture_lifecycle_spec.lua` as the `tests/` half of the same principle,
so a reader of either finds the other.

- [ ] **Step 7: Route it, run it, commit**

Add `tests/arch/fixture_lifecycle_spec.lua` to `atlas/traceability.yaml` under
`infra/test_harness`.

```bash
nvim -n --headless --noplugin -u tests/minimal_init.vim \
  -c "PlenaryBustedFile tests/arch/fixture_lifecycle_spec.lua" -c "qa!"
git add tests/arch/fixture_lifecycle_spec.lua tests/arch/spawn_seam_spec.lua \
        atlas/traceability.yaml
git commit -m "#220 M2: guard the reaping invariants"
```

- [ ] **Step 8: Close**

```bash
sdlc close --issue 220 --verified '<the Done-when evidence, including the interrupted run>'
```

---

## Done when (from the issue), and what proves each

| Criterion | Proof | Needs a real `ps`? |
|---|---|---|
| A full run leaves zero `fake_cliproxy` and zero harness `nvim --headless`, verified with `ps` | M2 Task 5 Step 5 | yes |
| An INTERRUPTED run also leaves none | M2 Task 5 Step 6; `tests/integration/fixture_reaping_spec.lua` covers each process kind in isolation, sandboxed | yes (the suite-level proof) |
| The suite reports surviving children at exit, and a non-zero count fails | M2 Task 5 Steps 3–4; `tests/unit/reap_test_orphans_spec.lua` | Step 4 only |
| The cleanup command in `TOOLING.md` uses `ps`, with the `pgrep` caveat | M2 Task 6 Step 1, asserted by `tests/arch/fixture_lifecycle_spec.lua` invariant 4 (M2 Task 7 Step 4) | no |

## The Spec's open question, answered

The Spec asks whether the Neovim leak and the fixture leak have one cause or two.
**Two, in a chain.** The fixture leak has its own sufficient cause (the watchdog was
opt-in, and six of eight spawn sites did not opt in — and where it *was* switched on
it could not fire during the startup race) and the Neovim leak has its own
(`nvim --headless` does not exit on SIGINT, so a Ctrl-C'd `make` leaves both the
parent and the children running). They appear together, and in a varying ratio,
because a surviving spec-child Neovim is a *live parent* for its fixtures: the
fixture watchdog cannot fire while the Neovim that spawned it is alive. That is why
the ratio moved from 3.3:1 to 6.2:1 without either cause changing — it is the number
of fixtures each wedged child happened to be holding. Fixing only the fixture layer
would have left the Neovims, and fixing only the Neovim layer would have left the
fixtures that production code spawns detached.

## ARCH-* notes

- **ARCH-DRY** — three chokepoints instead of three checklists: `LoopbackHTTPServer`
  for fixture servers, `tests/minimal_init.vim` for harness Neovims,
  `fixture_process` for spec spawns. Eight private registries collapse into the
  third. The one duplication that cannot be removed — the orphan rule in two
  languages — is guarded by Task 7's third invariant. `tests/fixtures/fake_ps` is
  deliberately *not* reused: different columns, different consumer, different
  caller (see `parse_ps`'s DRY rationale).
- **ARCH-PURE** — the census's selection (`parse_ps`, `select_orphans`, `ancestry`)
  is pure over a process table; `ps` and `kill` are the thin shell, and `--ps-from`
  is the seam that lets the pure half be tested with no process at risk.
- **ARCH-FUNERAL** — the entry this issue *is*. Every process the harness creates now
  names what removes it, and the census bounds what is left when all of that fails.
  Nothing durable is created: the census writes no file and keeps no state.
- **ARCH-PURPOSE** — the deliverable is the class, not the two named processes. The
  fix covers every fixture that binds a port (present and future), every harness
  Neovim, and every process a spec starts — including the *real* cliproxyapi, which
  can have no watchdog and which the first enumeration of this work missed. Task 7
  makes each layer a guard rather than a snapshot.
- **ARCH-ORDER** — the events that matter are the ones the harness cannot block:
  SIGINT to the process group (both Neovims survive it; the watchdogs cover them),
  SIGKILL to the harness (no teardown runs at all; same), and a fixture orphaned
  *during its own startup* (the `ppid == 1` half of the rule). The layers are
  deliberately independent and unordered: `os.exit` in the Neovim watchdog skips
  `VimLeavePre`, so the fixture layer must not depend on it, and does not. The one
  ordering the census cannot resolve — a second concurrent run in the same checkout
  — is excluded by a pre-existing constraint rather than papered over.
- **ARCH-CONSTRAINTS** — one 1 s unref'd timer per harness Neovim and one 1 s poll
  thread per fixture. Detection latency is bounded at one poll per layer, so a
  chain of Neovim → fixture clears in ~2 s; Task 5 Step 6 allows 10 s. The census
  runs twice per suite and costs one `ps`.
- **ARCH-SECURE** — the census sends SIGKILL based on strings from `ps`, which is
  the one place this can go wrong. Three narrowings: an absolute path under the
  checkout root, a kind clause (`--headless` or under `tests/fixtures/`), and the
  caller's own ancestry. `--ps-from`, the only path a test takes, signals nothing at
  all, so no test can kill a real pid that happens to match a recorded one.
- **ARCH-MOCK** — `ps` is the external dependency; `--ps-from` is its seam and
  `tests/fixtures/ps_test_orphans.txt` its recorded state, taken from this machine
  rather than invented.
