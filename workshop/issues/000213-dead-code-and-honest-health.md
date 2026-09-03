---
id: 000213
status: open
deps: []
github_issue:
created: 2026-09-02
updated: 2026-09-02
estimate_hours:
---

# delete dead code and make checkhealth honest

## Problem

Dead modules ship, and `:checkhealth parley` reports green on an install that
cannot work.

Dead or unreachable:

| Thing | Why |
|---|---|
| `lua/parley/discovery/` | **71 tests, zero production callers.** Its intended consumer is a virtual skill whose seam is never fed — `skill_picker.lua:78` passes no `virtual_generators`. Comments say "arrives in M5"; M5 never landed |
| `lua/parley/spinner.lua` | Self-described "intentionally empty... placeholder" |
| `lua/parley/test_agent_picker.lua` | Scratch `:luafile` harness, untouched since 2025-05-26 |
| `lua/parley/google_drive.lua` | Two-line back-compat alias |
| `lua/parley/review.lua` | Back-compat shim whose v1 exports were already deleted |
| azure + copilot adapters | Structurally unreachable — absent from `config.providers`, so `init.lua:754` drops any agent naming them; azure has no `api_keys.azure` to resolve. Copilot additionally spoofs `editor-plugin-version: copilot-chat/0.17.2024062801` against an undocumented internal GitHub API (`vault.lua:197`) |
| `command_prompt_prefix_template`, `command_auto_select_response` | Dead GpRewrite-era config under `config.lua:557`'s own `-- TODO: what are the following are needed?` |
| `voice_apply` skill | Hardcoded `~/.personal/`, no config key — arg picker is empty for every user but the author |
| panvimdoc markers | `README.md:1,7`, inherited from gp.nvim; there is no panvimdoc and no `doc/` (deleted in `f7e014a`), so `:help parley` ships nothing |

`health.lua:7-42` is 43 lines checking `require`, `setup()`, `curl` and lualine.
It does not check `git`, `rg`, `pandoc`, `sdlc`, the API key, the cliproxy
binary, or the vocabulary JSON whose absence hard-fails plugin load.

## Spec

Remove what does not run, and make the health check able to detect the failures
that actually happen.

- Delete the dead modules and unreachable adapters listed above, and their tests.
  The discovery registry's 71 tests are the largest single block — deleting a
  guarded-but-unreachable module means deleting the guard with it; record the
  decision in case the M5 consumer is later revived.
- Decide azure/copilot explicitly: either wire them into `config.providers` with a
  documented endpoint, or remove them. Shipping an adapter that cannot be reached
  is worse than shipping neither. The copilot spoofed header is an independent
  reason to remove rather than wire.
- Either give `voice_apply` a config key with a fallback (see #211) or remove it
  from the shipped skill root.
- Rewrite `:checkhealth parley` to check what breaks: every binary the plugin
  shells out to, the vocabulary file, at least one resolvable provider
  credential, and the cliproxy binary when a cliproxy agent is configured. Each
  check must have been seen fail for the right reason (`ARCH-PURPOSE`: a health
  check that cannot go red is decoration).
- Remove the orphan panvimdoc markers, and decide separately in #206 whether
  generated vimdoc returns.

## Done when

- No module in `lua/` is unreachable from a user-facing entry point; asserted by
  a reachability check, not by inspection.
- Every health check has been observed failing for its intended reason, and a
  deliberately broken install produces a red `:checkhealth parley`.
- The test suite still passes with the deleted specs removed, and total coverage
  is reported before and after so the drop is a known quantity.

## Plan

- [ ] Delete dead modules + their specs; record the discovery-registry decision.
- [ ] Resolve azure/copilot: wire with documentation, or remove.
- [ ] Resolve `voice_apply` (config key or removal).
- [ ] Rewrite health checks; observe each one red.
- [ ] Remove orphan panvimdoc markers.

## Log

### 2026-09-02

Split out of the `workshop/plans/000206-shipping-surface-inventory.md` audit as Tier 4 plus blocker
B10. Grouped because both are the same debt: things that exist without doing
anything, including a health check that cannot report ill health.
