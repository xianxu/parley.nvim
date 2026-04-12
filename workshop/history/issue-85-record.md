# Issue #85: Inline Branch Links

## Plan

### 1. Parser: detect inline `[🌿:...](...)` links
- [x] In `chat_parser.parse_chat`, scan lines for `[🌿:display](path)` patterns
- [x] Add each match to `parsed.branches` with `{ path, topic, line, after_exchange, inline }`
- [x] Context unpacking: strip `[🌿:text](file)` → `text` when building exchange content
- [x] Pure functions: `extract_inline_branch_links`, `unpack_inline_branch_links`
- [x] Unit tests: 8 tests covering extraction, unpacking, parser integration

### 2. Visual-select `<C-g>i` keybinding
- [x] Detect visual selection; if present, use inline link workflow instead of full-line
- [x] Replace selected text with `[🌿:selected text](new-file.md)`
- [x] Create child chat file with topic `what is "selected text"`, parent link, and question
- [x] Normal-mode `<C-g>i` behavior unchanged (full-line link)
- [ ] Integration tests: visual select creates inline link and child file (requires manual testing)

### 3. Navigation: `<C-g>o` on inline links
- [x] Extend `OpenFileUnderCursor` to detect cursor within `[🌿:...](...)` span
- [x] Reuses pure `extract_inline_branch_links` for detection (DRY)
- [x] Creates child file from template if it doesn't exist yet (same as full-line links)

### 4. In-buffer display
- [x] Add `ParleyInlineBranch` highlight group (underlined, links to Special)
- [x] Add `ParleyInlineBranchConceal` for concealed markup parts
- [x] Extmark-based concealing: hides `[🌿:` prefix and `](path)`, shows display text styled
- [x] Integrated into `highlight_chat_branch_refs` refresh cycle

### 5. Export: inline links in HTML and Markdown
- [x] In `process_branch_lines`, detect inline `[🌿:...](...)` within non-branch lines
- [x] Replace with `<a href="..." class="branch-inline">text</a>` using link_map
- [x] Add `.branch-inline` CSS in both HTML and Markdown exports
- [x] Unit tests: 3 tests covering HTML, markdown, and missing-target fallback

### 6. Tree discovery integration
- [x] Parser adds inline links to `branches` → `collect_tree` picks them up automatically
- [x] `build_link_map` and collision detection include inline links (no changes needed)

### 7. Update specs
- [x] Created `specs/chat/inline_branch_links.md`
- [x] Updated `specs/chat/format.md` with inline link syntax
- [x] Updated `specs/index.md`

## Review
All tasks complete. 15 new unit tests, all passing. Full test suite green.
Visual-select `<C-g>i` and `<C-g>o` navigation need manual testing.
