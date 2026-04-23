---
id: 000111
status: open
deps: [110]
created: 2026-04-22
updated: 2026-04-22
---

# Decompose init.lua

init.lua is 4736 lines with ~20 logical sections. After #110 extracts the keybinding
system (~450 lines), extract other self-contained sections to reduce init.lua to ~3000 lines.

## Done when

- init.lua is under 3500 lines
- Extracted modules are cohesive and have clear interfaces
- All tests pass, no behavioral changes

## Candidates (ordered by independence)

1. **Code/context copying** (lines 3973-4126) → `lua/parley/copy.lua`
   - Fully self-contained: CopyCodeFence, CopyLocation, CopyContext
   - ~150 lines, zero coupling

2. **Chat path resolution** (lines 2595-2850) → `lua/parley/chat_path.lua`
   - Slug rename, path candidates, resolve_chat_path, parse_branch_ref
   - ~250 lines, depends on config + chat_slug + file_tracker

3. **Chat tree operations** (lines 2896-3112) → `lua/parley/chat_tree.lua`
   - find_tree_root, collect_tree_files, delete_tree, move_tree
   - ~220 lines, depends on chat_path + float_picker

4. **File reference handling** (lines 3738-3975) → `lua/parley/file_reference.lua`
   - open_chat_reference, try_open_src_link, inline branch links
   - ~240 lines, depends on chat_path + open_buf

5. **Agent info resolution** (lines 4508-4734) → `lua/parley/agent_info.lua`
   - get_agent_info with header merging, memory prefs, prompt appending
   - ~230 lines, depends on system_prompts + state

## Plan

- [ ] Extract in order above, one at a time
- [ ] Tests pass after each extraction
- [ ] Update atlas/ when done

## Log

### 2026-04-22

- Created from init.lua structural analysis during #110 planning
- Identified 5 extraction candidates totaling ~1100 lines
