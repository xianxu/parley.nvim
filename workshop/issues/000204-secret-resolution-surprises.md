---
id: 000204
status: open
deps: []
github_issue:
created: 2026-08-30
updated: 2026-08-30
estimate_hours:
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

## Spec

Not designed. Two decisions to make, and they are independent — this issue can
be split if the fixes want different windows.

**D1 — merge, or make the default reachable.** Options: deep-merge user
`api_keys` over the defaults (surprising in the other direction if someone wants
to REMOVE a default); merge only for keys parley itself manages, of which
`cliproxyapi` is the only one today; or leave the semantics and fail loudly at
setup time when the managed proxy is enabled and `api_keys.cliproxyapi` is
absent — naming the default in the message so it can be copied.

**D2 — the vault's contract.** `add_secret` being first-write-wins is
presumably deliberate (an early caller should not be clobbered by a later one),
so the fix is probably not to reverse it. Candidates: a `set_secret` that
overwrites, used by `setup{}`; clearing the vault at the start of `setup{}`; or
having the managed-proxy path re-resolve from config rather than the vault.
Whichever it is, `:ParleyProxy restart` should either pick up an edited secret
or SAY that it cannot.

## Done when

- [ ] A user who sets any `api_keys` entry still gets a working
      `cliproxyapi` default, or is told at setup time exactly what to add.
- [ ] Editing `api_keys.cliproxyapi` and running `:ParleyProxy restart` either
      takes effect, or reports that a full reload is required — the current
      behaviour of silently re-rendering the old value is gone.
- [ ] The mismatch message distinguishes "your config is wrong" from "your
      config is right and the running proxy is stale", since the operator
      cannot tell those apart today.

## Plan

- [ ] Decide D1 and D2 (they are independent).
- [ ] A regression test per defect: a `setup{}` with a partial `api_keys` still
      resolves `cliproxyapi`; and a second `add_secret` after a config change is
      observable to the renderer.

## Log

### 2026-08-30

Filed from a live diagnosis in the `tools` repo. Sequence, because the ORDER is
what made it expensive: removed the override → "vault secret not found" (D1);
hardcoded a value → `:ParleyProxy restart` rendered the old one anyway (D2);
restarted nvim → rendered the new one, but with an underscore where the default
has a hyphen → "client api-key mismatch". Each step's error was accurate and
none of them pointed at the mechanism.

Verified along the way, and worth keeping: cliproxyapi's `api-keys` is an
INBOUND allowlist — the proxy authenticates its callers and returns 401 without
a match. The subscription credentials are separate, in the auth-dir. So the
client secret is a local handshake token, which is why a fixed default is
reasonable in the first place.
