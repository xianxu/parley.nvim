---
id: 000204
status: working
deps: []
github_issue:
created: 2026-08-30
updated: 2026-10-15
estimate_hours:
card_mirror: '8c3196180b86103664cb6aea108e00c4595db0ff' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-15T17:50:06-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "561e12cc", done: "565fefdd"}
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

Decisions (2026-10-15):

- **D1 is already fixed** by #307 (`afa83862`): `init.setup` now layers user
  `api_keys` over the defaults with `vim.tbl_extend("force", …)`, and `false`
  drops a default. Nothing pins it with a test, so this issue adds the regression test only.
- **D2: `setup{}` is the authority, so `vault.setup` resets the secret store**
  (`secrets` + `_obfuscated_secrets`). First-write-wins stays *within* one
  setup, so dispatcher's `provider.secret` still does not clobber `api_keys`.
  Re-sourcing the config (re-running `setup{}`) then takes effect on the next
  render. The vault records `loaded_at`. Parley cannot see a config file edit until setup
  re-runs, so the `:ParleyProxy restart` notice says which setup the key came
  from: `restarted (client key from setup() at HH:MM:SS; re-run setup or
  restart nvim to pick up config edits)`.
- **Mismatch message:** on a 401 in `ensure_running` (only the failure branch, so the cost stays off the
  hot path), read `port_identity` (ps+lsof, the same read `update` uses). A pure
  `mismatch_message(identity, port, prefix)` chooses one of three messages:
  `ours` → the config is right and the proxy is stale ("booted from an earlier key; run
  `:ParleyProxy restart`"). `not ours` → the proxy on the port is not parley's, so its
  api-keys must include `api_keys.cliproxyapi` (or stop it). If parley cannot
  tell, the message names both (ARCH-PURE).

- [x] Regression test: `setup{api_keys={openai=…}}` still resolves `cliproxyapi` to the default.
- [x] Regression test: a second `setup{}` with a changed `cliproxyapi` is what `get_secret`/the render sees; vault_spec A3 is unchanged and gets a new reset case.
- [x] `vault.setup` resets the store and records `loaded_at`; the restart notice names it.
- [x] `mismatch_message` pure + unit-tested on all three identities; wired into the 401 branch.

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

### 2026-10-15

- D1 needed no code: #307 already merges `api_keys`. `tests/unit/setup_api_keys_spec.lua` now pins it (a partial table, `false`, a re-run setup).
- D2 mutation check: with the `secrets = {}` reset removed, 3 cases fail (setup_api_keys ×2, vault F1). With it restored, everything passes.
- `port_identity` is now forward-declared, because `ensure_running` precedes it. It runs only on the 401 branch (ARCH-PURE: the message choice is `rel.mismatch_message`, unit-tested on all three identities).
- start-plan's `weave refresh` could not rewrite `.claude/settings.json` (sandbox: operation not permitted). A re-run succeeded. I reported this to the hub.
