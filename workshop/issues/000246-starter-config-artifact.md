---
id: 000246
status: working
deps: [000245]
github_issue:
created: 2026-09-13
updated: 2026-09-13
estimate_hours: 3.823
started: 2026-09-13T14:26:23-07:00
---

# Starter config as a product artifact: NVIM_APPNAME=parley, lazy.nvim bootstrap, derived from the operator config without personal data

## Problem

The `parley-packaging` project needs a Neovim configuration a non-Neovim user
can start from: lazy.nvim bootstrap, the parley plugin spec, sensible
defaults for a chat-first editor. Today the only such config is the
operator's personal one (`~/.config/nvim`), which #211 is separating from
the product. This issue makes the starter config a **product artifact** in
this repo, derived from the operator's config with personal data removed.

## Spec

- Lives in the repo (`packaging/starter-config/`), versioned with the plugin,
  and is what #247's formula installs. It is loaded under
  **`NVIM_APPNAME=parley`** (`~/.config/parley/`, state under
  `~/.local/share/parley/`), so it never reads, writes or merges an existing
  `~/.config/nvim` — installation and removal are each one directory.
- Contents: lazy.nvim bootstrap pinned to a tag; the parley plugin spec
  pointing at the released plugin (not a dev path); the keymaps and options
  from the operator's config that a chat-first user needs (leader, clipboard,
  markdown conceal defaults that keep pasted image labels visible — see
  #231's alt-text decision), and nothing personal: no API keys, no iCloud or
  blog paths, no ariadne repo hooks, no note or vision directories (#211
  owns the product defaults this leans on; #209 owns the safe posture).
- First run: opens a new chat with a one-screen key hint (`<M-CR>` respond,
  `<M-v>` paste image, `<M-t>` outline, `:ParleyProxy login`); cliproxyapi is
  the default provider route so no API key is typed.
- A generated-from test: a script diffs the artifact against a denylist of
  personal markers (email, home-relative paths, ariadne names) and fails on a
  hit, so the artifact cannot silently regain personal data.

## Done when

- `NVIM_APPNAME=parley nvim -u <artifact>/init.lua` on a machine with no
  `~/.config/parley` boots, installs lazy.nvim and parley, and opens a chat.
- The same machine's `~/.config/nvim` is byte-identical before and after.
- The personal-marker test passes and is wired into `make test`.
- The README's install section points here for non-Neovim users.

## Estimate

Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against
`baseline-v3.1.md`. Method A only; calibration is provisional (source stale).
Four focused Lua/Neovim primitives: live policy, profile settings/key, bootstrap,
and welcome/connect. Each uses midpoint design 2h ×0.2 for the approved detailed
plan and implementation 1h ×0.4 for v3.1. Existing libuv, Lazy and Parley owners
cover the integrations; no novel library is needed. Familiarity 1.0. One docs
primitive uses 0.1h ×0.2 design and 0.1h ×0.4 implementation; one boundary review
uses 0 design and 0.35h ×0.4 implementation; GitHub bootstrap discovery uses
0 design and 0.45h ×0.4 implementation. Design buffer is 15%.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: lua-neovim design=0.4 impl=0.4
item: lua-neovim design=0.4 impl=0.4
item: lua-neovim design=0.4 impl=0.4
item: lua-neovim design=0.4 impl=0.4
item: atlas-docs design=0.02 impl=0.04
item: milestone-review design=0 impl=0.14
item: real-api-discovery design=0 impl=0.18
design-buffer: 0.15
total: 3.823
```

## Plan

- [x] Derive the artifact from the operator config; strip per the denylist
- [x] Personal-marker test; pin lazy.nvim
- [x] First-run hint and default provider route
- [x] README section (with #206)

## Log

### 2026-09-13

Implemented the isolated starter and live-model policy. Tests cover real competing
initializers/key creators, abrupt owner death, effective provider/path/tool policy,
secret absence from logs, and managed download→login with stateful release/proxy
fixtures. Full `make test`: 241 specs pass; lint 419 Lua files with zero warnings
or errors. Bootstrap entry lint also passes. Real GitHub dependency bootstrap in
a fresh HOME/XDG profile passed with the local reviewed runtime; final released
plugin bootstrap remains pending until the close review and release publication.

Full-suite checks required reuse of fs.ensure_dir (optional creation permissions)
and literal welcome directory scanning. Effective setup exposed an existing
unmarked sensitive dispatcher diagnostic; its flag now protects the client key.
In-session review findings and regression lessons are recorded. No user chat
files were staged. ARCH-DRY/ORDER/SECURE shaped these corrections.

## Revisions

### 2026-09-13T14:43:00-07:00 — packaging execution scope

The operator confirmed the packaging spine #245 → #246 → #247. This
supersedes the original #209/#211 prerequisites: the starter explicitly supplies
profile-local paths, credentials and a no-local-tools policy without waiting for
those broader default changes. The existing native live model picker and restore
path will honor that policy through one shared option seam (ARCH-DRY).

The implementation plan is [starter-config](../plans/000246-starter-config-plan.md).
It specifies one editable init.lua, pinned lazy bootstrap, managed first-use proxy
connection via :ParleyConnect, and isolated config/data/state/cache/auth storage.
This supersedes the original one-directory lifecycle shorthand and raw-login
first-use hint. Fresh-context plan review completed; implementation approval is
pending. No implementation or estimate has been recorded yet.

### 2026-09-13 — boundary review round 1 corrections

BR-1: removed the unconditional default_agent override; the only configured learner
is naturally the first-use fallback. A real two-process startup test reproduced
saved model replacement before the fix and now verifies selection persistence.
BR-2: artifact guard now rejects all home-relative paths and ariadne imports,
except the exact installation comment in the shipped entry. New negative fixtures
reproduced the omissions. Re-running the full suite before the next close review.
