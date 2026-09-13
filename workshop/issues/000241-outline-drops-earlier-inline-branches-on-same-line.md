---
id: 000241
status: open
deps: []
github_issue:
created: 2026-09-12
updated: 2026-09-12
estimate_hours:
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

## Spec

- `branch_at_line[line]` becomes a **list**, in the parser's order (which is
  column order — the extractor advances left to right). The consumer emits
  one branch row per entry and recurses into each child, so both subtrees
  appear under the exchange, first link first. The row shape is unchanged.
- **Optional, cheap, worth doing while here:** the extractor already returns
  `col_start`/`col_end` and the parser drops them when it builds the branch
  record. Carry `col` through so the outline's Enter can land on the specific
  link rather than the line start — with two links on one line, "jump to
  line 8" is ambiguous in a way it was not before.
- No change to the flat builder (chats always use the tree; the flat rule
  matches only line-start `🌿:` rows) and none to the parser.

## Done when

- A line with N inline branch links yields N branch rows in the tree outline,
  in column order, each with its child subtree.
- Line-form `🌿:` rows and single inline links render exactly as today
  (extend `outline_parity_spec.lua`).
- Unit test on `_build_tree_outline_items` with a fixture chat carrying two
  links on one line, plus one with a line-form branch and an inline link at
  different lines of the same exchange.
- If `col` is carried: Enter on the second row places the cursor on the
  second link.

## Plan

- [ ] `branch_at_line` → list per line; loop the consumer; tests on a two-link fixture
- [ ] Parity test for the unchanged cases
- [ ] Carry `col` from the extractor into the branch record and the row's `value`; picker jump uses it when present

## Log

### 2026-09-12

- Filed from the brain advisor session. Reproduced by running
  `chat_parser.extract_inline_branch_links` and `parse_chat` headless on the
  operator's line: 2 links, 2 branches, both `line=8`. The loss is entirely
  in `outline.lua:255-268`.
