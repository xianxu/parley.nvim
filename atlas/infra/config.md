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

## Merge order

1. Plugin defaults in `lua/parley/config.lua`.
2. `setup(opts)` overrides.
3. Per-chat header metadata, for supported request fields such as model and prompt.

Hooks merge by key; agents and system prompts merge by their `name`. Each supplied
named entry replaces that entry, rather than recursively merging its fields.
Other options replace the corresponding option wholesale, including nested
configuration tables. Provider definitions and credentials have dedicated setup
handling. `defaults.lua` contains runtime constants/templates, not a second full
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
