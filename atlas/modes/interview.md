# Interview Mode

- `<C-n>i`: enter (no-op if active); `<C-n>I`: exit (no-op if inactive)
- `:ParleyToggleInterview`: toggle (backward compat)
- `:00min` marker on start; `:NNmin` auto-inserted on Enter in insert mode (elapsed since start)
- Resume: `<C-n>i` on existing timestamp resumes timer from that point
- Lualine: flashing timer display
- `InterviewTimestamp` highlight group on timestamp lines
- `InterviewThought` highlight group on `{thought text}` blocks (linked to `DiagnosticInfo`)
- Globally overrides Enter key in insert mode when active
