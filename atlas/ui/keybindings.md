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
`resolve_keys` (`keybinding_registry.lua`) picks ONE source — it never merges.
Measured, not inferred:

| config for the entry | resolves to |
|---|---|
| `default_keymaps = false` anywhere in config | **nothing** (master switch, below) |
| no `config_key` on the entry | `default_key` |
| `config_key` set, key absent from config | `default_key` |
| table without a `shortcut` field | `default_key` (its `modes` still apply) |
| bare string (`k = "<Z>"`) | `default_key` |
| `shortcut = ""` or `{}` | **nothing — disabled** |
| `shortcut = "<Z>"` or `{ … }` | **the config value** |

So an **explicit `shortcut` is authoritative in both directions**: non-empty
rebinds, empty disables. Anything else falls back. Two consequences that have
bitten this repo (#214):

- Editing `default_key` is inert **when config supplies a real shortcut** —
  which is why `chat_prune`'s chord had to change in `config.lua`, not the
  registry.
- A config value that supplies a *single* key where `default_key` held a list
  **shrinks** the binding set: giving `chat_drill_in` `shortcut = "<C-g>q"`
  would drop `<M-q>`. A test asserts every shipped default is a superset of its
  entry's registry keys, so that shrink fails the suite rather than shipping.

Both `default_key` and a config `shortcut` accept a string or a **list**; the
list is the alias mechanism (`chat_drill_in` = `{ "<C-g>q", "<M-q>" }`).

Help shows **every** bound key: the primary holds the aligned column and the
aliases follow the description as `(also <M-S-CR>, <C-g>i)`. The shipped order
still puts the portable key first, because the column is the one a reader
reaches for — `branch_ref` leads with `<M-i>`, not the `<M-S-CR>` mnemonic most
terminals cannot distinguish from `<CR>`. Help takes its keys from
`resolve_keys` and nothing else: an entry that resolves to nothing is
**omitted**, so the float cannot advertise a key that is not bound. (Before #214
it rendered `keys[1]` only — hiding `<M-q>`, `<M-t>` and `<C-g>i` — and fell
back to `or entry.default_key`, resurrecting exactly the keys resolution had
refused.)

## Every binding is rebindable
Every registry entry carries a `config_key` — enforced by
`tests/unit/keybindings_spec.lua`, not by convention. Before #214, nine entries
had none and could not be rebound or disabled at all.

To rebind: `chat_shortcut_drill_in = { shortcut = "<M-z>" }`.
To disable one binding: `shortcut = ""`.
To disable **all** of parley's default keymaps: `default_keymaps = false`.

## The master switch
`default_keymaps = false` makes parley claim no keys by default: every
registry-derived binding — picker-internal mappings included — and every native
override (below). It lives inside `resolve_keys`, so registration, `key_for`,
and the `<C-g>?` float all go quiet together; help and reality cannot disagree.

**A shortcut the user sets in `setup{}` still binds.** The switch suppresses
parley's *own* claims, not the user's choices — `setup()` records which
`*_shortcut_*` knobs the caller supplied (`config._explicit_shortcuts`) and
`resolve_keys` honours those. Without that carve-out the switch is a one-way
door: no later configuration could bind anything back, and several actions
(`chat_drill_in`/`<M-q>` among them) have no `:Parley*` command to fall back on.

Not covered: **hardcoded** keys inside transient parley windows (`q`/`<Esc>` to
dismiss a picker, motion within it), so a window you opened stays closable; and
maps that exist solely because a feature was switched on (interview-mode `<CR>`,
`chat_spell.typeahead`'s `<CR>`) — those are the feature, not a default.

The switch is read when a buffer is *prepared*, and `_prepared_bufs` makes that
per-buffer sample permanent: it governs buffers opened after `setup()`, while
buffers already open keep the keymaps they were given.

## Opt-in set
`keybinding_registry.opt_in` names the entries parley ships **unbound**, each
with its reason. Being in that list is the only sanctioned way for a shipped
binding to resolve to nothing; the spec closes it in both directions, so a
binding that silently loses its key fails the suite.

All five `<leader>` copy maps plus `<leader>fo` are in it: `<leader>` is the
user's namespace, and `<leader>fo` mapped oil.nvim, which parley never requires.
`config.lua` carries a paste-ready block to turn any of them on.

## Native overrides (off-registry by design)
`u`, `<C-r>`, `*`, `#`, `g*`, `g#` are mapped buffer-locally in chat buffers but
have **no registry entry**. Each wraps the native key and falls through to it
unless a parley-specific condition holds — `u`/`<C-r>` only intervene when the
chat owns a pending response; `*`/`#`/`g*`/`g#` only when the cursor sits inside
a `[...]` anchor (#141). They claim no keyspace, so there is nothing to rebind.

That exemption is enforced rather than trusted: `keybinding_registry.native_overrides`
records each key's location and rationale, `init.lua`'s `native_map` refuses to
map a key that is not listed, and `tests/integration/keybinding_agreement_spec.lua`
closes the list — any parley mapping that is neither registry-derived nor listed
fails as a leak.

## Unbound but callable
A binding may be deliberately keyless and still reachable. `chat_toggle_tool_folds`
ships no key — a tool call's *result* is low-value reading, so folding it does not
justify a key out of the shared `<C-g>` surface — but is invokable as
`:ParleyToggleToolFolds`, and the registry callback *is* that command, so binding
it cannot drift from calling it. "Unbound" must not mean "unreachable".
