# Issue #83: Tree Export for Chat Trees

## Plan

### 1. Extract shared export helpers
- [x] Refactor filename generation (date + sanitized topic) into a shared helper in `exporter.lua`
- [x] Refactor header parsing (title, date, tags extraction) into a reusable function

### 2. Implement tree discovery
- [x] Add `find_tree_root(file_path)` — walk up parent links to find the root
- [x] Add `collect_tree_files(root_path)` — recursively collect all files in the tree
- [x] Handle edge cases: missing files, circular references

### 3. Implement navigation link rendering
- [x] Parent link → `← Back to: <topic>` with format-specific link
- [x] Child branch links → `→ Branch: <topic>` with format-specific link
- [x] HTML: relative `<a href="...">` links
- [x] Jekyll Markdown: `{% post_url slug %}` syntax

### 4. Wire tree export into existing commands
- [x] `export_html`: discover tree, export all files, convert `🌿:` to HTML links
- [x] `export_markdown`: discover tree, export all files, convert `🌿:` to Jekyll links
- [x] Single-file fallback when no tree links exist (existing behavior unchanged)
- [x] Print summary: number of files exported, any skipped files

### 5. Tests
- [x] Unit test: `find_tree_root` walks up parent links correctly
- [x] Unit test: `collect_tree_files` gathers full tree, handles missing files and cycles
- [x] Unit test: navigation link rendering for both HTML and Jekyll formats
- [x] Integration test: export a small tree (root + 2 children), verify all files created with correct links
- [x] Integration test: single-file export unchanged when no tree links

### 6. Update specs
- [x] Update `specs/export/formats.md` to reference tree export behavior
- [x] Verify `specs/export/tree_export.md` matches implementation

## Review
All tasks complete. 26 new tests (21 unit + 5 integration), all passing. Full test suite green.
