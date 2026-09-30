# Parley application and release configuration

## Product boundary

Parley has two supported entry points into the same runtime:

- **Parley application:** `brew install xianxu/parley/parley`, then `parley`.
  A standalone chat application backed by Neovim, usable without maintaining a
  Neovim configuration. The launcher supplies an isolated profile and the
  packaged runtime; onboarding, shortcuts and chat discovery are product behavior.
- **parley.nvim plugin:** install the plugin in an existing Neovim configuration
  and call `require('parley').setup(opts)`. The user owns editor configuration,
  dependencies and overrides. Installing the plugin must not install the app's
  editor profile or redirect the user's configuration to `NVIM_APPNAME=parley`.

Both entry points share chat, provider, picker and LLM implementations. Packaging
must not fork those implementations. App profile isolation keeps editor configuration, chats and state separate from
a plugin configured in ordinary Neovim. Proxy account credentials are shared in
`~/.cli-proxy-api`; they are not isolated by `NVIM_APPNAME`.

Bundled startup loads shipped editor dependencies directly and opens no installer
view. Standalone source bootstrap closes Lazy's installer view and restores the
original editor window before starting Parley. Lazy's view closes asynchronously, so focus
restoration is explicit: the welcome chat must never inherit its 80% floating
window. Bootstrap coverage exercises an actual Neovim float as well as cached
startup, even when the test process itself runs headless.

## Configuration ownership today

`parley_app` is a development entry point into the same packaged starter. It
resolves the checkout from the executable path, changes into a separate demo
directory to avoid repo detection, and isolates HOME plus all XDG roots. The
default `${XDG_CACHE_HOME:-$HOME/.cache}/parley-app-demo` is reused, bounding this
helper to one profile; `PARLEY_DEMO_DIR` selects another operator-owned profile.
Unlike the installed application, its HOME isolation separates credential files.
The launcher explicitly sets `PARLEY_REPO_MODE=0` so markers in any demo ancestor
cannot enable repo mode. `--tutorials` sets `PARLEY_CHAT_DIR` to the checkout's
source tutorials; the starter expands and canonicalizes that override. State and
credentials remain in the demo. `--nuke` removes the owned demo profile and exits,
leaving source tutorials untouched. Python 3 provisions the manifest's checksummed
bundle under the demo profile's `editor-dependencies` root, verifies the complete
payload before every launch, and passes a shared reader lease into Neovim.
The initial preparation can download archives; a verified reused bundle does not.
See [bundle lifecycle and ownership](packaging.md#development-bundle-lifecycle).

`--demo` is the explicit repo-mode recording variant: the same ownership/PID
and sibling-lock guards protect a fixed Git-ignored `demo/workspace/`. Its
nearest `.parley` marker chooses a nested project root. `demo/init.lua` passes
Screenkey's manifest-derived spec into the shared starter via `loadfile` and enables it
on VimEnter. The packaged starter accepts an optional spec list; ordinary app
startup supplies none. The recording launcher selects the manifest's `recording`
membership so Screenkey is assembled and verified with the app dependencies.
Default demo startup selects a timestamped empty chat.
`--demo --reset` clears workspace workshop/config/state/cache and the profile's
chats/notes/exports/theme persistence, retaining plugins and HOME/auth;
`--demo --nuke` removes the owned workspace. Tracked demo configuration and
recordings outside the workspace survive. See `demo/README.md` for usage.
Launcher integration tests cover nested root and chat recognition, retained
versus reset data, symlink boundaries and competing operations; bootstrap
tests prove the demo additions do not enter packaged defaults.

`demo/viewer.html` is a standalone recording-review helper, outside the app
runtime. It loads the pinned asciinema player from a CDN, opens a local cast or
`?cast=...` URL, displays caption markers, inserts paused time stamps with Alt+T,
and downloads caption notes. File reads use selection generations so a slower
old selection cannot replace the newest one. Browser storage keeps at most 20
most recently saved URL-scoped drafts; local file openings share the current
page's draft. Storage errors are visible and leave notes editable/downloadable.
Legacy per-cast keys migrate to the bounded store and are removed only after a
successful write. `node tests/packaging/test_cast_viewer.js` verifies the production
script with controlled file reads and stateful storage. Usage and recording
rehearsal live in `demo/README.md` and `demo/REHEARSAL.md`.

The starter loads manifest-pinned Lualine with an automatic theme, prominent mode,
chat name and cursor position. Existing `parley.lualine` integration supplies
the model/activity section. `tests/packaging/statusline_compatibility.lua`
exercises the production options with real Lualine and every packaged theme.

It also pins blink.cmp (#287) for fuzzy `:` completion and current-buffer word suggestions
after two characters (#300), using its Lua matcher (no native download).
Insert mode uses Tab/Down and Up to select, Enter to accept (first item if none
is selected), and Esc to dismiss while staying in Insert mode. Closed-menu keys
fall back to native behavior; Ctrl-n/p, Ctrl-y and Ctrl-e remain alternatives.
There is no preselection or automatic insertion. Telescope's
`command_history` is bound to `<C-g>:`, since blink offers no history source.
`tests/packaging/completion_compatibility.lua` runs the production options
through the real pinned blink.

| Owner | Responsibility |
|---|---|
| `lua/parley/config.lua` | Current plugin defaults consumed by `setup(opts)` |
| `lua/parley/starter_config.lua` | Release policy overrides, derived from supplied profile roots |
| `lua/parley/starter.lua` | Applies release policy, initializes profile and welcome chat, starts onboarding |
| `lua/parley/editor_dependencies.lua` | Authoritative plugin commits and source/Preview artifact hashes |
| `scripts/editor-dependencies.py` | Verified development bundle assembly, publication and leases |
| `lua/parley/editor_bundle.lua` | Bundle identity/structure checks and local spec projection |
| `packaging/starter-config/init.lua` | App editor settings, bundle loading, standalone bootstrap and starter entry |
| `packaging/parley`, `packaging/launcher.lua` | Homebrew runtime selection and isolated editable configuration |
| User's Neovim configuration | Plugin overrides and personal workflow integrations |

`lua/parley/defaults.lua` also holds runtime constants and templates; it is not
another complete user configuration layer. See [configuration](config.md) for
actual setup merge semantics.

## Release behavior to preserve

The policy source is `starter_config.options(roots)`; this map explains its
intent rather than providing a second configuration to copy.

| Surface | Release contract |
|---|---|
| Storage | Profile-local config/data/state/cache; chats directly in `chats/`, including `welcome.md`; no personal iCloud or blog paths |
| First use | Missing welcome, basics, advanced and Vim Basics tutorials are seeded without overwriting edits; the welcome preamble explains connection, model selection and sending and is excluded from the LLM question |
| LLM setup | Missing setup opens the shared agent picker, including logged-out providers; login returns to that picker and model selection resumes the pending action |
| Setup cancellation | Cancel aborts the pending action; changed source requires retry; headless mode never opens a picker |
| Proxy | Managed CLIProxyAPI on loopback port 8317 with client key `parley-local`; account credentials share `~/.cli-proxy-api` with the plugin |
| Keys | All Ctrl+g prefixes and Alt chords, including Alt+Enter, plus all finder-local controls; other global/editor integration shortcut families disabled |
| Optional features | Automatic memory generation disabled; answer-style 📝 summaries, web search and all registered tools enabled |
| Customization | Existing Neovim users retain `setup(opts)` as the configuration boundary |

## Find your files and recover startup

The following defaults apply to the app outside project mode. XDG variables
replace the corresponding base directory; `/parley` is appended to each base.

| Content | Default location | XDG base override |
|---|---|---|
| Editable settings | `~/.config/parley/init.lua` | `XDG_CONFIG_HOME` |
| Chats and tutorials | `~/.local/share/parley/chats/` | `XDG_DATA_HOME` |
| Notes | `~/.local/share/parley/notes/` | `XDG_DATA_HOME` |
| Exports | `~/.local/share/parley/exports/` | `XDG_DATA_HOME` |
| Shipped editor plugins | Homebrew keg's `libexec/editor-bundle/plugins/` | Package-managed |
| Standalone/personal plugin storage | `~/.local/share/parley/lazy/` | `XDG_DATA_HOME` |
| Saved Parley state | `~/.local/state/parley/persisted/state.json` | `XDG_STATE_HOME` |
| Runtime log | `~/.local/state/parley/parley.log` | `XDG_STATE_HOME` |
| Caches/query scratch | `~/.cache/parley/` | `XDG_CACHE_HOME` |

Inside Parley, `:lua print(vim.fn.stdpath('data'))` shows the effective data
root; replace `data` with `config`, `state` or `cache` for the others.
`:lua print(require('parley').config.chat_dir)` shows the actual chat destination,
including a configured override or [project mode](repo_mode.md). Back up that
directory together with its `assets/` subdirectory to preserve attachments.
Plugin defaults instead use `stdpath('data')/parley/chats`, ordinarily
`~/.local/share/nvim/parley/chats/`; an existing plugin configuration can override it.
Provider accounts remain in shared `~/.cli-proxy-api`, outside these profile roots.

For startup problems:

1. A missing or incompatible Homebrew editor bundle requires package repair or
   upgrade; startup does not download a replacement. A corrupt development
   bundle requires the explicit [managed-root repair](../../TOOLING.md#editor-dependency-bundles).
   Standalone source-profile download failures remove owned staging and can be
   retried after restoring connectivity; that fallback requires Neovim 0.11+,
   Git and curl. `:checkhealth parley` reports feature dependencies once open.
2. An error saying an initializer is **still active** means another launch owns
   it; let that launch finish. If the error explicitly says **requires repair**,
   close all Parley instances, then remove only the initializer directory named
   in that error and retry. The possible default locations are
   `~/.config/parley/.launcher-initializer`,
   `~/.local/share/parley/initializer.lock` and
   `~/.local/state/parley/welcome-initializer`. With XDG overrides use the reported
   path, not these defaults. Do not remove the entire profile to clear a lock.
3. A standalone source profile's incomplete Lazy checkout is reported with its
   exact directory. Preserve local changes before repairing that checkout;
   bundled app repair does not delete it. An incomplete welcome chat is also
   reported by path: back up and repair that file, or move it aside and restart
   to seed a fresh copy. Existing tutorial edits are otherwise preserved.
4. If loopback port 8317 belongs to another service, stop that service or change
   the configured proxy port. Parley does not remove a foreign listener.

Upgrades preserve `init.lua`; compare any adjacent `init.lua.new` before adopting
new starter settings. Adopting the new bundle-loading setup is required for an
older edited starter to gain offline dependency loading. Existing Lazy caches
and personal plugins remain untouched. Before removing app profile data, save chats/assets you
want and run `:ParleyProxy stop`. `brew uninstall parley` alone removes the
application, retaining profile data and shared account logins.

## Shared product defaults

`config.lua` owns the portable baseline used by the app and plugin (ARCH-DRY).
Both use the same answer-style prompt, including 📝 summaries, web search,
`@all` tools, model searches and onboarding. Automatic memory generation is off;
answer summaries do not enable background memory generation. The placeholder
prompts for a real model instead of selecting a named ToolOpus agent.

The app supplies separate storage, editor bootstrap and its Ctrl+g/Alt key
families plus finder-local controls. Personal chat/notes and blog export locations belong in the author's
`~/.config/nvim/lua/plugins/parley.lua`; no personal paths ship in the defaults.
Existing files are not moved by this configuration change.

## Test the application configuration without Homebrew

From the checkout root:

```sh
./parley_app
```

This uses the working tree and the same starter entry as the release in an
isolated demo profile. Python 3 prepares missing manifest dependencies and
verifies the complete bundle before opening the editor. For an existing profile,
use the [dependency CLI's `run` entry](../../TOOLING.md#editor-dependency-bundles)
with the desired Neovim command. Direct standalone startup without a supplied
bundle retains its online bootstrap outside the packaged offline guarantee.
These paths do not exercise Homebrew formula installation or launcher upgrades.

Bundle mode disables Lazy's bytecode cache: Neovim 0.11 encodes complete source
paths in cache filenames, and long manifest-addressed bundle paths can exceed the
filesystem's filename limit. Source-profile bootstrap retains its existing cache
behavior. Mutable Lazy state and lockfiles still use user XDG storage.

`make test-spec SPEC=infra/starter` follows [traceability](../traceability.yaml).
The policy unit spec defends defaults, key families, and finder-local controls; starter integration probes
inspect effective setup, profile isolation, welcome parsing, finder visibility,
keymaps and model selection before sending. Onboarding/readiness specs cover
provider selection, cancellation and changed-source handling. Bootstrap fixtures
exercise installation failures and retry. Full packaging/VM acceptance remains
necessary for release transport and installation behavior.

## Runtime and lifecycle details

The single editable `packaging/starter-config/init.lua` is the app entry under
`NVIM_APPNAME=parley`. Packaging supplies `PARLEY_RUNTIME` and
`PARLEY_EDITOR_BUNDLE` for the installed release and its dependencies. Bundled
Lazy loads local specs without installation or build hooks. Without those
supplied paths, the standalone source profile bootstraps a released Parley
checkout and manifest-pinned dependencies. Its profile initializer directory owns
staged Git work and serializes initialization; dead or incomplete ownership
requires explicit recovery instead of stealing a competing initializer's work.

`starter_config.options(roots)` is the pure profile policy projection. It uses
loopback port 8317 and the `parley-local` client key, matching `define` defaults;
no client-key file is created or read. Provider OAuth and proxy management
credentials remain separate. The profile retains Ctrl+g and Alt key families plus finder-local controls
from the default bindings and adds Alt+Enter for sending. App-only Alt+f/n
alias chat finder/new chat; new question keeps Ctrl+g n without Alt+n to avoid
a buffer-local collision. Both chat memory
summaries and preference generation are disabled in this profile.
`starter.start()` applies the policy, seeds missing bundled tutorials and reopens the welcome chat, and
uses `:ParleyProxy connect` for account selection and login. The proxy command
is available in ordinary plugin setup as well as the starter.
`starter.connect()` delegates to the shared onboarding flow.

`starter_onboarding` and `llm_readiness.defer` share the existing agent picker
in both entry points. Missing setup opens its logged-out provider rows; login
returns to the same picker with the refreshed catalog. Model selection resumes
the pending action at the original buffer and cursor. Cancellation or changed
source cancels that action. Selected non-proxy agents retain their normal path;
headless startup never opens dialogs. The placeholder is hidden from the picker.

`cliproxy.live_models.tools` flows through the shared `live_agent_options` into
`cliproxy_catalog.build_agent` for both picking and restoring live models. An
explicit empty table keeps local tools disabled; omission retains `@all`.

Editor artifacts belong to Neovim's config/data/state/cache roots. OAuth
credentials use the explicit shared `~/.cli-proxy-api` directory. Starter copies
legacy profile auth JSON files there without overwriting existing credentials,
retains originals, and refuses redirected directories. Uninstalling the app
retains the shared login directory. `chats/welcome.md` contains
setup instructions before its first question and is a recognized chat filename
for both attachment and finder discovery. Legacy welcome-folder chats move via
the existing chat-tree mover, preserving attachments and refusing conflicts.
For manual profile removal, stop the owned managed proxy first as described
in the recovery section above. See the
[starter guide](../../packaging/starter-config/README.md) for commands and recovery.

`scripts/check-starter.py` rejects personal configuration markers in the artifact
and its policy source. Hermetic startup tests inspect effective Parley setup,
not just returned options; local Git/process fixtures exercise bootstrap races
and failures. Release conformance separately exercises the real assembled bundle
with external networking blocked.
`tests/integration/starter_auth_spec.lua` covers legacy auth migration, collision
preservation, private permissions and refusal of redirected credential roots.

## Bundled help and local access

The default app model receives `parley_help`, a read-only tool for this release's
README, bundled tutorials and Markdown documents linked from `atlas/index.md`.
Calling it without a topic lists IDs; `README` or `atlas/infra/starter` reads a
document. Tutorial IDs are `tutorials/welcome`, `tutorials/basics`,
`tutorials/advanced` and `tutorials/vim-basics`. Lua source is
already packaged for Neovim to execute, but the help tool does not expose it.

README's marked introduction is also appended after chat prompt resolution, with
app/plugin mode, so the welcome question needs no tool call to get basic guidance.
The same text owns the user-facing introduction and request context (ARCH-DRY).
`parley_help = false` disables that context; explicit agent tool lists control
tool availability. The plugin's default @all roster includes help automatically.
No doc text is written back into configured agents or chat metadata.

`help_content` discovers topic IDs from the shipped atlas index; `help` resolves
only those documents under the runtime root, rejects redirected/symlinked files,
and limits each document to 128 KiB. Missing docs return a tool error; missing or
invalid bootstrap docs omit the introduction without preventing ordinary chat.
Tool output is indented so quoted chat delimiters remain documentation.

General file tools separately use `tool_read_roots`, which accepts multiple
absolute or relative folders. Their primary root is the owning repository for
repo chats, otherwise the chat directory. Extra roots grant reads, not writes;
relative extras resolve against that primary root. Both app and plugin default
to no extra roots, so peer directories are not implicitly accessible. Help
access does not add the package root to those filesystem permissions.

Both entry points enable the registered `@all` tool roster by default. Tool
availability does not expand filesystem permissions; users can request supported
actions without editing configuration. File writes retain existing backup and
confinement behavior. Chat-history search filters configured roots through the
trusted per-request root policy passed by the dispatcher; model input cannot
choose a broader policy. Search therefore stays within the current project by
default, while plugin users can explicitly grant additional read roots.

## Markdown browser preview

The app loads `iamcco/markdown-preview.nvim` and its prebuilt server from the
shared editor manifest. Homebrew resources and local provisioning verify source
archive, binary archive and extracted binary hashes before startup. Bundled
specs disable the plugin's install hook; no Node/Yarn dependency is added.
Keep the `markdown-preview.nvim` directory name: the upstream binary uses it
to locate its assets. App upgrades replace the plugin/server together.

Standalone source bootstrap without a bundle retains the explicit Lazy build:
it runs the versioned upstream installer, then checks the executable version.
Failed download/version verification names `:Lazy build markdown-preview.nvim`
for retry. This fallback does not establish bundled dependency parity.

The Markdown filetype and `MarkdownPreview`, `MarkdownPreviewToggle`, and
`MarkdownPreviewStop` commands load the plugin. Auto-start and network exposure
are explicitly disabled; upstream owns preview process shutdown on Stop/editor
exit. Bootstrap fixtures cover bundled local specs and standalone install errors.
The real bundle conformance runner opens the production starter with external
networking denied, fetches Preview's loopback HTML and compares payload hashes
before/after. That runtime assertion, rather than a download stub, is the offline
verification boundary.

## Stable tutorial filenames

`welcome.md`, `basics.md`, `advanced.md` and `vim-basics.md` are recognized chat filenames without timestamps.
The topic header provides their displayed titles (for example, “2. A Bit More
Basics”); changing that title does not rename these files. Ordinary new chats
retain timestamp-plus-topic filenames. The shared chat filename predicate owns
recognition for both attachment and Finder. Starter integration tests verify
`basics.md` is discoverable and skipped by automatic topic-slug renaming.
`lua/parley/tutorials.lua` owns the ordered names used by seeding, help discovery,
chat recognition and finder diagnostics.
The four lessons ship in `packaging/tutorials/` and are seeded together under
the existing initializer lock using atomic hard links. Existing files are never
overwritten, so edited lessons survive upgrades. Seed text contains only the
authored preamble and first practice question, without private AI responses.

The VIM Basics keyboard exercise is executable against the real app profile:

```sh
PARLEY_DEMO_DIR=/tmp/parley-vim-basics-check ./parley_app --headless -i NONE \
  -c "luafile $PWD/tests/packaging/vim_basics_compatibility.lua"
```

Use a new disposable demo path; the launcher may provision its manifest bundle
before opening the editor. Existing bundles are verified before reuse.
The probe edits only the seeded copy and supplies an in-memory clipboard provider.
It checks jump history (including Tab), undo/redo, smart-case search, selection,
copy/cut/paste and explicit save with the packaged mappings loaded.

## Paths in repo mode

For file-tool requests in repo mode, the directory containing `.parley` is the
base: `notes.md` means `<repo-root>/notes.md`, and `workshop/parley/chat.md` means
`<repo-root>/workshop/parley/chat.md`. The chat file's nested location does not
move that base. Outside repo mode, the chat directory supplies the base.
Markdown navigation links are a distinct document convention: `./basics.md`
resolves beside the document containing the link.

The app discovers `.parley` in the launch directory or its ancestors before
setup, and explicitly passes that project root. A Git repository is not required.
`starter_project_spec` exercises this using real marker-only fixture projects,
nested cwd, an unmarked global launch and the preserved plugin chat-dir override.

The packaged editor uses `ignorecase` + `smartcase` for native `/` and `?` search.

Onboarding delegates proxy availability to `cliproxy.ensure_running`: an existing
server can serve the saved model even when the current profile has no executable.
Credential and model checks still decide whether account/model setup is needed.

The demo launcher uses a canonical sibling directory lock across ownership
validation, PID publication and reset; reset cannot delete the active lock.
