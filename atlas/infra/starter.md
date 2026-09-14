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

First-install bootstrap closes Lazy's installer view and restores the original
editor window before starting Parley. Lazy's view closes asynchronously, so focus
restoration is explicit: the welcome chat must never inherit its 80% floating
window. Bootstrap coverage exercises an actual Neovim float as well as cached
startup, even when the test process itself runs headless.

## Configuration ownership today

| Owner | Responsibility |
|---|---|
| `lua/parley/config.lua` | Current plugin defaults consumed by `setup(opts)` |
| `lua/parley/starter_config.lua` | Release policy overrides, derived from supplied profile roots |
| `lua/parley/starter.lua` | Applies release policy, initializes profile and welcome chat, starts onboarding |
| `packaging/starter-config/init.lua` | App editor settings, pinned dependency bootstrap and starter entry |
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
| First use | Missing welcome, basics and advanced tutorials are seeded without overwriting edits; the welcome preamble explains connection, model selection and sending and is excluded from the LLM question |
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
| Installed editor plugins | `~/.local/share/parley/lazy/` | `XDG_DATA_HOME` |
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

1. A failed download normally removes its own staging. Check internet access
   and retry `parley`. The starter requires Neovim 0.11+, Git and curl; Homebrew
   supplies the app runtime. When the editor opens, `:checkhealth parley` reports
   feature dependencies. A preview-server build failure can be retried with
   `:Lazy build markdown-preview.nvim`.
2. An error saying an initializer is **still active** means another launch owns
   it; let that launch finish. If the error explicitly says **requires repair**,
   close all Parley instances, then remove only the initializer directory named
   in that error and retry. The possible default locations are
   `~/.config/parley/.launcher-initializer`,
   `~/.local/share/parley/initializer.lock` and
   `~/.local/state/parley/welcome-initializer`. With XDG overrides use the reported
   path, not these defaults. Do not remove the entire profile to clear a lock.
3. An incomplete installed Lazy checkout is reported with its exact directory.
   Close Parley, remove only that reported checkout and retry; the starter
   downloads it again. An incomplete welcome chat is also reported by path:
   back up and repair that file, or move it aside and restart to seed a fresh
   copy. Existing tutorial edits are otherwise preserved.
4. If loopback port 8317 belongs to another service, stop that service or change
   the configured proxy port. Parley does not remove a foreign listener.

Upgrades preserve `init.lua`; compare any adjacent `init.lua.new` before adopting
new starter settings. Before removing app profile data, save chats/assets you
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
NVIM_APPNAME=parley PARLEY_RUNTIME="$PWD" nvim -u "$PWD/packaging/starter-config/init.lua"
```

This uses the working tree and the same starter entry as the release, including
pinned dependencies. It uses existing Parley profile data and may download missing
plugins. It does not exercise Homebrew formula installation or launcher upgrades.

`make test-spec SPEC=infra/starter` follows [traceability](../traceability.yaml).
The policy unit spec defends defaults, key families, and finder-local controls; starter integration probes
inspect effective setup, profile isolation, welcome parsing, finder visibility,
keymaps and model selection before sending. Onboarding/readiness specs cover
provider selection, cancellation and changed-source handling. Bootstrap fixtures
exercise installation failures and retry. Full packaging/VM acceptance remains
necessary for release transport and installation behavior.

## Runtime and lifecycle details

The single editable `packaging/starter-config/init.lua` is the app entry under
`NVIM_APPNAME=parley`. It bootstraps pinned Lazy and editor dependencies, then
loads a released Parley version. Packaging can supply `PARLEY_RUNTIME` to use its
installed release. A profile initializer directory owns staged Git work and
serializes first installation; dead or incomplete ownership requires explicit
recovery instead of stealing a competing initializer's work.

`starter_config.options(roots)` is the pure profile policy projection. It uses
loopback port 8317 and the `parley-local` client key, matching `define` defaults;
no client-key file is created or read. Provider OAuth and proxy management
credentials remain separate. The profile retains Ctrl+g and Alt key families plus finder-local controls
from the default bindings and adds Alt+Enter for sending. Both chat memory
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
and failures, followed by live upstream bootstrap conformance at release.
`tests/integration/starter_auth_spec.lua` covers legacy auth migration, collision
preservation, private permissions and refusal of redirected credential roots.

## Bundled help and local access

The default app model receives `parley_help`, a read-only tool for this release's
README, bundled tutorials and Markdown documents linked from `atlas/index.md`.
Calling it without a topic lists IDs; `README` or `atlas/infra/starter` reads a
document. Tutorial IDs are `tutorials/welcome`, `tutorials/basics` and
`tutorials/advanced`. Lua source is
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

The app bootstrap includes `iamcco/markdown-preview.nvim` at commit
`a923f5fc5ba36a3b17e289dc35dc17f66d0548ee`. Its Lazy build runs the upstream
versioned prebuilt installer with a 120-second timeout, then executes the server
via argv to verify its version (five-second timeout). The build derives the
platform from Neovim’s host information; it must not call plugin autoload
functions because Lazy function builders run before those files are loaded. No Node/Yarn dependency is
added. Failed download or version verification fails the build and names the
Lazy retry command. Keep Lazy's default `markdown-preview.nvim` directory name:
the upstream binary uses it to locate its assets.

The Markdown filetype and `MarkdownPreview`, `MarkdownPreviewToggle`, and
`MarkdownPreviewStop` commands load the plugin. Auto-start and network exposure
are explicitly disabled; upstream owns preview process shutdown on Stop/editor
exit. Bootstrap fixtures exercise plugin selection, installer success/failure
and version verification. Live conformance checks start a pinned server in an
isolated profile, fetch its local HTML and stop it without opening a browser.

## Stable tutorial filenames

`welcome.md`, `basics.md` and `advanced.md` are recognized chat filenames without timestamps.
The topic header provides their displayed titles (for example, “2. A Bit More
Basics”); changing that title does not rename these files. Ordinary new chats
retain timestamp-plus-topic filenames. The shared chat filename predicate owns
recognition for both attachment and Finder. Starter integration tests verify
`basics.md` is discoverable and skipped by automatic topic-slug renaming.
The three lessons ship in `packaging/tutorials/` and are seeded together under
the existing initializer lock using atomic hard links. Existing files are never
overwritten, so edited lessons survive upgrades. Seed text contains only the
authored preamble and first practice question, without private AI responses.

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
