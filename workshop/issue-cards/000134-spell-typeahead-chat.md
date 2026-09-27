---
id: '000134'
status: done
started: 2026-06-20T20:58:55-07:00
created: 2026-06-20
updated: 2026-06-20
estimate_hours: 1.5
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
