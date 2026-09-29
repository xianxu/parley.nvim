# Spell Typeahead

Chat spelling uses Neovim's dictionaries and Blink's completion menu in Normal
and Insert modes. The plugin and packaged app share the same controller.
`chat_spell.blink = true` is the default; suggestions activate when Blink has
finished setup. Parley does not install Blink or call its setup for plugin users.

## Behavior

After a 180 ms pause, an eligible misspelling under the cursor offers whole-word
corrections. Insert mode also recognizes the word immediately before the cursor
at its end, without crossing whitespace. Short words such as `teh` qualify;
Blink spelling has no minimum word length. The app's separate buffer-word
provider still starts after two typed characters.

| Key while a Parley spelling menu is open | Effect in Normal and Insert modes |
|---|---|
| Tab / Down | Select the next item |
| Up | Select the previous item |
| Enter | Accept the selected item, or the first item if none is selected |
| Esc | Dismiss the menu, retaining the current mode |

Selection and menu refresh do not edit text. Acceptance replaces the whole word,
including when the cursor is inside it. In Normal mode the correction has its
own undo entry and leaves the cursor on the last replacement character. Insert
acceptance uses Blink's normal edit path with the original whole-word range.

The controller borrows buffer-local mappings only while its menu is open and
restores the effective prior mappings when it closes. With no spelling menu,
keys retain their prior behavior, including prompt submission and interview
Return handling. An intervening user remap is preserved.

Esc suppresses further suggestions on the same unchanged word, including movement
within it or a switch between Normal and Insert. Leave that word, change it, or
explicitly request suggestions again:

```vim
:lua require('parley.spell_blink').request()
```

This public entry point targets the current attached chat; `request(buf)` accepts
an explicit buffer number. Native Blink typing requests do not bypass the debounce
or clear dismissal. Changes to text, cursor, window, buffer or mode invalidate
old acceptance evidence; a delayed result cannot apply to a new target.

## Config

`require('parley').setup({ chat_spell = { ... } })` merges these defaults:

| Key | Default | Meaning |
|---|---|---|
| `enable` | `true` | Visible spell underlines, independently of either menu backend |
| `blink` | `true` | Use ready Blink for Normal/Insert spelling suggestions |
| `debounce_ms` | `180` | Delay before a Blink spelling request; finite values are rounded down and clamped to 0–5000 ms |
| `typeahead` | `false` | Opt into the legacy Insert-only popup when Blink is disabled or unavailable |
| `spelllang` | `"en_us"` | Buffer dictionary language, also used with underlines disabled |
| `min_word` | `4` | Legacy popup minimum word length; does not limit Blink spelling |
| `max_suggest` | `9` | Maximum suggestions; Blink clamps finite values to 1–20 |

Non-finite or nonnumeric Blink debounce/maximum values use the defaults.
Set `enable = false` to hide underlines while keeping suggestions. Set
`blink = false, typeahead = false` to disable both suggestion backends while
keeping underlines. A raw `spell.attach` call with neither popup flag enabled
installs neither popup; the public setup defaults are merged before attachment.

If Blink is absent, not set up, or incompatible, chats remain usable with native
spell underlines. Legacy suggestions run only with explicit `typeahead = true`.
The controller retries readiness on later buffer, cursor and mode events. When
Blink becomes ready, it retires legacy popup resources before taking ownership.

## Plugin setup and completion ownership

Install and load Blink **v1.10.2**, commit
`78336bc89ee5365633bcf754d93df01678b5c08f`, through your plugin manager. For a fresh
configuration, initialize it before Parley:

```lua
require("blink.cmp").setup({
  fuzzy = { implementation = "lua" },
  sources = { default = { "buffer" } },
})
require("parley").setup({
  chat_spell = { blink = true, enable = true },
})
```

The Lua matcher needs no downloaded native matcher library. If Blink is already
configured, retain its setup and provider list; Parley adds its spelling source
to the existing Insert providers. Normal-mode requests use only spelling.
The app already loads the pinned Blink dependency and consumes this same plugin
integration; it has no separate spelling implementation.

While Blink owns a chat, Parley's nvim-cmp neighborhood adapter yields to it.
Native `completefunc` and manual path completion remain available. This does not
disable unrelated user nvim-cmp configuration; manually enabling two completion
engines in the same chat is unsupported. Neighborhood-path migration to Blink
is separate work.

The compatibility boundary is tested against the pin above. Readiness inspects
Blink's already-loaded trigger module, without loading it to manufacture a ready
state. A scoped adapter wraps the loaded completion list's selection policy to
prevent preview edits during refresh of an owned context. It preserves user
configuration and delegates foreign contexts unchanged; the original function
is restored on last detach if the adapter still owns it. Missing expected
internals leave the integration inactive. Recheck this boundary when changing
the Blink pin.

## Bounds and legacy fallback

Words use Neovim's Unicode alphabetic matching, allowing internal straight or
curly apostrophes. Ranges are UTF-8 byte offsets. Lines over 16 KiB and words over
128 bytes receive no Blink spelling suggestions. The controller reads only the
current line, holds one pending timer per attached buffer and caps the suggestion
count at 20. Native `spellbadword`/`spellsuggest` calls are synchronous and use the
buffer's `spelllang`; this path does not perform network work.

The opt-in legacy backend retains its Insert-only end-of-word behavior and
`min_word = 4` threshold. It opens Neovim's native popup with no selected item.
Return accepts a selected item; with no selection it dismisses and inserts the
ordinary newline (or interview timestamped newline). Its Return map is omitted
for prompt buffers, which retain native Return-to-submit. Disabling or replacing
the backend restores mappings and removes its autocmds.

## Key files

- `lua/parley/spell_state.lua` — pure word targeting, dismissal and acceptance state.
- `lua/parley/spell_blink.lua` — observations, debounce, dependency readiness and mapping ownership.
- `lua/parley/spell_source.lua` — native dictionary lookup and guarded Blink edits.
- `lua/parley/spell.lua` — backend selection, underlines and legacy fallback.
- `lua/parley/config.lua` — shared defaults; `lua/parley/init.lua` attaches chats.
- `lua/parley/neighborhood.lua` — completion ownership and manual path completion.
- `tests/unit/spell_state_spec.lua` and `tests/unit/spell_spec.lua` — pure contracts.
- `tests/integration/spell_blink_spec.lua`, `spell_source_spec.lua` and
  `spell_chat_spec.lua` — stateful controller, native editing and backend tests.
- `tests/packaging/spell_compatibility.lua` — keyboard conformance against pinned Blink.
