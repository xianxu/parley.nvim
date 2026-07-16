# Issue #81: Tree of Chat

## Status: COMPLETE

## Plan

- [x] **1.1 Keybinding: `<C-g>i` to insert new chat reference** — In chat buffer: change "create and insert new chat" from `<C-g>n` → `<C-g>i` (restoring `<C-g>n` for its intended "search chat sections" role). In markdown buffer: add `<C-g>i` as "create and insert new chat reference". Update keybindings help text.

- [x] **1. Syntax + Highlighting** — New `🌿: filename.md: topic` prefix for all chat-to-chat links inside chat buffers. First transcript line = parent back-link; anywhere in body = child branch. `🌿:` lines excluded from LLM context and preserved across answer regeneration (like `🔒:`). New highlight group `ParleyChatReference`. Extend `<C-g>o` to open `🌿:` lines. Update `<C-g>i` in chat buffer to insert `🌿:` lines. `@@path@@` remains for non-chat file/URL refs.

- [x] **2. Parent Link Parsing** — First transcript line `🌿: filename.md: topic` = back-link to parent. Parse to know ancestry chain.

- [x] **2.1 Auto-insert parent back-link** — When `<C-g>o` on a `🌿:` line creates a new child chat file, insert `🌿: parent_path: parent_topic` as the first transcript line (after header `---`). Only on new file creation, not when opening existing files.

- [x] **3. Context Assembly** — When submitting from a child chat: walk ancestor chain, include each ancestor's exchanges up to the branch point, append current chat's exchanges. Full depth (unlimited).

- [x] **3.1 Keybinding: `<C-g>s` for system prompt** — Change default system prompt keybinding from `<C-g>p` → `<C-g>s`. Stop moved from `<C-g>s` → `<C-g>x`.

- [x] **4. Prune Operation (`<C-g>p`)** — Move cursored exchange + all following into a new child chat file. Insert `🌿:chat-file: topic` at cursor in parent. Auto-write parent link in new child's first transcript line.

- [x] **5. LLM Topic Regeneration** — After pruning, call LLM to generate a topic from pruned content and set it in the new child's front matter.

- [x] **5.1 Topic generation spinner** — While topic is being generated, animate the `?` in `topic: ?` with a spinner (reuse SSE spinner frames). Replace with final topic when done.

- [x] **6. Outline: Branch Awareness** — Show `🌿: topic` references as navigable items in outline. `<CR>` or click on a child 🌿 entry opens that file's outline (recursive expand) inside current chat file's outline, with one indention. `<CR>` or click on outline item inside children or grand children's outline, jump to that corresponding question in that corresponding file. Note, outline when opened on a child, or grand child file, would display the full outline of the whole tree, but expanded for current file

- [x] **7. Delete: Single File Only** — `ParleyChatDelete` deletes only the current file. Dangling `@@` refs in parent/siblings left as-is (intentional).

- [x] **8. Move: Whole Tree** — `ParleyChatMove` moves the entire tree that the current file is a part of, to the new location.

- [x] **9. Audit of Other Affected Systems** — Review and update: memory/summarization (preserve `@@child@@` refs like other `@@` refs), export (tree-aware?), chat finder (show parent/child relationships?), `RespondAll` (recurse into children?).

## Design Decisions

- `🌿: filename.md: topic` is the universal chat-link prefix inside chat buffers (parent back-link if first transcript line, child branch otherwise)
- `@@path@@` remains for non-chat file/URL refs in both chat and markdown buffers
- Position disambiguates direction: first transcript line = parent, body = child branch
- `🌿:` lines: excluded from LLM context, preserved during answer regeneration, answer block ends before them
- Context assembly: at each ancestor level, include exchanges older than the branch point to current path (B-tree ancestry model)
- Delete leaves dangling refs intentionally; Move takes whole subtree

## Review

### Files Changed
- `lua/parley/config.lua` — added `chat_branch_prefix`, `chat_shortcut_prune`; changed stop→`<C-g>x`, system_prompt→`<C-g>s`
- `lua/parley/chat_parser.lua` — `🌿:` branch detection, `parent_link`/`branches` fields, `first_question_seen` flag
- `lua/parley/chat_respond.lua` — `build_ancestor_messages`, `collect_ancestor_chain`, `generate_topic` (extracted+reusable), `find_topic_line`, ancestor context injection in `respond()`
- `lua/parley/highlighter.lua` — `ParleyChatReference` highlight group, `render_chat_branch_line` (with `⚠️` for dangling refs), `highlight_chat_branch_refs` debounced timer
- `lua/parley/init.lua` — `<C-g>i` branch ref insertion, `<C-g>o` for `🌿:` lines (with parent back-link), `ChatPrune` command, `move_chat_tree`, `find_tree_root_file`, `collect_tree_files`, keybinding changes
- `lua/parley/outline.lua` — tree-aware outline with `find_tree_root`, `build_file_outline_items`, `_build_tree_outline_items`, cross-file navigation, same-window `edit`
- `lua/parley/chat_dirs.lua` — `cmd_chat_move` uses `move_chat_tree`
- `tests/unit/ancestor_messages_spec.lua` — 8 tests for `build_ancestor_messages`
- `tests/unit/parse_chat_spec.lua` — 6 tests for `🌿:` branch parsing
- `specs/chat/format.md`, `specs/chat/lifecycle.md`, `specs/chat/parsing.md`, `specs/ui/outline.md`, `specs/ui/keybindings.md`, `specs/ui/highlights.md`, `specs/index.md` — updated

### Bugs Fixed During Implementation
- `~` path expansion in ancestor context assembly and branch path resolution
- Empty content messages causing Anthropic `cache_control` errors
- Outline cursor-outside-buffer errors (bounds clamping, use current buf for highlights)
- Outline cross-file navigation using `split` instead of `edit`
- `🌿:` not recognized by `is_outline_item` causing cursor snap to next question
- `highlight_chat_branch_refs` not triggered after `<C-g>i` insertion

### Test Results
All existing + new tests pass (0 failures, 0 errors).
