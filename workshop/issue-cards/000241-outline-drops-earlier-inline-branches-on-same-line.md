---
id: '000241'
status: done
started: 2026-09-14T18:16:23-07:00
created: 2026-09-12
updated: 2026-09-14
estimate_hours: 0.3075
actual_hours: 0.09
---

# Chat outline shows only the last inline branch on a line: the tree builder keys branches by line number, so a second [🌿:…](…) on the same line overwrites the first

## Problem

Operator report, 2026-09-12, with screenshots. An answer line carrying two
inline branch links:

    … **[🌿:setting up the MeLE, connecting through the Mango, and then integrating equipment control](2026-09-12.19-36-16.695_….md)**. We can also build a [🌿:pre-shoot checklist ](2026-09-12.18-48-52.334_pre-shoot-checklist.md)so the …

The Chat Tree Outline shows one branch row under that exchange —
`🌿 pre-shoot checklist`, with its child's items — and nothing for the first
link. The first child chat exists and is reachable by other means; it is
simply absent from the outline.

Root cause, reproduced headless with the exact line:

- The parser is correct. `extract_inline_branch_links` walks the line with
  `search_start = e + 1` and returns both links in column order;
  `parse_chat` records both as branches, both with `line = 8`,
  `inline = true`, distinct topics and paths.
- The tree builder is not. `outline.lua:255-257`:

  ```lua
  local branch_at_line = {}
  for _, branch in ipairs(parsed.branches) do
    branch_at_line[branch.line] = branch
  end
  ```

  One slot per line number. The second link on a line overwrites the first,
  and the consumer at `:268` (`local branch = branch_at_line[i]`) emits one
  row and one child recursion (`:355`) for whatever survived — always the
  last link on the line.

Not the inline-vs-line-form distinction #214 fixed (BR-75/BR-79); those made
inline links *survive* a resubmit. This is the outline never having modelled
more than one branch per line — a map where a list was needed.
