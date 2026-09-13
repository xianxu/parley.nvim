---
id: 000232
status: working
deps: []
github_issue:
created: 2026-09-10
updated: 2026-09-12
estimate_hours: 1.45
started: 2026-09-12T19:44:52-07:00
---

# chat outline drops @@ annotations because the tree builder has its own item rule

## Problem

A line that is entirely `@@text@@` is meant to add a manual navigation entry to the
outline. **In a chat it never appears.** The operator added
`@@plan for 9/10/2026@@` (line 85 of
`workshop/parley/2026-09-09.11-40-59.150_astrophotography-plan.md`) and the outline
(`<M-t>`) does not show it.

The line itself is correct: no stray whitespace, and it does not start with a
path prefix, so it is not mistaken for a file injection (`extract_file_refs` only
injects refs starting with `https://`, `/`, `~/`, `./`, or `../`).

### Two builders, two definitions of "outline item"

`outline.lua` has two ways of building the list:

- **Flat** — `_build_picker_items` calls `is_outline_item` on every line, which
  recognises questions, `@@…@@` annotations, `🌿:` branches, and (outside chats)
  markdown headings.
- **Tree** — `_build_tree_outline_items`, used for **every chat file**. Its per-file
  extractor takes branches from `chat_parser.parse_chat` and recognises question
  lines itself. It **never calls `is_outline_item`**, so annotations are invisible
  to it.

For a chat, the picker (`outline.lua`, the chat branch of `question_picker`) builds
the tree and only falls back to the flat builder when the tree returns **zero**
items:

```lua
local items = M._build_tree_outline_items(root, config, expanded_set)
if #items == 0 then
  items = M._build_picker_items(current_bufnr, config, { is_chat = true })
end
```

Any chat with a question produces a non-empty tree, so the flat builder — the only
one that knows annotations — never runs for chats in practice.

### Measured on the operator's file

| builder | line 85 `@@plan for 9/10/2026@@` |
|---|---|
| flat, `is_chat = true` | present — `85  annotation → @plan for 9/10/2026@` |
| tree | **absent** — 25 items (root title, questions, branches), `annotation present: false` |

### Consequence

In a chat there is currently **no way** to add a manual outline entry. Headings are
excluded from chat outlines by design (`if not opts.is_chat`), and annotations are
dropped by the tree builder. The feature works only in plain (non-chat) markdown
files — the opposite of where a long, branching research chat most needs it.

### Minor, same area

`is_outline_item` displays an annotation as `"→ " .. string.sub(line, 2, -2)`, which
strips **one** `@` from each end: `@@my note@@` lists as `→ @my note@`. Should be
`3, -3`.

## Spec

**One definition of an outline item, used by both builders.** The tree builder's
per-file extractor classifies each line through
`is_outline_item(…, { is_chat = true })` instead of detecting questions itself. The
tree keeps what is genuinely its own — the `📋` root title, branch recursion and
indentation, expand/collapse — and takes *which lines are items* from the shared rule
(`ARCH-DRY`).

That gives chats annotations now, and means any future item type added to
`is_outline_item` reaches both outlines rather than one.

Keep `is_outline_item`'s existing skips (code-block lines, and headings in chats), so
chat outlines stay otherwise unchanged.

Fix the one-`@` display slice while here.

## Done when

- `@@plan for 9/10/2026@@` appears in the tree outline of the operator's file, at its
  position among the questions and branches.
- A test builds **both** outlines for the same chat fixture and asserts they agree on
  which lines are items, differing only in the tree's root and nesting. It fails
  against today's code on the annotation line — so the two builders cannot drift
  apart again.
- An annotation inside a nested (branched) chat file appears under that branch in
  the tree.
- `@@my note@@` displays as `→ my note`.
- Chat outlines are otherwise unchanged: no headings in chats, code-block lines still
  skipped.

## Estimate

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec design=0.4 impl=0.04
item: lua-neovim design=0.2 impl=0.3
item: atlas-docs design=0.1 impl=0.05
item: milestone-review design=0.1 impl=0.14
design-buffer: 0.15
total: 1.45
```

*Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against
`baseline-v3.1.md`. Method A only.* `sdlc estimate-source` flags that doc as
stale (#127), so the per-primitive hours are provisional.

How each item was picked, from the v2 table's ranges: design ×0.2 where the
plan already resolves the decisions (v2 Step 3), `impl=` at 40% of the v2/v2.1
range (v3.1), design buffer 0.15 because the ×0.2 discount applies to the code
primitive (v2.1 halves the buffer then). Familiarity 1.0: the outline module
and its #218 tests were read end to end before planning.

- `issue-spec` — the spec itself predates the claim (written 2026-09-10,
  outside the measured window); inside the window are the plan rewrite and
  three plan-gate rounds — below the 0.5–1.5 design range's low end, so 0.4;
  impl at the 0.1–0.3 ×0.4 floor.
- `lua-neovim` — one focused change: route `build_file_outline_items` through
  `is_outline_item`, fix the slice, two describes of tests. Design at the ×0.2
  floor of 1–3 (the plan carries the exact call); impl low in the 0.2–0.6
  scaled range because the change is a dozen lines plus tests.
- `atlas-docs` — one sentence in `atlas/ui/outline.md`.
- `milestone-review` — the single close boundary; 0.2–0.5 impl ×0.4 = 0.14.

## Plan

Single-pass atomic work (one module, one spec, one atlas line) — plain
checkboxes, one `sdlc close`.

Test strategy (cases live in `tests/unit/picker_items_spec.lua`, beside the
#218 tree-outline describe; red first):
- `_build_picker_items` vs `_build_tree_outline_items` — **normalized
  differential parity** over a chat mixing every line class the shared rule
  knows (question, annotation, branch, fenced content, trailing empty prompt)
  and over one level of nesting: the tree minus its root row must equal the
  flat list on `(lnum, type, display)`, and a nested file's items must appear
  under its branch row, indented once. Adversarial inputs go in the spec, not
  here.
- `_is_outline_item` — **direct classifier assertions** over annotation
  delimiters (display text, and what is and is not an annotation).

- [ ] Parity + nesting tests over the two builders (red on today's tree builder).
- [ ] Classifier tests over annotation delimiters (red on today's slice).
- [ ] Route `build_file_outline_items` through `is_outline_item(nil, i, config,
      code_memo, file_lines, { is_chat = true })` for every non-branch line:
      display = `indent .. formatted_line`, `type = item_type`, value
      `{ lnum = i, file = abs_path }`. Delete its private `user_prefix` match
      (`ARCH-DRY`: one item rule). The trailing-empty-question drop stays as
      is. Branch rows stay exactly as they are (they come from
      `parsed.branches`, which the shared rule does not know).
- [ ] Fix the display slice (`3, -3`).
- [ ] Atlas: `atlas/ui/outline.md` Logic section — one sentence: both builders
      classify lines through `is_outline_item`; the tree adds root, branch rows
      and indentation only.
- [ ] Verify on the operator's file
      (`workshop/parley/2026-09-09.11-40-59.150_astrophotography-plan.md`):
      `<M-t>` shows `→ plan for 9/10/2026` at its position. Record in `## Log`.

## Log`.

## Log

### 2026-09-10

Operator reported an `@@…@@` line not appearing in a chat outline. Checked the line
for whitespace and path prefixes, then ran both builders on the actual file rather
than reading the code: the flat builder finds the annotation, the tree builder does
not, and chats always use the tree. The cause is a second, hand-rolled item rule
living beside `is_outline_item`.

Earlier in the session the operator had been told `@@…@@` was *the* way to add
outline entries in chats. That came from reading `is_outline_item` without checking
which builder chats actually use, and it is wrong until this lands.
