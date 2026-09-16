---
id: 000259
status: open
deps: []
github_issue:
created: 2026-09-15
updated: 2026-09-15
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

Compare the interaction and defaults with Pair’s draft Neovim implementation.
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
- Defaults and documentation clearly state whether automatic typeahead is on;
  users can disable it without disabling visible spell underlines.
- Focused unit/integration tests cover menu sizing, source precedence,
  accept/dismiss behavior, buffer vocabulary, and chat submission safety.
- The release smoke path confirms the interaction matches the useful Pair draft
  behavior and avoids the oversized shipped menu.

## Plan

- [ ] Audit Parley’s current `spell.lua`/completion flow against Pair’s draft
  spell popup and identify which behavior is missing or incorrectly defaulted.
- [ ] Design the shared completion-source and precedence contract, including
  bounded display and `<CR>`/dismiss behavior.
- [ ] Implement the release defaults and buffer-vocabulary completion behind the
  existing completion seam; update atlas/user documentation.
- [ ] Add focused unit/integration coverage and run release smoke verification.

## Log

### 2026-09-15

Filed for Parley release quality from operator comparison with Pair’s draft
Neovim pane. The desired interaction is a small numbered completion popup for
misspellings plus completion from words already in the buffer; the current
released spell menu is too large/noisy and Parley’s typeahead is opt-in.
