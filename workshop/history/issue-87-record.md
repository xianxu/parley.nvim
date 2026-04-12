# Issue #87: Split Interview Mode Enter/Exit Keybindings

## Tasks
- [x] Split `interview.toggle()` into `interview.enter()` and `interview.exit()` in `lua/parley/interview.lua`
- [x] Keep `toggle()` as backward-compat wrapper delegating to enter/exit
- [x] Add `EnterInterview` and `ExitInterview` commands in `lua/parley/init.lua`
- [x] Map `<C-n>i` to enter, `<C-n>I` to exit in global keymaps
- [x] Update help display to show both keybindings
- [x] Update `specs/modes/interview.md` with new commands section
- [x] Update `specs/ui/keybindings.md` with enter/exit keys
- [x] Run tests — all pass
- [x] Run lint — clean (pre-existing warning in outline.lua)

## Review
- `enter()` is no-op if already active, `exit()` is no-op if not active
- Timestamp-resume logic preserved in `enter()` path
- No behavioral changes to existing `ToggleInterview` command
