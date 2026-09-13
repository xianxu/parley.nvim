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
puts the key a reader should reach for first, because the column is the one they
see. Two rules decide it: the **alt spelling leads** for transcript actions —
`branch_ref` with `<M-i>`, `chat_prune` with `<M-p>`, `open_file` with `<M-o>`,
each keeping its `<C-g>` spelling as a legacy alias rather than revoking it — and
the **portable key leads** where portability is the issue, so `branch_ref` shows
`<M-i>` and not the `<M-S-CR>` mnemonic most terminals cannot distinguish from
`<CR>`.

The alt family means "act on this transcript": quote, respond/define, accept,
reject, branch, prune, outline, skill picker (`<M-s>`), paste an image as an
attachment (`<M-v>`, `paste_image`, #231), and follow-a-link
(`<M-o>`, #225 — one key for "go to what I'm looking at", falling through to
smart `gf` when the cursor is not on a parley reference). `<C-g>` is
the prefix surface for everything else. Help takes its keys from
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

**Reversibility, per sample site.** The switch is *sampled* in three places, and
each one is where its decision becomes durable state:

| site | scope | reversible? |
|---|---|---|
| `register_global` | global maps, at `setup()` | **yes** — it tracks what it installed and revokes those maps on the next `setup()`, skipping any key whose `desc` no longer matches (so a key the user rebound afterwards is left alone) |
| `register_buffer` via `prep_chat` / `setup_markdown_keymaps` | buffer-local | governs buffers prepared *after* the flip; `_prepared_bufs` makes each buffer's sample permanent until it is reopened |
| `native_map` | buffer-local | same rule as `register_buffer` |

Before #214 the global site had no teardown, so `setup()` followed by
`setup({ default_keymaps = false })` left 43 global mappings live — the switch
failed in the most natural way to try it.

## Opt-in set
`keybinding_registry.opt_in` names the entries parley ships **unbound**, each
with its reason. Being in that list is the only sanctioned way for a shipped
binding to resolve to nothing; the spec closes it in both directions, so a
binding that silently loses its key fails the suite.

All five `<leader>` copy maps plus `<leader>fo` are in it: `<leader>` is the
user's namespace, and `<leader>fo` mapped oil.nvim, which parley never requires.
`config.lua` carries a paste-ready block to turn any of them on.

## Feature-gated maps
A third category, distinct from both defaults and opt-ins:
`keybinding_registry.feature_gated` names keys that exist **only** because a
feature was switched on — `chat_spell.typeahead`'s insert-mode `<CR>`, and
interview mode's. They are not keyspace claims: turning the feature off removes
them. They are listed so the leak guard's allowance list is genuinely closed
rather than reporting a documented opt-in as an escape.

Interview's `<CR>` is **global**, and its teardown **restores what it shadowed**.

The bug was that teardown did an unconditional `vim.keymap.del("i", "<CR>")`, so
leaving interview mode deleted the user's own `<CR>` map — cmp/blink's accept
key, for most people — instead of putting it back. `del` cannot tell "mine" from
"theirs" at **any** scope, so narrowing the map to buffer-local (a first attempt)
only moved the collision: it then destroyed the one buffer-local `<CR>` parley
itself installs, spell typeahead's, and confined session state to a single
buffer while the statusline still reported the mode as on.

Global is the right scope because interview mode *is* session state, and because
spell's buffer-local `<CR>` already delegates to `interview.cr_keys` through
`base_cr` (#134) — a global interview map is what that design expects. Teardown
captures the previous mapping with `nvim_get_keymap` (`maparg` returns a
buffer-local map when both exist) and restores it with `mapset`, which
round-trips Lua-callback maps.

Its timer handle lives in a module-local, never in `_state`: `refresh_state`
deepcopies `_state`, and a libuv userdata cannot be deepcopied — parking it there
made every `refresh_state` caller raise while the mode was on, so opening any
chat file errored.

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
