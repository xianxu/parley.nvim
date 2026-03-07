# Spec: Interview Mode

## Overview
Interview mode provides automatic timestamping and a timer for live interview recording.

## Toggle Command
- `:ParleyToggleInterview` (`<C-n>i`): Toggles interview mode in the current session.

## Timestamp Logic
- `:00min`: Initial timestamp marker inserted on toggle or in a template.
- `:NNmin`: Automatically inserted when `Enter` is pressed in insert mode.
- Calculation: Elapsed time since `interview_start_time`.

## Resuming
- If toggled while the cursor is on an existing timestamp, the timer MUST resume from that point.

## UI Integration
- **Lualine**: Flashing timer shows the current elapsed time.
- **Highlights**: `InterviewTimestamp` group highlights the entire line.
- **Keymaps**: Globally overrides the `Enter` key in insert mode when active.
