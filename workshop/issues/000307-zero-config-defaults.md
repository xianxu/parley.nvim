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

Design (after audit, see Log):
- `api_keys`: merge the user table over the defaults (`vim.tbl_extend("force", ...)`)
  instead of `opts.api_keys or defaults`. The replacement is what forced the
  operator's `ollama`/`cliproxyapi` placeholders. `false` drops a default key.
- `repo_root`: drop the `opts.chat_dir` guard in `apply_repo_local`; detect with
  `repo_mode.detect_root(cwd, repo_marker)` (nearest marker, no git needed, the same
  rule the starter uses) instead of git-root + marker. `repo_root = false` opts out
  (the starter's `PARLEY_REPO_MODE=0` already uses it). An explicit `chat_dir`
  becomes the "global" root under the repo root, which is exactly what the operator
  gets today by computing `repo_root` by hand.
- Tests that pass `chat_dir` from inside this repo (which has `.parley`) and rely on
  it not entering repo mode pass `repo_root = false`.
- Keychain: no plugin shorthand (Simplicity First). The README shows a 3-line local
  helper that builds the `security` argv.
- Missing key: already lazy (`vault.run_with_secret` reports "vault secret X not
  found" on first use, nothing at startup); add a test that pins it.

- [x] Clean-profile audit (`NVIM_APPNAME=parley-clean`); log findings
- [ ] api_keys merge + tests (keyless default survives a user table; `false` drops it)
- [ ] repo_root auto-detection with chat_dir set + opt-out test; fix affected specs
- [ ] Headless zero-config boot test (setup({}), no keys: no warnings, chat created)
- [ ] README minimal-config section
- [ ] Trim the operator's local config; verify parity

## Log

### 2026-09-30

Audit (clean XDG tree, `NVIM_APPNAME=parley-clean`, `setup({})`, no `*_API_KEY` env):
- setup succeeds, no `vim.notify`, no WARNING/ERROR in parley.nvim.log;
  `:ParleyChatNew` creates `stdpath("data")/parley/chats/<ts>.md`. Default agent is
  the cliproxyapi "Choose a model" placeholder.
- Keyless defaults exist already (`ollama = "dummy_secret"`, `cliproxyapi =
  "parley-local"`), but `setup` reads `opts.api_keys or M.config.api_keys`, so any
  user `api_keys` table discards them: root cause of the operator's placeholders.
- `apply_repo_local` returns early when `opts.chat_dir` is set (added in 138f57cb as
  "skip if user explicitly set chat_dir (e.g. tests)"); 79ed1b57 let `repo_root`
  override it. That test-convenience guard is what pushed the operator into
  computing `repo_root` by hand.
- Missing key at use time: `vault.run_with_secret` warns "vault secret X not found"
  and calls on_error; nothing at startup. Behavior is already right; needs a pin test.

