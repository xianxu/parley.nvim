---
id: 000307
status: open
deps: []
github_issue:
created: 2026-09-30
updated: 2026-09-30
estimate_hours:
card_mirror: 'fb9b5aca269763e7a9cc5fbf0a55c6d0097fd6e2' # card fields mirrored from issue-cards; edit via sdlc
---

# Clean up local parley config; zero-config plugin defaults

## Problem

The operator's own config (`~/.config/nvim/lua/plugins/parley.lua`, ~100 lines) has drifted
from what parley needs as a plugin, and hides whether a stranger gets a working install
from `require("parley").setup({})`:

- `repo_root` is computed in user config through internal modules
  (`require("parley.repo_mode").detect_root(..., require("parley.config").repo_marker)`).
  That is plugin work leaking into user config; setup should detect it itself.
- About 50 lines of commented-out `google_drive` / `oauth` blocks with obfuscated client
  secrets: dead weight, and they show that remote-reference setup can't be discovered
  from defaults.
- API keys come from verbose macOS `security find-generic-password` argv tables repeated
  per provider. The defaults already read env vars (`OPENAI_API_KEY`, ...), but the
  keychain pattern has no shorthand.
- `ollama = "dummy_secret"` / `cliproxyapi = "parley-local"`: providers that need no key
  still need a placeholder in user config (cliproxyapi already has a default; ollama
  probably doesn't).
- The spec never states what "out of the box" means: which features work with an empty
  setup, and what the smallest set of user-required values is (just personal paths + keys).

## Spec

Goal: `require("parley").setup({})` (plus an API key from the environment) gives a working
chat/notes/issues experience with no errors on startup. The operator's config shrinks to
personal choices only: storage dirs, export dirs, and key sources.

Scope:
1. **Audit what needs config**: install the plugin into a clean `NVIM_APPNAME` profile
   (lazy.nvim, `setup({})`, no keys), then list startup errors, warnings, and features
   that fail or need config. Record the findings in `## Log`.
2. **Move plugin logic out of user config**: `repo_root` is auto-detected by default
   (check `init.lua:756-767`: why does setting `chat_dir` suppress detection? That rule
   may be what pushed the operator into computing it by hand).
3. **Key ergonomics**: keyless providers (ollama, local proxies) need no placeholder.
   Consider a compact keychain form (e.g. `{ keychain = { service = "OPENAI_API_KEY",
   account = "..." } }`) or document the argv form once. Decide during design; no new
   secret backends beyond that.
4. **Missing-key behavior**: a provider with no key is skipped or reports one clear error
   when first used, not at startup.
5. **Docs**: a README "Minimal config" section showing the empty setup and the typical
   personal overrides.
6. **Clean up local config** (outside the repo, `~/.config/nvim`): drop the `repo_root`
   line, the dead oauth/gdrive blocks, and the redundant placeholders; keep only personal
   values. Check that behavior matches before and after.

Out of scope: new provider integrations; changing default storage locations
(`stdpath("data")/parley`).

## Done when

- A headless test boots a clean profile with `setup({})` and no API keys: no errors or
  warnings, and a chat buffer can be created/opened.
- `repo_root` detection needs no user config, including when `chat_dir` is set (test
  covers it).
- Keyless providers need no placeholder key (test covers it).
- README has a minimal-config section that matches the tested setup.
- Operator's `~/.config/nvim/lua/plugins/parley.lua` holds only personal paths + key
  sources (no internal `require("parley.*")` calls, no commented dead blocks), and
  parley behaves the same in the operator's daily use.

## Plan

- [ ] Clean-profile audit (`NVIM_APPNAME=parley-clean`); log findings
- [ ] Fix repo_root auto-detection + test
- [ ] Keyless providers / missing-key behavior + tests
- [ ] (optional) keychain shorthand, if the audit supports it
- [ ] Headless zero-config boot test
- [ ] README minimal-config section
- [ ] Trim the operator's local config; verify parity

## Log

### 2026-09-30
