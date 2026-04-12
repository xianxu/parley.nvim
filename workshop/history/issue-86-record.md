# Issue #86: Editable System Prompts + Standardize Picker Keybindings

## Standardized Picker Action Keys

| Action | Key | Chat Finder | Note Finder | Chat Roots | System Prompt | Agent |
|--------|-----|-------------|-------------|------------|---------------|-------|
| **Select** | `<CR>` | open chat | open note | select root | select prompt | select agent |
| **Delete** | `<C-d>` | delete chat | delete note | remove root | delete/restore | — |
| **New** | `<C-n>` | — | — | add root | new prompt | — |
| **Rename** | `<C-r>` | — | — | rename label | rename prompt | — |
| **Edit** | `<C-e>` | — | — | — | edit text | — |
| **Move** | `<C-x>` | move to root *(was `<C-r>`)* | — | — | — | — |
| **Recency left** | `<C-a>` | cycle left | cycle left | — | — | — |
| **Recency right** | `<C-s>` | cycle right | cycle right | — | — | — |
| **Help** | `<C-g>?` | keybindings | keybindings | keybindings | keybindings | keybindings |

Notes:
- `<C-g>?` is picker-scoped: it should be available in ALL float picker instances, not just chat/note finder
- `—` means the action is not applicable for that picker

## Design

### Storage
- Custom/edited system prompts stored in `{state_dir}/custom_system_prompts.json`
- Format: `{ "prompt_name": { "system_prompt": "...", "source": "custom" }, ... }`
- Built-in prompts come from `config.lua` defaults + user setup opts (existing behavior)
- Custom file overrides built-in prompts with same name

### Data Model
- `M._builtin_system_prompts` — snapshot of prompts after config merge (read-only reference)
- `M.system_prompts` — active prompts = builtins merged with custom overrides (existing field)
- Each prompt gets a `source` tag: `"builtin"`, `"custom"`, or `"modified"` (builtin with user edits)

### System Prompt Picker Actions
- `<CR>`: Select prompt (existing)
- `<C-e>`: Edit — opens selected prompt in scratch buffer for editing
- `<C-d>`: Delete custom prompt / restore modified builtin to default / no-op for pure builtins
- `<C-n>`: New — prompt for name, create blank custom prompt, open in edit buffer
- `<C-r>`: Rename — prompt for new name (custom prompts only)

### Edit Buffer
- Opens as a scratch buffer with prompt name in title
- Buffer-local `BufWriteCmd` saves content back to custom_system_prompts.json
- Filetype set to `markdown` for reasonable editing UX

## Tasks

### Part A: Standardize picker keybindings ✅
- [x] A1. Chat Finder: change move key from `<C-r>` to `<C-x>`
- [x] A2. Update chat finder config default (`chat_finder_mappings.move`)
- [x] A3. Add `<C-g>?` keybindings help to all pickers (chat roots, system prompt, agent, outline x2)
- [x] A4. Update specs (`specs/ui/pickers.md` standardized key table, `specs/infra/config.md`)
- [x] A5. Update keybindings help display (`init.lua`)
- [x] A6. Run tests — all pass, lint clean

### Part B: Editable system prompts — persistence ✅
- [x] B1. Add `load_custom_prompts()` / `save_custom_prompts()` in new module `lua/parley/custom_prompts.lua`
- [x] B2. Track builtin vs custom source during setup merge; snapshot builtins in `M._builtin_system_prompts`
- [x] B3. Load custom prompts during setup, merge over builtins into `M.system_prompts`

### Part C: Editable system prompts — edit buffer ✅
- [x] C1. Implement edit buffer: open prompt text in scratch buffer, `BufWriteCmd` saves to custom file
- [x] C2. On save, update `M.system_prompts` in-place and refresh picker/state via `refresh_prompts()`

### Part D: Editable system prompts — picker actions ✅
- [x] D1. Add `<C-e>` (edit), `<C-d>` (delete/restore), `<C-n>` (new), `<C-r>` (rename) to system prompt picker
- [x] D2. Show source indicators (`[custom]`/`[modified]`) in picker display; builtins have no tag

### Part E: Specs & tests ✅
- [x] E1. Update `specs/ui/pickers.md` with standardized action key table
- [x] E2. Create `specs/providers/system_prompts.md` for editable prompts; added to `specs/index.md`
- [x] E3. Tests for custom prompt persistence (10 tests: load/save/get/set/remove/rename)
- [x] E4. Tests for source detection (4 tests) and picker source display (1 test)
