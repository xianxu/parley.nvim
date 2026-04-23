# Spec: Key Bindings Help

## Command
`:ParleyKeyBindings` (`<C-g>?`): centered floating window showing context-scoped shortcuts.

## Architecture: Keybinding Registry
All keybindings are declared in `lua/parley/keybinding_registry.lua` — a single source of truth. Each entry carries:
- `id`, `scope`, `desc`, `default_key`, `default_modes`
- optional `config_key` for user-configurable bindings
- optional `help_desc` override for the help display

Registration and help generation are both driven from this registry. Adding a keybinding = one registry entry; everything else follows.

## Scope Forest
Contexts form a hierarchy; help shows all scopes from leaf to root:

```
global                  — always shown
├── parley_buffer       — shared: chat and markdown buffers
│   ├── chat            — chat-specific (respond, stop, agent…)
│   └── markdown        — non-chat .md files (review, chat refs, delete)
│       ├── note        — parley note files (interview mode)
│       └── issue       — parley issue files (status, decompose, goto)
├── repo                — repo-mode features (issue/vision finders)
└── vision              — vision YAML files (validate, export)

chat_finder / note_finder / issue_finder  — standalone (only their own keys shown)
```

Buffer context is auto-detected (`detect_buffer_context`): vision YAML, issue dir, note dir, repo marker (`.parley`), chat file, or other.

## Resolution
Shortcuts resolved from config override (`config_key`) then `default_key`. Help reads live keymaps first; falls back to config/default.
