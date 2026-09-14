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
must not fork those implementations. App profile isolation keeps its chats,
credentials and state separate from a plugin configured in ordinary Neovim.

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
| First use | Welcome preamble explains connection, model selection and sending; the preamble is excluded from the LLM question |
| LLM setup | Missing connection opens the provider float; an available provider supplies model choices; successful selection resumes the pending action |
| Setup cancellation | Cancel aborts the pending action; changed source requires retry; headless mode never opens a picker |
| Proxy | Managed CLIProxyAPI on loopback port 8317 with client key `parley-local`; account credentials remain profile-local |
| Keys | All Ctrl+g prefixes and Alt chords, including Alt+Enter; other integration shortcut families disabled |
| Optional features | Chat memory summaries, preference generation and web search disabled; everyday file/search tools and bundled help enabled |
| Customization | Existing Neovim users retain `setup(opts)` as the configuration boundary |

## Default convergence direction — not yet implemented

The intended product direction is one portable baseline shared by the app and
an unconfigured plugin. Personal paths, preferred agents, broad tool access and
Ariadne-specific workflow choices belong in the author's machine configuration,
not in defaults distributed to strangers (ARCH-DRY).

Today the two configurations still differ: plugin defaults include personal
chat/note/export paths, `ToolOpus*` with `@all` tools, web search and chat memory
enabled, and broader default keymaps. The release overrides these explicitly.
[Issue #211](../../workshop/issues/000211-personal-config-out-of-defaults.md)
already tracks removing personal defaults; convergence must include these policy
differences and tests of bare `setup()` as well as the release profile.

Sharing defaults means sharing product policy, not literal directories or editor
bootstrap. Derive storage from each entry point's own profile; keep dependency
installation, theme/editor settings and automatic welcome opening app-specific.
Before migration, inventory the author's effective overrides and move that delta
into the personal configuration. Preserve explicit plugin overrides and existing
chats. This direction is recorded here; plugin defaults have not been migrated.

## Test the application configuration without Homebrew

From the checkout root:

```sh
NVIM_APPNAME=parley PARLEY_RUNTIME="$PWD" nvim -u "$PWD/packaging/starter-config/init.lua"
```

This uses the working tree and the same starter entry as the release, including
pinned dependencies. It uses existing Parley profile data and may download missing
plugins. It does not exercise Homebrew formula installation or launcher upgrades.

`make test-spec SPEC=infra/starter` follows [traceability](../traceability.yaml).
The policy unit spec defends defaults and key families; starter integration probes
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
credentials remain separate. The profile retains Ctrl+g and Alt key families
from the default bindings and adds Alt+Enter for sending. Both chat memory
summaries and preference generation are disabled in this profile.
`starter.start()` applies the policy, seeds missing bundled tutorials and reopens the welcome chat, and
uses `:ParleyProxy connect` for account selection and login. The proxy command
is available in ordinary plugin setup as well as the starter.
`starter.connect()` delegates to the shared onboarding flow.

`starter_onboarding` coordinates interactive startup through the existing proxy
health, login and picker APIs. A saved real model skips onboarding; otherwise a
usable connected provider opens the model picker and no connected provider opens
Connect. An unavailable account-health check still tries the model catalog; if
no usable catalog can be obtained, it opens provider selection without a blocking
setup error. Initial proxy-start failure also opens provider selection; an actual
login attempt still reports operational failures. Successful login opens the
picker with the invalidated catalog. Headless
startup and cancellation do not reopen dialogs. The placeholder agent is hidden
from the picker.
`llm_readiness.defer` also guards LLM actions before request construction. It
validates provider/model availability, scopes model selection to the provider,
and resumes against the original buffer and cursor. Cancellation or changed
source cancels the pending action. The starter opts into this behavior with
`llm_onboarding`; ordinary plugin configuration is unchanged.
Connect uses `float_picker` with stable provider identities and selection recall,
matching the agent selector's floating UI. Cancellation releases the active
connection prompt so it can be reopened explicitly.

`cliproxy.live_models.tools` flows through the shared `live_agent_options` into
`cliproxy_catalog.build_agent` for both picking and restoring live models. An
explicit empty table keeps local tools disabled; omission retains `@all`.

All writable profile artifacts belong to Neovim's config/data/state/cache roots;
the proxy auth directory is explicitly profile-local. `chats/welcome.md` contains
setup instructions before its first question and is a recognized chat filename
for both attachment and finder discovery. Legacy welcome-folder chats move via
the existing chat-tree mover, preserving attachments and refusing conflicts.
Uninstall stops the
owned managed proxy before removing those roots. See the
[starter guide](../../packaging/starter-config/README.md) for commands and recovery.

`scripts/check-starter.py` rejects personal configuration markers in the artifact
and its policy source. Hermetic startup tests inspect effective Parley setup,
not just returned options; local Git/process fixtures exercise bootstrap races
and failures, followed by live upstream bootstrap conformance at release.

## Bundled help and local access

The default app model receives `parley_help`, a read-only tool for this release's
README and Markdown documents linked from `atlas/index.md`. Calling it without a
topic lists IDs; `README` or `atlas/infra/starter` reads a document. Lua source is
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

The app enables `parley_help`, `read_file`, `ls`, `find`, `grep`,
`chat_history_search`, `write_file` and `edit_file` automatically. Users can ask
for these actions without editing configuration. Internal skill-output tools are
not offered in ordinary app chats. File writes retain existing backup and
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
