# Configuration

## Where to customize

The app reads `~/.config/parley/init.lua` (or `$XDG_CONFIG_HOME/parley/init.lua`).
Its starter supplies options to the same `require('parley').setup(opts)` used by
plugin installations. See [the starter profile](starter.md) for app defaults and
[packaging](packaging.md) for the `init.lua.new` upgrade candidate.

## Install as a Neovim plugin

For an existing Neovim configuration, a minimal lazy.nvim entry is:

```lua
{
    'xianxu/parley.nvim',
    config = function()
        require('parley').setup({})
    end,
}
```

Use `:ParleyChatNew` to start a conversation, `:ParleyProxy connect` to connect
an account, and `:ParleyAgent` to select a model. A separately configured API key
is not required when using the managed account path. The plugin requires a
working Neovim installation and `curl`; individual features may need additional
[external tools](dependencies.md). Run `:checkhealth parley` for local advice.
Installing the plugin leaves your editor profile under your control.
Spelling suggestions additionally need Blink **v1.10.2**, installed and set up
before Parley; see [Spell Typeahead](../chat/spell_typeahead.md#plugin-setup-and-completion-ownership).

### Minimal config

`setup({})` is a complete configuration: it boots with no keys and no warnings,
stores chats and notes under `stdpath("data")/parley`, and enters
[repo mode](repo_mode.md) when started under a directory holding `.parley`.
A headless spec pins this (`tests/integration/zero_config_spec.lua`). Typical
personal overrides are storage and export paths only:

```lua
require('parley').setup({
    chat_dir = vim.fn.expand('~/Documents/parley'),   -- global chats
    notes_dir = vim.fn.expand('~/Documents/notes'),
    export_html_dir = vim.fn.expand('~/blog/static'),
    export_markdown_dir = vim.fn.expand('~/blog/posts'),
})
```

Setting `chat_dir` does not turn off repo detection; in a marked project it
becomes the `"global"` root beside the project's chats. Pass `repo_root = false`
to opt out. Models reached through the managed proxy need no API key. Keys are
for agents that call a provider directly (`provider = "openai"`, `"anthropic"`,
`"googleai"`). `api_keys` merges over the defaults, which read `OPENAI_API_KEY`,
`ANTHROPIC_API_KEY` and `GOOGLEAI_API_KEY` from the environment; set an entry to
`false` to drop a default. A key may also be a command, resolved on first use:

```lua
local function keychain(service)
    return { 'security', 'find-generic-password', '-a', 'me:neovim', '-s', service, '-w' }
end
require('parley').setup({ api_keys = { anthropic = keychain('ANTHROPIC_API_KEY') } })
```

A provider without a key reports `vault secret <name> not found` when an agent
first uses it, not at startup.

## Merge order

1. Plugin defaults in `lua/parley/config.lua`.
2. `setup(opts)` overrides.
3. Per-chat header metadata, for supported request fields such as model and prompt.

Hooks merge by key; agents and system prompts merge by their `name`. Each supplied
named entry replaces that entry, rather than recursively merging its fields.
Other options replace the corresponding option wholesale, including nested
configuration tables. Provider definitions and credentials have dedicated setup
handling; `api_keys` merges per provider over the defaults. `defaults.lua` contains runtime constants/templates, not a second full
configuration layer.

## Storage and state

`chat_dir` is the primary writable chat directory; configured `chat_roots` and
legacy `chat_dirs` describe additional discovery roots. Repo mode prepends its
project chat directory and retains the global directory for discovery. Chat roots
are not restored from `state_dir/state.json`; configure them at setup or use the
repo/super-repo modes. Note roots and explicit repo/super-repo choices do persist.
See [repo mode](repo_mode.md) for detection and precedence.

The app places chats, notes, exports and state under its Parley profile. Both app
and plugin share proxy account credentials in `~/.cli-proxy-api`.

## Shortcuts and product defaults

The nested `shortcut` field accepts a string or a list of aliases; for example,
`chat_shortcut_drill_in = { shortcut = "<M-z>" }`. Set that field to `""` or `{}`
to disable the action. A bare string assigned to `chat_shortcut_drill_in` is not
the supported option shape. `default_keymaps = false` disables implicit defaults while retaining
explicit shortcut options. Open `:ParleyKeyBindings` (normally `Ctrl+g ?`) to see
bindings resolved from the current Parley configuration and context. This help
does not inspect arbitrary mappings installed by other plugins or `vim.keymap.set`.
The app retains Ctrl+g/Alt families and all finder-local controls; other global
plugin shortcut families are disabled.

Both entry points enable answer-style 📝 summaries, web search and the registered
`@all` tool roster. Automatic memory generation is disabled. Tool availability
does not grant extra filesystem access: `tool_read_roots` defaults to `{}`.
Cursor-follow during streaming defaults on, with a saved preference taking
precedence; `Ctrl+g l` toggles it. Finder recency windows are configurable.

## Implementation and checks

`lua/parley/init.lua` owns setup merging and state persistence;
`config.lua` and `starter_config.lua` own defaults and app overrides.
`keybinding_registry.lua` resolves shortcuts and help. Tests include
`tests/unit/starter_config_spec.lua`, `tests/unit/chat_dirs_spec.lua`,
`tests/unit/keybindings_spec.lua` and `tests/unit/chat_finder_logic_spec.lua`.
