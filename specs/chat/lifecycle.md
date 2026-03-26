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
- Chat Finder MUST continue discovering chats from configured roots whose paths contain glob metacharacters.
- New chat creation MUST still use only the primary `chat_dir`.

### Command: `:ParleyChatMove`
- Moves the **entire chat tree** (root + all descendants linked via `🌿:`) to another registered chat root.
- The destination MUST already be present in the normalized chat-root list.
- Moving a chat MUST keep filenames and update any open chat buffers to the new paths.
- All `🌿:` references within moved files MUST be rewritten to reflect the new locations.

### Pruning: `<C-g>p`
- Moves the exchange under the cursor and all following exchanges into a new child chat file.
- Inserts a `🌿: child_path: ` reference at the cursor position in the parent.
- Copies the parent's header (patching `topic: ?` and `file:`) and inserts a parent back-link (`🌿: parent: topic`) as the first transcript line in the child.
- Triggers async LLM topic generation from the pruned exchanges; updates child header and parent `🌿:` line on completion.
- A spinner animates the `topic: ?` line while topic generation is in progress.

## Response Generation
### Command: `:ParleyChatRespond` (Buffer Shortcut: `<C-g><C-g>`)
- Validates that the buffer is a valid chat file.
- Identifies the current question based on cursor position.
- Assembles conversation history, applying memory summarization if enabled.
- Sends the request to the configured LLM provider via `curl`.
- Streams the response directly into the buffer beneath the answer prefix.
- When web search is enabled, shows a temporary animated in-buffer spinner/progress indicator while the response is active.
- Streamed answer text MUST render beneath that temporary progress line so provider progress can remain visible for the full response.
- The temporary progress line MUST be removed when the response completes or exits.

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
- Can be terminated at any time with `:ParleyStop` (`<C-g>x`).

## Context Assembly (Tree of Chat)
- When submitting from a child chat (one that has a `🌿:` parent back-link), ancestor context is injected.
- The system walks the parent chain to the root, collecting Q+A exchanges at each level up to the branch point.
- Ancestor messages are inserted after the system prompt and before the current chat's messages.
- Summaries are used in place of full answers when available.

## Deletion
### Command: `:ParleyChatDelete` (Buffer Shortcut: `<C-g>d`)
- Deletes only the current chat file from disk (does NOT delete child branches).
- Dangling `🌿:` references in parent/sibling files are left as-is; they display `⚠️` via the auto-render cycle.
- If `chat_confirm_delete` is `true`, a confirmation prompt MUST be shown.
- Associated memory and cached metrics for the chat are purged.
