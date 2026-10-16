---
id: 000204
status: done
created: 2026-08-30
updated: 2026-10-15
estimate_hours:
github_issue:
started: 2026-10-15T17:50:06-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 0.99
tracker:
    version: 1
    completion:
        token: close-717dd7e23300
        repository: github.com/xianxu/parley.nvim
        reviewed_head: a8add1b4526fd3cd95f4ec4972c034ca8cba4638
        evidence_commit: 134d5e37fc50607c7793e8599c610ca5e280e4f1
        landed_commit: 667210963be63b40d32ad1923bb3016660201b06
---

# a config change to api_keys silently does not take effect: the defaults table is replaced, and the vault pins the first secret it saw

## Problem

Reported by the operator, 2026-08-30, while getting `tools`'s `define` to reach
the parley-managed cliproxyapi. Two independent defects, both in the same shape:
**a config change does not take effect, and nothing says so.** Diagnosing them
took four rounds of restarting the wrong thing.

### D1 — a user `api_keys` table REPLACES parley's defaults

`lua/parley/config.lua:44` carries a default that exists to make the managed
proxy work with no setup at all:

```lua
-- a fixed local default works out-of-the-box over loopback
cliproxyapi = os.getenv("CLIPROXYAPI_API_KEY") or "parley-local",
```

A user who writes their own `api_keys` in `setup{}` — to pull `openai` from the
keychain, say — replaces that table wholesale. `cliproxyapi` then has no value
at all, and the failure is:

```
Parley.nvim: query abort before start [cliproxyapi]: vault secret cliproxyapi not found
```

The operator hit this by DELETING their `cliproxyapi` override, reasonably
expecting to fall back to the documented default. The default is unreachable to
anyone who configures any other key.

### D2 — the vault pins the first secret it ever saw, so a restart re-reads a stale value

`lua/parley/vault.lua:41-46` is first-write-wins:

```lua
V.add_secret = function(name, secret)
	if secrets[name] then
		logger.debug("vault secret " .. name .. " already exists", true)
		return          -- the new value is discarded
	end
```

The vault is in-memory and populated when `setup{}` runs. `render_opts()`
(`cliproxy.lua`) reads the client secret from it on every render, so
`:ParleyProxy restart` rewrites the config file — mtime moves, which looks like
success — while re-reading the SAME stale secret. Only reloading nvim clears it.

That is what made this hard to diagnose rather than merely wrong: the operator
edited the config, restarted the proxy, and stopped/started it, and the rendered
`api-keys` never changed. Every signal said "restarted"; nothing said "the value
you edited was not re-read".

Downstream the mismatch surfaces as a message that names the right field but not
the reason:

```
cliproxy: client api-key mismatch — the rendered api-keys do not match the
bearer parley sends (check api_keys.cliproxyapi)
```

That message is accurate and still sent the operator to the config file, which
was already correct — the stale half was in memory.

### Not a defect, but it compounded both

The secret is a 12-character literal, so `parley_local` and `parley-local` are
indistinguishable at a glance and by length. With D2 masking edits, a one
character typo cost a full round of restarting.
