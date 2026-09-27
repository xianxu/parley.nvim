---
id: '000190'
status: done
started: 2026-07-15T12:00:53-07:00
created: 2026-07-15
updated: 2026-07-15
estimate_hours: 2.75
actual_hours: 4.81
---

# persist repo super-repo state across nvim sessions

## Problem

Repo mode is derived from the current `.parley` repository, but super-repo mode
is a transient overlay. A user who prefers peer aggregation for one repository
must re-enable it in every Neovim session. Brain repositories currently receive
a separate automatic super-repo rule, so startup behavior depends on repository
type rather than the user's explicit choice.

The mode toggle also uses `<C-g>S`, while the desired mnemonic is `<C-g>p` for
“peer.” That key is currently used by chat pruning, and the agreed replacement
`<C-g>b` is currently used by the optional tool-fold toggle.
