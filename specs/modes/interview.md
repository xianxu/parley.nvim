# Spec: Interview Mode

## Overview
Interview mode provides automatic timestamping and a timer for live interview recording.

## Commands & Keybindings
- `<C-n>i`: Enter interview mode (no-op if already active).
- `<C-n>I`: Exit interview mode (no-op if not active).
- `:ParleyToggleInterview`: Toggles interview mode (preserved for backward compatibility).

## Timestamp Logic
- `:00min`: Initial timestamp marker inserted on toggle or in a template.
- `:NNmin`: Automatically inserted when `Enter` is pressed in insert mode.
- Calculation: Elapsed time since `interview_start_time`.

## Resuming
- If `<C-n>i` (enter) is pressed while the cursor is on an existing timestamp, the timer MUST resume from that point.

## UI Integration
- **Lualine**: Flashing timer shows the current elapsed time.
- **Highlights**: `InterviewTimestamp` group highlights the entire line.
- **Keymaps**: Globally overrides the `Enter` key in insert mode when active.
