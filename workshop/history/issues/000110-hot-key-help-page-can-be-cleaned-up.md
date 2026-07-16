---
id: 000110
status: done
deps: []
created: 2026-04-20
updated: 2026-04-22
---

# Keybinding Registry — Single Source of Truth for Hotkeys

## Done when

- All parley keybindings are declared in a single registry with scope metadata
- Registration (vim.keymap.set) is driven from the registry, not ad-hoc
- Help display is auto-generated from the registry based on current buffer context
- Adding a new keybinding = one registry entry, everything else follows
- All previously hardcoded keybindings become configurable
- Existing tests pass, new tests cover registry completeness

## Spec

### Problem
Keybindings are registered ad-hoc across init.lua (multiple sections), and the help
display manually lists them with hardcoded context checks. They drift apart — e.g.
`<C-g>vf` was missing from help. Some keybindings are configurable (via config keys),
others are hardcoded. No single place to see what exists.

### Design

**Registry entry** — each keybinding declared once:
```lua
{
  config_key = "chat_shortcut_respond",  -- key in config table (nil for non-configurable)
  default_key = "<C-g><C-g>",
  default_modes = { "n", "i", "v", "x" },
  scope = "chat",
  desc = "Respond",                      -- vim keymap description (also used in help)
  help_desc = "Send response",           -- optional override for help display
  callback = "respond",                  -- string key resolved at setup time, or function
}
```

**Scope forest:**

```
global                  — always active, always shown
├── parley_buffer       — shared between chat and markdown (open file, copy fence, outline, branch ref)
│   ├── chat            — chat-specific (respond, stop, agent, etc.)
│   └── markdown        — non-chat .md files (review, chat refs, delete)
│       ├── note        — parley note files (interview mode)
│       └── issue       — parley issue files (status, decompose, goto)
├── repo                — repo-mode features (issue/vision finders, note finders)
└── vision              — vision YAML files (validate, export)

chat_finder             — standalone
note_finder             — standalone
issue_finder            — standalone
```

Help for a buffer = collect all scopes from leaf to root:
- Issue file → issue + markdown + parley_buffer + repo + global
- Chat → chat + parley_buffer + repo + global
- Vision YAML → vision + repo + global
- Any file in a repo → repo + global
- File outside repo → global only
- Finder → finder scope only

**New file: `lua/parley/keybinding_registry.lua`** containing:
- Scope hierarchy definition
- All registry entries (~60)
- `get_scopes_for_context(context)` — returns ordered list of applicable scopes
- `get_entries_for_context(context)` — filters registry by applicable scopes
- `resolve_key(entry, config)` — resolves config override or default
- `help_lines(context, buf)` — generates help lines from registry
- `register_global(config, callbacks)` — registers global/repo keymaps
- `register_buffer(scope, buf, config, callbacks)` — registers buffer-local keymaps for a scope

**Changes to init.lua:**
- Replace ad-hoc keymap registration in setup() with `registry.register_global()`
- Replace ad-hoc registration in `setup_chat_mappings()` with `registry.register_buffer("chat", buf, ...)`
- Replace ad-hoc registration in `setup_markdown_keymaps()` with `registry.register_buffer("markdown", buf, ...)`
- Replace `keybinding_help_lines()` with `registry.help_lines()`
- Extend `detect_buffer_context()` with vision + repo detection
- Remove old shortcut_value/resolve_shortcut/keybinding_help_lines (~450 lines)

## Plan

- [x] Create `lua/parley/keybinding_registry.lua` with scope hierarchy + entry schema
- [x] Populate registry with all ~60 keybinding entries
- [x] Implement `get_scopes_for_context()` and `get_entries_for_context()`
- [x] Implement `help_lines()` — registry-driven help generation
- [x] Implement `register_global()` and `register_buffer()`
- [x] Extend `detect_buffer_context()` for vision + repo
- [x] Replace `keybinding_help_lines()` with registry call
- [x] Remove old ad-hoc help code (~540 lines removed from init.lua)
- [x] Update tests (20 tests, all passing)
- [x] Wire init.lua setup() to use `register_global()` — replaced ~220 lines of ad-hoc registration
- [x] Wire `setup_chat_mappings()` to use `register_buffer("chat", ...)` — replaced ~200 lines
- [x] Wire `setup_markdown_keymaps()` to use `register_buffer("markdown", ...)` — replaced ~170 lines
- [x] Manual verification: help in each context

## Log

### 2026-04-22

- Cataloged all keybindings: ~60+ entries across global, chat, markdown, note, issue, finder, and vision scopes
- Key issues found:
  - Review shortcuts (`<C-g>vi/vr/ve/vf`) missing from help
  - Copy shortcuts (`<leader>cl/cL/cc/cC`) missing from help
  - Toggle tool folds (`<C-g>b`) missing from chat help
  - Vision shortcuts missing from help
  - Some keybindings hardcoded (not configurable)
  - Some keybindings shared between chat and markdown but no shared scope
- Quick fix applied: added missing entries to help display
- Designed scope forest with parley_buffer as shared parent of chat and markdown
- Scoped issue to keybinding registry only; decomposing other init.lua sections tracked in #111
