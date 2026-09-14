# Interview Mode

Interview mode adds elapsed-time markers while taking notes. `<C-n>i` enters
(or resumes from the `:NNmin` line under the cursor); `<C-n>I` exits.
`:ParleyToggleInterview` toggles the state. Entering an already-active mode or
exiting an inactive mode is a no-op.

A new interview starts with `:00min`. In Insert mode, Enter adds a new timestamped
paragraph using elapsed minutes. This Enter mapping is global while interview
mode is active, so it also affects other buffers; exit restores the previous
global Enter mapping. Parley's spell-completion mapping preserves interview
insertion when it is not accepting a completion.

Lualine shows a flashing timer. Timestamp lines use `InterviewTimestamp`;
`{thought text}` uses `InterviewThought`, linked to `DiagnosticInfo`.

## Implementation and verification

`lua/parley/interview.lua` owns entering, resuming, timer state, `cr_keys`, and
mapping restoration. `lua/parley/keybinding_registry.lua` owns the configurable
entry/exit shortcuts. Existing checks include `tests/unit/spell_spec.lua`,
`tests/unit/keybindings_spec.lua`, and the lualine cases in
`tests/unit/super_repo_spec.lua`.
