# Spell Typeahead

As-you-type spelling assist for chat buffers: type a misspelled word and a
completion menu of `spellsuggest()` results pops up (pick with Tab / `<CR>` /
arrows, or keep typing). Plugin-free — built on Neovim's built-in
`spellbadword`/`spellsuggest`, which work even when the `spell` option is off.
Ported (single concern) from the sibling `pair` repo's `spell_complete`.

## Behavior

Per insert-mode keystroke (`TextChangedI` / `TextChangedP`) in a chat buffer,
`spell.suggest`:

1. Takes the alphabetic (`[%a']`) word ending at the cursor. Bails if the cursor
   is *inside* a word (mid-word edit would be mangled by `complete()`'s replace
   span) or there's no word.
2. Bails if the word is shorter than `min_word` (default 4).
3. `spellbadword(word)` — bails if correctly spelled.
4. `spellsuggest(word, max_suggest)` — bails if no suggestions.
5. Pops the menu via `helper.complete_noselect(start, suggestions)` — the shared
   `completeopt=menuone,noinsert,noselect` idiom (also used by
   `vision.on_text_changed_i`).

**`<CR>` handling.** Under `noselect` nothing is auto-highlighted, so a bare
`<CR>` over the open menu only closes it and *swallows the newline*. A
buffer-local insert `<CR>` map routes through the pure `spell.cr_keys`:

| popup | selection | keys feed   | effect                         |
|-------|-----------|-------------|--------------------------------|
| no    | —         | `<CR>`      | plain newline                  |
| yes   | yes       | `<C-y>`     | accept the highlighted item    |
| yes   | no        | `<C-e><CR>` | dismiss the menu, then newline |

The `<CR>` map is skipped when `chat_prompt_buf_type` is set (there `<CR>`
already triggers respond via `prompt_setcallback`).

## Config

`config.chat_spell` (defaults on):

| key           | default   | meaning                                            |
|---------------|-----------|----------------------------------------------------|
| `enable`      | `true`    | visible spell underlines (window-local `spell`)    |
| `typeahead`   | `true`    | the as-you-type suggestion menu + `<CR>` handling  |
| `spelllang`   | `"en_us"` | spell language (set even when `spell` is off)      |
| `min_word`    | `4`       | min misspelled-word length before suggesting       |
| `max_suggest` | `9`       | max suggestions shown in the menu                  |

`enable` and `typeahead` are independent — `spellsuggest()` reads `spelllang`
regardless of the `spell` option, so squiggles and typeahead are separately
gateable (e.g. `typeahead`-only with no underlines).

## Key files

- `lua/parley/spell.lua` — pure core (`word_at_cursor`, `cr_keys`) + IO seam
  (`suggest`, `attach`).
- `lua/parley/helper.lua` — `complete_noselect(start, items)`, the shared
  non-blocking typeahead idiom (spell + vision).
- `lua/parley/init.lua` — `M.prep_chat` calls `spell.attach(buf, …)` after
  `prep_md`, gated on `config.chat_spell` and threading `prompt_buf_type`.
- `lua/parley/config.lua` — `chat_spell` defaults.
- `tests/unit/spell_spec.lua` — pure-function specs.
- `tests/integration/spell_chat_spec.lua` — live attach + popup specs.
