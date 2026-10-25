---
type: side-doc
parent: ../../issues/000440-a-predicate-wait-doing-child-rpc-never-times-out.md
process-instruction: "[free-form] a draft for the operator to file upstream, or not"
---

# Draft: upstream neovim issue (not filed; for the operator's decision)

## Title

vim.wait() never times out when each predicate call closes a libuv handle

## Problem

`vim.wait(timeout, pred)` does not return at `timeout` when every call of `pred` leaves a pending close callback, for example by closing a `vim.uv` timer. The loop pass then returns without blocking, and the pass takes under 1 ms. The remaining time seems to be reduced by whole elapsed milliseconds per pass, with the baseline reset each time, so a sub-millisecond pass subtracts 0. The wait then spins forever: we measured about 3 million predicate calls over 115 s with a 15 s timeout.

A common real-world shape is a predicate that makes an RPC through a helper that arms a timeout timer per request (`new_timer`, `start`, `stop`, `close`).

## Repro (`nvim --clean --headless -l repro.lua`)

```lua
local uv = vim.uv
local function run(label, pred)
  local t0 = uv.hrtime()
  local ok = vim.wait(500, pred)
  print(("%s returned=%s elapsed_ms=%d"):format(label, tostring(ok), (uv.hrtime() - t0) / 1e6))
end
local function busy(ns) local s = uv.hrtime() + ns; while uv.hrtime() < s do end end

run("plain", function() return false end)
run("close+1.5ms", function() uv.new_timer():close(); busy(1.5e6); return false end)
-- never returns:
run("close", function() local t = uv.new_timer(); t:start(60000, 0, function() end); t:stop(); t:close(); return false end)
print("unreachable on 0.11.7 and 0.12.5")
```

## Expected

All three waits return `false` after about 500 ms, and the final line prints.

## Actual (macOS arm64; identical on 0.11.7 and 0.12.5)

```
plain returned=false elapsed_ms=503
close+1.5ms returned=false elapsed_ms=761
<hangs; killed after 8 s>
```

`close+1.5ms` shows the accounting: 500 passes of about 1.5 ms each were counted as 1 ms each, so the 500 ms wait took 761 ms. With a pass under 1 ms, each counts 0. A `vim.schedule(function() end)` per predicate call hangs the same way. Keeping one timer and only starting and stopping it does not hang.

## Suggested fix

In the wait loop (`LOOP_PROCESS_EVENTS_UNTIL`, used by `nlua_wait`), measure the remaining time against a fixed deadline taken once at the start, `deadline = os_hrtime() + timeout * 1e6`, and compute `remaining = (deadline - os_hrtime()) / 1e6` on each pass. Do not subtract truncated per-pass deltas from a moving baseline. Alternatively, keep the sub-millisecond remainder rather than resetting `before = now`.

We have not yet checked the current master source to confirm the exact lines; the behaviour above is measured.
