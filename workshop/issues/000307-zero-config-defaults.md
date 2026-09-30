---
id: 000307
status: working
deps: []
github_issue:
created: 2026-09-30
updated: 2026-09-30
estimate_hours:
card_mirror: '20b6544a82e33a1d74a38c7b9fad2ca05e049608' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-09-30T11:29:00-07:00
flow: {kind: quick, provenance: inferred, spec: "a3e5d739", done: "15a7c84a"}
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
- The plugin setup guide the README links to (`atlas/infra/config.md`) has a
  minimal-config section that matches the tested setup.
- A trimmed operator config (only personal paths; no api_keys, no internal
  `require("parley.*")` calls, no commented dead blocks) resolves to the same
  config as today's, checked by a probe in a repo dir and a plain dir. Installing it
  to `~/.config/nvim` follows the merge.

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
- [x] api_keys merge + tests (keyless default survives a user table; `false` drops it)
- [x] repo_root auto-detection with chat_dir set + opt-out test; fix affected specs
- [x] Headless zero-config boot test (setup({}), no keys: no warnings, chat created)
- [x] Minimal-config section (in `atlas/infra/config.md#minimal-config`; see Log)
- [x] Trim the operator's local config; verify parity (install to ~/.config follows the merge)

## Log

### 2026-09-30
- 2026-09-30: closed — make test: all green except 2 arch specs failing on main too and one parallel-load timeout (document_fold_batches 5/5 alone; branch_child 39-51s alone on main and branch vs ~50s deadline); tests/integration/zero_config_spec.lua 9 cases incl. BR-1 class (issues/history/vision/buffer-context resolve to marker-only root; fails with old issues.lua); make lint clean; parity probe old code+old operator config vs new code+trimmed config identical in repo and plain dir; minimal-config section in atlas/infra/config.md.; review verdict: FIX-THEN-SHIP

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

Implementation:
- `api_keys` merges over the defaults. Found in the full suite: the merged
  defaults re-enabled providers the starter disables with `openai = {}`, because
  secret injection made the empty table non-empty (an empty table is the
  dispatcher's disable signal). Injection now skips empty provider tables; spec pins it.
- Detection opt-out: `repo_root = false`, or `PARLEY_REPO_MODE=0` when `repo_root` is
  unset. The env check moved from the starter into setup (one knob, ARCH-DRY). The
  test harness sets `PARLEY_REPO_MODE=0` in `tests/minimal_init.vim`: the first full
  run without it wrote 79 chats into this repo's `workshop/parley` (removed).
  super_repo_spec's startup cases clear it locally; fresh_clone_probe passes
  `repo_root = false`.
- Operator follow-up: with cliproxyapi built in, the operator's openai/anthropic/googleai
  keychain keys are dead. No agent in their config calls a direct provider; default and
  catalog agents all dispatch through cliproxyapi. Trimmed config is 4 paths.
  Parity probe (resolved repo_root/chat_dir/chat_roots/notes/note_dirs/export dirs/agents/
  secret presence), old code + old config vs new code + trimmed config: identical from
  `~/workspace/parley.nvim` (repo mode) and from a plain dir.
  Install waits for merge: lazy loads parley from the main checkout, which
  needs the new detection.
- The README was slimmed to a landing page in e02820c7 and links plugin setup to
  `atlas/infra/config.md#install-as-a-neovim-plugin`, so the minimal-config section
  lives there instead of in README.
- Suite: all green except `tests/arch/buffer_mutation_spec.lua` and
  `single_source_sweeps_spec.lua` (both fail on main too; unrelated), and
  `branch_child_spec.lua` (runs 39–51s alone on both main and branch against a ~50s
  plenary deadline; times out under parallel load. Existing, not introduced here).

## Revisions

### 2026-09-30 — close review round 1 (FIX-THEN-SHIP)
- Done when "README has a minimal-config section" → the section is in
  `atlas/infra/config.md#minimal-config`. README became a landing page in e02820c7
  and links plugin setup to that file's install anchor.
- Done when "operator's config holds only personal paths" → parity verified by probe
  before close; installing the trimmed file happens after merge, because lazy loads
  parley from the main checkout. The last Plan item stays open until then.
- BR-1: setup's nearest-marker root now reaches every repo-relative reader through
  `parley.project_root()` (repo root, else cwd Git root); the "repo" buffer
  context uses `repo_mode.detect_root`. zero_config_spec pins issues/vision/
  buffer-context in a marker-only project and fails with the old issues.lua.

