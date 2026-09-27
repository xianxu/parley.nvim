---
id: '000120'
status: done
created: 2026-05-06
updated: 2026-05-06
actual_hours: 3.5
---

# update to branching mode

## Problem

`<C-g>i` insert a branch point at the current selection or cursor, so that we can for discussion into a side. 

Somewhat related, `<C-g>v` is designed for review: `<C-g>vi` will insert 🤖[] at cursor to allow human to feedback on a piece of text. it follows the convention of turn structure 🤖[]{}[]{}, alternating between human and machine.Both parley and ariadne (through /fix skill) supports such syntax. 

After using coding agent for a while, I think there are benefit of the linear transcript, but allowing easy reference to follow up question is useful, thus the following improved design.
