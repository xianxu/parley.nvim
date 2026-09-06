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
`resolve_keys` (`keybinding_registry.lua`) picks ONE source — it never merges —
but it falls back far more often than "config wins" suggests. Measured, not
inferred:

| config for the entry | resolves to |
|---|---|
| no `config_key` on the entry | `default_key` |
| `config_key` set, key absent from config | `default_key` |
| table without a `shortcut` field | `default_key` |
| bare string (`k = "<Z>"`) | `default_key` |
| `shortcut = ""` | `default_key` |
| `shortcut = "<Z>"` or `{ … }` | **the config value** |

So **only a table with a non-empty `shortcut` replaces**. Two consequences that
have bitten this repo (#214):

- Editing `default_key` is inert **when config supplies a real shortcut** —
  which is why `chat_prune`'s chord had to change in `config.lua`, not the
  registry.
- A config value that supplies a *single* key where `default_key` held a list
  **shrinks** the binding set: giving `chat_drill_in` `shortcut = "<C-g>q"`
  would drop `<M-q>`.
- `shortcut = ""` does **not** disable a binding — it falls through to the
  default. Today the only way to ship an entry disabled is `default_key = nil`
  (how `chat_toggle_tool_folds` does it).

Both `default_key` and a config `shortcut` accept a string or a **list**; the
list is the alias mechanism (`chat_drill_in` = `{ "<C-g>q", "<M-q>" }`).

Help reads live keymaps first, then config/default. **It renders only
`keys[1]`**, so aliases are invisible in `<C-g>?` — which is why the shipped
order puts the portable key first (`branch_ref` leads with `<M-i>`, not the
`<M-S-CR>` mnemonic most terminals cannot distinguish from `<CR>`).

## Unbound but callable
A binding may be deliberately keyless and still reachable. `chat_toggle_tool_folds`
ships no key — a tool call's *result* is low-value reading, so folding it does not
justify a key out of the shared `<C-g>` surface — but is invokable as
`:ParleyToggleToolFolds`, and the registry callback *is* that command, so binding
it cannot drift from calling it. "Unbound" must not mean "unreachable".
