# Spec: Outline Navigation

## Command
- `:ParleyOutline` (`<C-g>t`): floating picker with headings and conversation turns

## Scope
- **Chat files**: tree-aware outline with questions, branches, annotations
- **Any `.md` file**: flat outline of `#`, `##`, `###` headings

## Logic
- Identifies: `💬:` (user questions), `#`/`##`/`###` (headings), `@@…@@` (annotations), `🌿:` (branch refs)
- Headings indented by level: `#` → 2sp, `##` → 4sp, `###` → 6sp
- Lines inside code blocks (``` / ~~~) are excluded
- Document order (ascending line number)

## Tree-Aware Outline (Chat Files)
- Walks parent chain to root; builds unified outline across linked files
- Root topic shown as `📋 topic` at top
- All branches expanded by default; 2-space indentation per depth level
- Selecting `🌿` jumps to that line in parent file
- Selecting child-file item opens file in same window and jumps to line

## Interaction
- Standard `float_picker` (results + prompt), fuzzy filter with highlights
- Single click selects; double-click/`<CR>` confirms with highlight flash
- Cross-file nav uses `edit` (same window), not split
