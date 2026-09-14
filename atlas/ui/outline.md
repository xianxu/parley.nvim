# Spec: Outline Navigation

## Command
- `:ParleyOutline` (`<M-t>` / `<C-g>t`): floating picker for document navigation

## Scope
- **Chat files**: tree-aware outline with questions, branches, annotations; Markdown headings in answers are deliberately excluded
- **Other `.md` files**: flat outline including `#`, `##`, `###` headings

## Logic
- Identifies `💬:` user questions, `@@…@@` annotations, and `🌿:` branch references; `#`/`##`/`###` headings are included only in non-chat Markdown
- **One item rule** (#232): both builders — the flat buffer scan and the
  tree's per-file extractor — classify lines through `is_outline_item`; the
  tree adds only its `📋` root row, the branch rows it takes from the parser
  (a child's upward parent link is therefore never a row), and indentation.
  `tests/unit/outline_parity_spec.lua` is the differential oracle. An
  annotation displays as `  → text` (both `@@` delimiters stripped), at the
  same level as the questions of its file.
- Headings indented by level: `#` → 2sp, `##` → 4sp, `###` → 6sp
- Lines inside code blocks (``` / ~~~) are excluded — but a `💬:`/`🤖:` turn
  marker at column zero ENDS an open fence (#218), so an unmatched fence in one
  answer no longer drops every later question from the outline. All three
  outline scans share `highlight_structure.code_block_memo`; it must be given
  patterns from the live config, or a custom `chat_user_prefix` silently loses
  containment.
- Document order (ascending line number)

## Tree-Aware Outline (Chat Files)
- Walks parent chain to root; builds unified outline across linked files
- Root topic shown as `📋 topic` at top
- All branches expanded by default; 2-space indentation per depth level
- Selecting `🌿` opens the referenced child file at line 1 (standalone, inline, and nested branches); missing files show a warning without creating an empty buffer
- Selecting child-file item opens file in same window and jumps to line

## Interaction
- Standard `float_picker` (results + prompt), fuzzy filter with highlights
- Single click selects; double-click/`<CR>` confirms with highlight flash
- Cross-file nav uses `edit` (same window), not split

## Implementation and checks

`lua/parley/outline.lua` owns classification, tree building, and navigation.
`tests/unit/outline_spec.lua` verifies child-file navigation and missing-file
handling; `tests/unit/outline_parity_spec.lua` keeps flat/tree classification aligned.
