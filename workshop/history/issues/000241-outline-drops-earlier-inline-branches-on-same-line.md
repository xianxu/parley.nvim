---
id: 000241
status: done
deps: []
github_issue:
created: 2026-09-12
updated: 2026-09-14
estimate_hours: 0.3075
started: 2026-09-14T18:16:23-07:00
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

- [x] Extend `tests/unit/outline_parity_spec.lua` with synthetic real-file sibling chats; exercise `_build_tree_outline_items` for multiple same-line inline branches and mixed line-form/single-inline branches, parser order, subtree interleaving, collapsed and independently expanded children. Observe the same-line cases fail before changing production code.
- [x] In `build_file_outline_items` (`lua/parley/outline.lua`), group parser branches into ordered arrays by source line and emit every entry using the existing row/resolver path. Keep recursion, expansion, cycle guard and child-file selection unchanged. Update `atlas/ui/outline.md` with same-line ordering.
- [x] Run `make test-spec SPEC=ui/outline`, lint and diff checks; existing #250 real-buffer selection tests defend child-file landing. Commit and close through the fresh SDLC review, then open a PR.


## Log


- 2026-09-14: closed — All 185 tests in five ui/outline specs pass; four same-line regressions RED then GREEN, mixed branch parity and existing child-file navigation pass; lint451 files clean; diff check clean.; review verdict: SHIP
### 2026-09-12

- Filed from the brain advisor session. Reproduced by running
  `chat_parser.extract_inline_branch_links` and `parse_chat` headless on the
  operator's line: 2 links, 2 branches, both `line=8`. The loss is entirely
  in `outline.lua:255-268`.

## Revisions

### 2026-09-14 — Preserve shipped child navigation

Reason: #250 shipped after this issue was filed and intentionally changed branch selection to open the child file at line1. Delta: supersede the optional source-column propagation and second-link landing acceptance criterion with preserving that child destination. The former plan's third checkbox (carry col through parser/picker) is removed from active scope; no parser or selection changes are needed. The remaining purpose is still every parsed branch row and each distinct child subtree, in document/column order.

The three-file fix uses the existing `build_file_outline_items` IO boundary, with an ordered-list grouping local to that invocation; no new public function or separate business rule. ARCH-DRY: parser order and the existing row renderer remain authoritative. ARCH-PURE/MOCK: exercise real parser/files and tree builder without mocking filesystem or resolver. ARCH-PURPOSE: all branches survive, with independent expansion; unchanged global visited semantics still prevent cyclic recursion. ARCH-CONSTRAINTS: O(branches + lines + existing recursion), no additional file reads per branch. ARCH-ORDER: synchronous file projection has no pending operation state; arrays preserve parser order. ARCH-SECURE: existing path resolver is reused. ARCH-FUNERAL: arrays die with the build; synthetic fixture files are removed in teardown.

## Estimate

After plan approval: known local grouping fix, existing real-file test harness and no new public API. Design baseline0.25h ×0.2 =0.05h; implementation/tests/docs baseline0.375h ×0.4 =0.15h; one boundary review baseline0.25h ×0.4 =0.1h.15% design buffer adds0.0075h. No parallel-overlap discount.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: lua-neovim design=0.05 impl=0.15
item: milestone-review design=0 impl=0.1
design-buffer: 0.15
total: 0.3075
```

### 2026-09-14 — Implementation and verification

Plan-quality CLEAN in one round; estimate-quality INFO (small budget relies on reuse; review allowance includes close/PR bookkeeping). Real-file regressions: all four same-line cases failed before the fix, while all four mixed standalone/inline cases passed. After ordered-array grouping, all eight cases pass, including exact source/child attribution, left-to-right order and interleaved child questions/annotations under independent expansion states. Existing #250 navigation tests still pass. `make test-spec SPEC=ui/outline` and `make lint` passed (451 files, zero warnings/errors); `git diff --check` clean. No parser or navigation change. Unrelated local prompt/chat edits preserved.

Fresh review: SHIP, no findings. Reviewer independently verified190 passing tests and repeated the base/head regression check in an isolated archive. Correction to the close command's evidence count: the five specs contain190 tests, not185; the complete suite was run in both checks.
