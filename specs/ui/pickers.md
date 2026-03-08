# Spec: UI Pickers

## Overview
Parley integrates with Telescope to provide searchable pickers for agent selection, system prompts, and chat files.

## Agent Picker
- `:ParleyAgent`: Opens a Telescope picker with agent names, providers, and models.
- If Telescope is absent, the command MUST cycle to the next available agent.

## System Prompt Picker
- `:ParleySystemPrompt`: Opens a Telescope picker with named system prompts.
- Selected prompts MUST be reflected in subsequent LLM requests.

## Chat Finder
- `:ParleyChatFinder` (`<C-g>f`): Search, preview, and open chat files.
- **Recency Filter**: By default, shows files from the last `chat_finder_recency.months`.
- **Mappings**:
    - `<C-a>`: Toggle between recent and all files.
    - `<C-d>`: Delete the selected chat file.
    - `<C-g>?`: Open Parley key bindings help from within the finder.
    - Files are sorted by modification date, newest first.

## Navigation Picker
- `:ParleySearchChat` (`<C-g>n`): Searches the current chat for lines beginning with user or assistant prefixes.
- Enables quick jumps between conversation turns.
