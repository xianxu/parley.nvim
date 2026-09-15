# Spec: Outline Navigation

## Command
- `:ParleyOutline` (`<M-t>` / `<C-g>t`): floating picker for document navigation

## Scope
- **Chat files**: tree-aware outline with questions, branches, annotations; Markdown headings in answers are deliberately excluded
- **Other `.md` files**: flat outline including `#`, `##`, `###` headings

## Logic
- Identifies `💬:` user questions, `@@…@@` annotations, and `🌿:` branch references; `#`/`##`/`###` headings are included only in non-chat Markdown
- **One item rule** (#232): both builders — the indexed live candidate query and the
  tree's per-file extractor — classify lines through `is_outline_item`; the
  tree adds only its `📋` root row, the branch rows it takes from the parser
  (a child's upward parent link is therefore never a row), and indentation.
  `tests/unit/outline_parity_spec.lua` is the differential oracle. An
  standalone annotation displays as `  → text` (both delimiters stripped).
  A whole-line `@@label@@` immediately above a question becomes that question's
  outline label and search text, retaining its question-row destination.
  A blank line breaks adjacency. `@@_@@` always hides its own annotation row;
  immediately above a question it hides that question from the outline too.
  These attached tags are the exchange's preface: their raw text still prefixes
  the following user message in AI context, including `@@_@@`. Fenced lookalikes
  do not attach. The shared rule lives in `question_tags.lua`.
- Headings indented by level: `#` → 2sp, `##` → 4sp, `###` → 6sp
- Lines inside code blocks (``` / ~~~) are excluded — but a `💬:`/`🤖:` turn
  marker at column zero ENDS an open fence (#218), so an unmatched fence in one
  answer no longer drops every later question from the outline. Live candidates use the document index
  and disk materialization uses the shared grammar. Both receive patterns from
  the live configuration, including custom question prefixes.
- Document order (ascending line number)

## Tree-Aware Outline (Chat Files)
- Walks parent chain to root; builds unified outline across linked files
- Root topic shown as `📋 topic` at top
- Multiple inline branches on one source line appear left to right, each followed by its expanded child subtree. Standalone and inline branch rows retain their existing indentation and child-file destinations.
- All branches expanded by default; 2-space indentation per depth level
- Selecting `🌿` opens the referenced child file at line 1 (standalone, inline, and nested branches); missing files show a warning without creating an empty buffer
- Selecting child-file item opens file in same window and jumps to line
- Opening the outline with the cursor on a preface selects its labelled question; Enter lands on the question line

## Interaction
- Standard `float_picker` (results + prompt), fuzzy filter with highlights
- Single click selects; double-click/`<CR>` confirms with highlight flash
- Cross-file nav uses `edit` (same window), not split

## Implementation and checks

`lua/parley/outline.lua` owns classification, tree building, and navigation.
`tests/unit/outline_spec.lua` verifies child-file navigation and missing-file
handling; `tests/unit/outline_parity_spec.lua` keeps flat/tree classification aligned.

## Live query bounds

The current buffer uses document summary searches with at most eight candidates
per page and at most 4096 bytes per label read. Picker loading advances through
scheduled pages and resolves selection through a stable current handle. Closing
the picker or detaching its document retires outstanding work. Explicit cross-file
tree materialization remains a user-command operation over disk snapshots.
