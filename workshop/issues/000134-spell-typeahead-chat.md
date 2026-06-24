---
id: 000134
status: done
deps: []
github_issue:
created: 2026-06-20
updated: 2026-06-20
estimate_hours: 1.5
started: 2026-06-20T20:58:55-07:00
actual_hours: 0.36
---

# spell-suggestion typeahead in chat buffers

## Problem

When composing prompts in a parley chat buffer, there is no spelling assist. The
sibling `pair` repo's embedded nvim has an as-you-type **spell typeahead**: type a
word, and if the spellchecker flags it as misspelled, a completion menu of
`spellsuggest()` results pops up (pick with Tab/CR/arrows, or keep typing). The
user finds this very useful for words they can't spell precisely, and wants the
same in parley chat buffers.

## Spec

Port `pair/nvim/init.lua`'s `spell_complete` (the as-you-type fallback completer)
into parley as a **native, plugin-free** feature, matching parley's existing
`vim.fn.complete()` typeahead idiom (`vision.lua:on_text_changed_i`,
`init.lua` issue-status handler).

**Decisions (confirmed with user):**
- Native built-in, not the `cmp-spell` plugin (self-contained, dependency-free,
  works regardless of the user's completion-engine setup).
- Also enable visible spell **squiggles** (`spell=true`) on chat buffers, in
  addition to the typeahead menu.

**Behavior** (per keystroke, `TextChangedI`/`TextChangedP` in a chat buffer):
1. Take the alphabetic (`[%a']`) word ending at the cursor. Bail if the cursor
   sits *inside* a word (char under cursor is alphabetic) — mid-word edits must
   not be mangled by `complete()`'s replace span.
2. Bail if the word is shorter than `min_word` (default 4).
3. `spellbadword(word)` — bail if correctly spelled.
4. `spellsuggest(word, max_suggest)` — bail if empty.
5. `vim.fn.complete(start_col, suggestions)` under
   `completeopt=menuone,noinsert,noselect` (parley's house idiom).

**`<CR>` handling (the #65 fix from pair):** under `noselect` nothing is
auto-highlighted, so a bare `<CR>` while the menu is up only closes the menu and
swallows the newline. Add a buffer-local insert `<CR>` map driven by a pure
`cr_keys(visible, has_selection)`:
- no popup → `<CR>` (plain newline)
- popup + selection → `<C-y>` (accept)
- popup, no selection → `<C-e><CR>` (dismiss menu, THEN newline)
Skip this map when `chat_prompt_buf_type` is set (there `<CR>` triggers respond).

**Notable finding:** `spellsuggest()`/`spellbadword()` work even with `spell`
off in modern Neovim, so typeahead and squiggles are independently gateable.

**Config** (`config.lua`, new `chat_spell` table; defaults on per user choice):
```lua
chat_spell = {
  enable = true,        -- spell=true squiggles on chat buffers
  typeahead = true,     -- as-you-type spell-suggestion popup + <CR> handling
  spelllang = "en_us",
  min_word = 4,         -- min misspelled-word length before suggesting
  max_suggest = 9,      -- max suggestions shown in the menu
}
```

**Module:** new `lua/parley/spell.lua` — pure core (`word_at_cursor`, `cr_keys`)
+ thin IO (`suggest(buf, opts)`, `attach(buf, opts)`). Wired from `M.prep_chat`
in `init.lua` after `prep_md(buf)`. (ARCH-PURE: pure word/CR logic unit-tested;
ARCH-DRY: reuses the established `completeopt`+`complete()` idiom rather than a
new completion engine.)

## Done when

- Typing a misspelled word ≥4 chars in a chat buffer pops a spellsuggest menu.
- Squiggles appear on misspelled words in chat buffers.
- `<CR>` over an open no-selection menu inserts a newline (not swallowed).
- Behavior is gated by `config.chat_spell`; defaults on, fully toggleable.
- Unit tests cover `word_at_cursor` + `cr_keys`; an integration test exercises
  the live attach + spellsuggest popup in a real chat buffer.

## Plan

- [x] Add `chat_spell` defaults to `config.lua`.
- [x] Create `lua/parley/spell.lua` (pure `word_at_cursor`/`cr_keys` + `suggest`/`attach`).
- [x] Wire `spell.attach` into `M.prep_chat` in `init.lua`.
- [x] Unit test `tests/unit/spell_spec.lua` (word_at_cursor + cr_keys).
- [x] Integration test `tests/integration/spell_chat_spec.lua` (live popup).
- [x] Update atlas for the new chat-buffer surface.
- [x] `make test` green; manual smoke in a real chat buffer.

## Estimate

```estimate
model: estimate-logic-v2.1
familiarity: 1.0
item: lua-neovim       design=0.2 impl=0.9
item: milestone-review design=0.0 impl=0.3
item: atlas-docs       design=0.0 impl=0.1
design-buffer: 0.15
total: 1.53
```

*Produced via `brain/data/life/42shots/velocity/estimate-logic-v2.1.md` against `baseline-v2.1.md`. Method A only.*

- **Lua/Neovim feature (single, focused)**: design 1–3 hr × **0.2 spec-quality
  discount** (spec pre-resolves behavior, config shape, module split, CR table;
  ports known-good `pair` code; mirrors the existing `vision.lua` typeahead — the
  existing code IS the spec) = 0.2–0.6 hr design; impl 0.5–1.5 hr (familiarity
  ×1.0 — porting into an established pattern). Step 2.5: the spell engine is a
  built-in (`spellsuggest`/`spellbadword`), no novel stack.
- **Code review (one chunk)**: design 0–0.2 + impl 0.2–0.5 hr.
- **Atlas/docs**: design 0.05–0.2 + impl 0.05–0.2 hr.
- Design subtotal 0.25–1.0 hr, **+15% buffer** (thorough spec ⇒ v2.1 halved
  buffer) = 0.29–1.15 hr. Impl subtotal 0.75–2.2 hr (no buffer).
- **Total ≈ 1.0–3.35 hr, most likely ~1.5 hr.** → `estimate_hours: 1.5`.

## Log

### 2026-06-20
- 2026-06-20: closed — make test GREEN: 0 lint warn/err across 221 files; new spell_spec.lua (10) + spell_chat_spec.lua (8) pass, incl. a live spellsuggest popup driven in insert mode; vision_spec.lua still green after the helper.complete_noselect refactor. Headless-verified spellbadword/spellsuggest work with spell=off.; review verdict: FIX-THEN-SHIP

- Investigated `pair/nvim/init.lua`: relevant piece is `spell_complete` (1817)
  + the `cr_keys` (#65) fix; `path_complete`/`word_complete` are pair-specific
  (agent-output spans) and out of scope.
- Plugin survey: `f3fora/cmp-spell` (nvim-cmp source) is the off-the-shelf
  option and is what pair's own comment says mirrors the user's main config;
  rejected in favor of native (no completion-engine dependency).
- Verified in headless nvim: `spellsuggest()`/`spellbadword()` return results
  with `spell=off` (default spelllang "en") → squiggles and typeahead decouple.
- Implemented: `config.chat_spell` (config.lua); new `lua/parley/spell.lua`
  (pure `word_at_cursor`/`cr_keys` + IO `suggest`/`attach`); wired into
  `prep_chat` after `prep_md`. ARCH-DRY: extracted the shared
  `helper.complete_noselect(start, items)` and refactored
  `vision.on_text_changed_i` onto it (the consolidation the plan-quality judge
  flagged), so the `completeopt` typeahead dance lives in one place.
- Tests: `tests/unit/spell_spec.lua` (10 cases) + `tests/integration/spell_chat_spec.lua`
  (8 cases — attach option wiring, autocmd/`<CR>`-map presence, prompt-buf skip,
  live `spellsuggest` popup via an in-insert-mode `<F2>` trigger). Test-writing
  finding: the live popup must be inspected *inside* the insert-mode callback —
  `feedkeys`' `"x"` flag appends an `<Esc>` that tears the menu down on return.
- `make test` GREEN: 0 lint warnings/errors across 221 files, all specs pass
  (incl. `vision_spec.lua` after the refactor).

## Revisions

### 2026-06-20 — FIX-THEN-SHIP boundary-review fix (Important + minors)

The close-time fresh-context review returned **FIX-THEN-SHIP** on one Important
cross-feature finding, fixed before ship:

- **Important — spell `<CR>` map shadowed interview-mode timestamps.** `spell.attach`
  installs a *buffer-local* insert `<CR>` map on every chat buffer; interview mode
  uses a *global* insert `<CR>` map to insert `:NNmin` timestamps. Buffer-local
  beats global, so the spell map silently broke interview timestamps in chat
  buffers (both default-on). **Fix:** extracted `interview.cr_keys()` (the shared
  interview-aware `<CR>` base), gave `spell.cr_keys` a `base` arg, and threaded an
  injected `base_cr` through `attach` (init wires it to `interview.cr_keys`) so the
  buffer-local map *subsumes* interview's behavior instead of clobbering it. Decoupled
  (DI at the init boundary; spell.lua never requires interview). Regression tests
  added (unit `cr_keys` base cases; integration "base_cr honored when no popup").
- **Minor — `complete_noselect` completeopt restore** now pcall-guarded (two callers depend on it).
- **Minor — asymmetric `enable`/`typeahead` gating** documented with a comment.
- Side-quest: removed two stray `print("DEBUG: …")` calls in `interview.setup_keymap`
  that fired on every insert-mode `<CR>` (touched while extracting `cr_keys`).
- Deferred (noted, not blocking): `word_at_cursor` `[%a']` is ASCII-only (fine for
  en_us default; flagged for future i18n).
- `make test` GREEN after fix; spell specs now 13 unit + 10 integration.
