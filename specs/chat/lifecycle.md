# Spec: Chat Lifecycle

## Overview
The chat lifecycle includes creation, sending questions, receiving responses, resubmission, and deletion.

## Creation
### Command: `:ParleyChatNew` (Global Shortcut: `<C-g>c`)
- Generates a new `.md` file in the primary `chat_dir` with a `YYYY-MM-DD` timestamp.
- Writes the default template, substituting: filename, model/provider headers, and initial system prompt.
- Opens the file in a Neovim buffer and moves the cursor to the first question area.

### Multi-Root Discovery
- Chat-aware discovery features MAY scan multiple configured chat roots.
- When `chat_dirs` is configured, Chat Finder MUST include matching chat files from every configured root.
- New chat creation MUST still use only the primary `chat_dir`.

### Command: `:ParleyChatMove`
- Moves the current chat file to another registered chat root.
- The destination MUST already be present in the normalized chat-root list.
- Moving a chat MUST keep the current filename and update any open chat buffer to the new path.

## Response Generation
### Command: `:ParleyChatRespond` (Buffer Shortcut: `<C-g><C-g>`)
- Validates that the buffer is a valid chat file.
- Identifies the current question based on cursor position.
- Assembles conversation history, applying memory summarization if enabled.
- Sends the request to the configured LLM provider via `curl`.
- Streams the response directly into the buffer beneath the answer prefix.
- When web search is enabled, shows a temporary animated in-buffer spinner indicator until first streamed answer text (or exit).

### Command: `:ParleyToggleFollowCursor` (Buffer Shortcut: `<C-g>l`)
- Toggles whether cursor/view follows the active streamed insertion point.
- When toggled on during an active response, cursor MUST jump to the current insertion location and continue following.
- When toggled off, streaming continues but cursor/view MUST stop auto-following.
- When a followed response finishes, completion-time buffer edits (for example appending the next prompt) MUST NOT move the cursor past the final streamed response text.

### Concurrent Process Guard
- Subsequent `:ParleyChatRespond` calls are ignored if a response is running.
- Force a new response with `:ParleyChatRespond!`.

## Resubmitting Questions
### Command: `:ParleyChatRespondAll` (Buffer Shortcut: `<C-g>G`)
- Sequential resubmission of all questions from the beginning up to the cursor position.
- Existing answers are replaced in order.
- Can be terminated at any time with `:ParleyStop` (`<C-g>s`).

## Deletion
### Command: `:ParleyChatDelete` (Buffer Shortcut: `<C-g>d`)
- Deletes the current chat file from disk.
- If `chat_confirm_delete` is `true`, a confirmation prompt MUST be shown.
- Associated memory and cached metrics for the chat are purged.
