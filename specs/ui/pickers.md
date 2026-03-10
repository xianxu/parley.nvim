# Spec: UI Pickers

## Overview
Parley uses a custom floating window picker (`float_picker`) for all selection UIs.
No external dependencies (Telescope or similar) are required.

## Mouse Interaction
All pickers support mouse interaction:
- **Single click**: moves cursor/selection to the clicked item (picker stays open).
- **Double-click**: confirms the selected item and closes the picker.

## Agent Picker
- `:ParleyAgent`: Opens a floating picker with agent names, providers, and models.
- The current agent is marked with `✓` and sorted to the top.

## System Prompt Picker
- `:ParleySystemPrompt`: Opens a floating picker with named system prompts.
- Selected prompts MUST be reflected in subsequent LLM requests.

## Chat Finder
- `:ParleyChatFinder` (`<C-g>f`): Browse and open chat files in a floating picker.
- **Recency Filter**: By default, shows files from the last `chat_finder_recency.months`.
- **Mappings**:
    - Toggle key (`<C-g>a` by default): Toggle between recent and all files.
    - Delete key (`<C-d>` by default): Delete the selected chat file.
    - `<C-g>?`: Open Parley key bindings help from within the finder.
    - Files are sorted by modification date, newest first.
- Use native `/` to search within the displayed list.

## Navigation Picker
- `:ParleySearchChat` (`<C-g>n`): Searches the current chat for lines beginning with user or assistant prefixes.
- Enables quick jumps between conversation turns.
