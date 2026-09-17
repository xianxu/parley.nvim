---
id: 000259
status: open
deps: []
github_issue:
created: 2026-09-15
updated: 2026-09-16
estimate_hours:
---

# Ship compact spell and buffer completion in Parley

## Problem

Parley’s released chat experience does not provide the compact, always-nearby
completion flow that makes misspellings easy to correct. The shipped spell-check
menu is oversized and noisy. The operator’s configured Parley menu is somewhat
better, while Pair’s draft Neovim pane has the preferred behavior: a normal
completion popup appears as the word is typed, with numbered suggestions that
are easy to select. The draft also completes words already present in the
buffer, even when they are not in the spell dictionary.

Parley already has a `spell.lua` typeahead implementation ported from Pair, but
the feature is currently opt-in and its scope is narrower than the draft
completion experience.

## Spec

Make spelling assistance a compact completion feature suitable for a Parley
release. Reuse the existing completion popup and spell seams rather than adding
a second picker or coupling the feature to WhichKey. Preserve ordinary chat
editing, submission and other completion sources.

The design should cover two complementary sources:

- spelling suggestions for a misspelled word, with a bounded menu and simple
  accept/dismiss behavior;
- words already available in the current chat buffer, so useful project or
  conversation vocabulary can be completed even when it is absent from the
  dictionary.

Each source has its own trigger length, and they differ:

- **buffer words → 2 typed characters.** More eager than the draft’s
  `WORD_TRIGGER_MIN = 1` (which fires on the first letter) and far quicker
  than the spell threshold. Keep candidates prefix-anchored and bounded so the
  menu stays quiet.
- **spell suggestions → 4 typed characters**, matching Pair’s draft
  (`SPELL_TRIGGER_MIN = 4`) and Parley’s current `spell.lua` defaults
  (`min_word = 4`, `max_suggest = 9`). `spell.lua`’s `min_word` is uniform
  today, so it has to become per-source.

Pair’s draft Neovim pane (`pair/nvim/init.lua`) is the explicit reference to
audit against rather than a loose comparison: `word_complete` for the buffer
source, `spell_complete` for the spell source, including its
`completeopt=noselect` and its `spell_popup_active` vs. as-you-type
distinction.

Decide whether the typeahead should be enabled by default for released Parley
chat buffers, and keep an explicit escape hatch for users who do not want
automatic suggestions. Avoid a huge menu, stealing `<CR>`, or hiding the
normal chat submission path.

## Done when

- A released Parley chat buffer offers a compact, bounded completion popup for
  misspellings without requiring a separate WhichKey-style picker.
- Suggestions can be accepted, dismissed, or ignored while preserving normal
  newline/submission behavior, including interview mode and prompt buffers.
- Words from the current buffer can be completed even when absent from the
  spell dictionary, with deterministic precedence when spell and buffer sources
  overlap.
- Buffer-word completions appear after 2 typed characters and spell
  suggestions after 4, with the two thresholds independently configurable.
- Defaults and documentation clearly state whether automatic typeahead is on;
  users can disable it without disabling visible spell underlines.
- Focused unit/integration tests cover menu sizing, source precedence,
  per-source trigger lengths (2 vs. 4), accept/dismiss behavior, buffer
  vocabulary, and chat submission safety.
- The release smoke path confirms the interaction matches the useful Pair draft
  behavior and avoids the oversized shipped menu.

## Plan

- [ ] Audit Parley’s current `spell.lua`/completion flow against Pair’s draft
  spell popup and identify which behavior is missing or incorrectly defaulted.
- [ ] Design the shared completion-source and precedence contract, including
  bounded display and `<CR>`/dismiss behavior.
- [ ] Implement per-source thresholds (a `min_word` per source in `spell.lua`
  or a dedicated buffer-word source), the release defaults and
  buffer-vocabulary completion behind the existing completion seam; update
  atlas/user documentation.
- [ ] Add focused unit/integration coverage and run release smoke verification.

## Revisions

### 2026-09-16 — per-source trigger lengths pinned

- **Reason:** operator, clarifying the desired interaction: “if words appeared
  in the chat itself, we start that completion with 2 characters. the spelling
  check auto completion, I’d check what’s current behavior in pair’s nvim draft
  pane, it seems to work well.”
- **Delta:** the Spec already named both sources but left their trigger
  lengths open. Pinned them per source — buffer words at 2 typed characters,
  spell at 4 — and promoted Pair’s draft (`pair/nvim/init.lua`:
  `WORD_TRIGGER_MIN = 1`, `SPELL_TRIGGER_MIN = 4`, `SPELL_MAX_SUGGEST = 9`)
  from a loose comparison to the reference to audit against. Noted that
  `spell.lua`’s single `min_word` must become per-source. Folded in from
  `brain#000016`, which had been filed as a separate refinement issue; no
  separate Parley issue was opened for it.

## Log

### 2026-09-15

Filed for Parley release quality from operator comparison with Pair’s draft
Neovim pane. The desired interaction is a small numbered completion popup for
misspellings plus completion from words already in the buffer; the current
released spell menu is too large/noisy and Parley’s typeahead is opt-in.
