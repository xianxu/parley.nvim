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
Shortcuts come from the config override (`config_key`) **or** `default_key` —
`resolve_keys` **replaces**, it does not merge or fall back
(`keybinding_registry.lua:965`):

```lua
if not entry.config_key then
    return as_list(entry.default_key), entry.default_modes
end
```

Two consequences, both of which have bitten (#214):

- Editing `default_key` on an entry that HAS a `config_key` is **inert** — the
  config value wins and the edit does nothing.
- **Adding** a `config_key` to an entry silently **discards** whatever
  `default_key` held. For a multi-key entry that deletes bindings: giving
  `chat_drill_in` a single-string config default would drop `<M-q>`. An arch
  guard asserts the shipped config resolves to a superset of `default_key`.

Both `default_key` and a config `shortcut` accept a string or a **list**; the
list is the alias mechanism (`chat_drill_in` = `{ "<C-g>q", "<M-q>" }`).

Help reads live keymaps first; falls back to config/default. **It renders only
`keys[1]`**, so an entry's aliases are invisible in `<C-g>?` — which is why the
shipped order puts the portable key first (`branch_ref` leads with `<M-i>`, not
the `<M-S-CR>` mnemonic that most terminals cannot distinguish from `<CR>`).

## Unbound but callable
A binding may be deliberately keyless and still reachable. `chat_toggle_tool_folds`
ships no key — a tool call's *result* is low-value reading, so folding it does not
justify a key out of the shared `<C-g>` surface — but is invokable as
`:ParleyToggleToolFolds`, and the registry callback *is* that command, so binding
it cannot drift from calling it. "Unbound" must not mean "unreachable".
