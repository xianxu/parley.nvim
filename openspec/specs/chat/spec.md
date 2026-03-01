# Spec: Chat

## Overview

The chat feature is the primary function of parley.nvim. It treats a Markdown file as a structured conversation between a user and an LLM assistant. Each chat is a plain `.md` file stored in a configured directory, with conventions for marking turns, metadata, and special content.

---

## Chat File Format

### File Location and Naming

- Chat files MUST be stored in the configured `chat_dir`.
- Chat filenames MUST begin with a timestamp prefix in the format `YYYY-MM-DD`. The full filename format observed in code is a datetime-based stamp followed by `.md`.
- Files not located in `chat_dir` or lacking the timestamp prefix MUST NOT be treated as chat files by the plugin.

### File Header Section

Every chat file MUST contain a header section before the first `---` separator. The header MUST include at minimum:

1. A topic line as the first line, starting with `# ` (e.g., `# topic: My research topic`).
2. A `- file: <filename>` line within the first 10 lines.

The header MAY also contain:

| Field | Example | Description |
|---|---|---|
| `- model: ...` | `- model: {"model":"gpt-4o","temperature":1.1}` | Model name (string) or JSON object with parameters |
| `- provider: ...` | `- provider: openai` | Provider name |
| `- role: ...` | `- role: You are a helpful assistant.` | System prompt (newlines escaped as `\n`) |
| `- tags: ...` | `- tags: research code` | Space-separated tags |
| `- max_full_exchanges: N` | `- max_full_exchanges: 10` | Per-chat override for memory configuration |
| `- raw_mode.show_raw_response: true` | | Per-chat raw mode flag |
| `- raw_mode.parse_raw_request: true` | | Per-chat raw request mode flag |

The header section ends at the first line beginning with `---`.

> **NOTE:** The exact set of per-chat header overrides accepted is not exhaustively documented. The code parses `- key: value` lines and stores them as `config_<key>`. Which config keys are acted upon beyond `max_full_exchanges` and raw mode flags is not fully specified.

### Conversation Turns

After the `---` separator, the file contains alternating user and assistant turns.

#### User Turn (Question)

- A question MUST begin with a line starting with the configured `chat_user_prefix` (default: `💬:`).
- All lines following a question prefix, until the next assistant prefix or end of file, are considered part of that question.

#### Assistant Turn (Answer)

- An answer MUST begin with a line starting with the configured `chat_assistant_prefix` first element (default: `🤖:`).
- The assistant prefix line MAY include an agent identifier suffix in the form `[AgentName]` (rendered via the `{{agent}}` template).
- All lines following an assistant prefix, until the next user prefix or end of file, are considered part of that answer.

#### Special Lines Within an Answer

Two special single-line prefixes MAY appear within answers:

| Prefix | Default | Purpose |
|---|---|---|
| `🧠:` | configurable via `chat_memory.reasoning_prefix` | Reasoning/thinking output from the LLM |
| `📝:` | configurable via `chat_memory.summary_prefix` | Summary of the exchange for memory management |

Both lines MUST be single plaintext lines (no embedded newlines). They are visually dimmed by default and excluded from subsequent LLM context when memory summarization is active.

#### Local Section

- A line starting with the configured `chat_local_prefix` (default: `🔒:`) begins a local section.
- Content in local sections is excluded from the context sent to the LLM.
- A local section ends when the next user or assistant prefix is encountered.

### File Validity Check

The plugin uses the following criteria to determine whether a buffer is a valid chat file:

1. The resolved file path MUST start with the resolved `chat_dir`.
2. The filename MUST match the timestamp prefix pattern `YYYY-MM-DD`.
3. The buffer MUST contain at least 5 lines.
4. The first line MUST start with `# `.
5. A `- file: ` line MUST appear within the first 10 lines.

If any check fails, chat-specific commands and keybindings are not activated for that buffer.

---

## Creating a New Chat

### Command

`:GpChatNew` (default shortcut: `<C-g>c` globally)

**Given** the user invokes the new chat command,
**When** the command executes,
**Then** the plugin MUST:
1. Generate a new `.md` file in `chat_dir` with a timestamp-based filename.
2. Write the chat template to the file, substituting: filename, model/provider headers, system prompt, and configured shortcut keys.
3. Open the file in a Neovim buffer.
4. Move the cursor to the end of the buffer (position for first question).

### Chat Template

Two templates are available:

- `chat_template` (full) — includes help text with shortcut reminders.
- `short_chat_template` (default) — minimal header only.

Both templates produce:
```
# topic: ?
- file: <filename>
[optional model/provider/role headers]
---

💬:
```

The topic line defaults to `# topic: ?` and SHOULD be edited by the user.

### Autosave

> **NOTE:** The README states chats are "saved automatically." No explicit autosave mechanism (e.g., a `BufWritePost` autocmd or timer) was identified in the code. The save mechanism is undocumented at the code level.

---

## Requesting a Response

### Command

`:GpChatRespond` (or `:ParleyChatRespond`)
Default shortcut: `<C-g><C-g>` (normal, insert, visual, and visual-block modes)

**Given** the user's cursor is in a valid chat buffer,
**When** the respond command is invoked,
**Then** the plugin MUST:
1. Validate that the buffer is a valid chat file.
2. Identify the current question based on cursor position.
3. Assemble the conversation history as messages, applying memory summarization if enabled.
4. Send the request to the configured LLM provider via `curl` (streaming).
5. Stream the response into the buffer beneath the current question's answer prefix.

### Cursor Position Determines Scope

- If the cursor is inside a **question** in the middle of the transcript, the plugin MUST resubmit that question and replace its existing answer.
- If the cursor is on or after the **last** question (no answer yet), the plugin MUST append a new answer.
- The previously existing answer for a resubmitted question MUST be replaced, not appended.

### Concurrent Process Guard

- If a response is already being generated for the buffer, a subsequent `ChatRespond` invocation MUST be silently ignored (logs a warning).
- Appending `!` to the command (`:ParleyChatRespond!`) MUST bypass the guard and force a new response.

### Stopping a Response

`:GpStop` (default shortcut: `<C-g>s`)

**When** invoked during an active response,
**Then** the plugin MUST terminate all running LLM response processes.

### Resubmit All Questions

`:ParleyChatRespondAll` (default shortcut: `<C-g>G`)

**When** invoked from within a question,
**Then** the plugin MUST resubmit all questions from the beginning of the transcript up to and including the cursor's question, in sequence. Each question's answer is replaced as the sequence progresses.

A visual indicator MUST highlight each question being processed. The user MAY stop the resubmission at any time via the stop shortcut.

---

## Context and Memory Management

### Overview

When `chat_memory.enable` is `true` (default), the plugin limits how many full exchanges are sent to the LLM. Older exchanges beyond `max_full_exchanges` are replaced in the API payload by their summary lines (`📝:`).

### Preservation Rules

An exchange (question + answer) MUST be preserved in full (not summarized) if ANY of the following are true:

1. It is the current question being processed.
2. It is within the last `max_full_exchanges` exchanges in the transcript.
3. It contains one or more `@@`-prefixed file reference lines in the question.

### Summarization Substitution

When an exchange is summarized:

- The user message content is replaced with the configured `omit_user_text` (default: `"Summarize our chat"`).
- The assistant message content is replaced with the content of the `📝:` summary line from that answer, if present.

> **NOTE:** If an older exchange has no `📝:` summary line, the behavior when summarizing it is not explicitly documented.

### Per-Chat Override

The `max_full_exchanges` setting MAY be overridden per file by including `- max_full_exchanges: N` in the chat header. When present, the header value MUST take precedence over the global config value.

---

## File References In Questions

### Syntax

Within a question, a line beginning with `@@` followed by a path causes the plugin to load that file's content and include it in the message sent to the LLM.

Supported forms:

| Syntax | Behavior |
|---|---|
| `@@/path/to/file.txt` | Include a single file |
| `@@/path/to/dir/` | Include all files in a directory (non-recursive) |
| `@@/path/to/dir/*.lua` | Include all matching files in a directory (non-recursive) |
| `@@/path/to/dir/**/` | Include all files recursively |
| `@@/path/to/dir/**/*.lua` | Include all matching files recursively |

Included files are displayed with line numbers in the content sent to the LLM.

### Opening Referenced Files

With the cursor on a `@@`-prefixed line, pressing `<C-g>o` (default) MUST open the referenced file or directory.

- For files: opens the file in the buffer.
- For directories or glob patterns: opens the file explorer.

> **NOTE:** Which file explorer is opened for directories is not specified in the README. The code resolves and opens the path directly; behavior for directories may vary by environment.

### Memory Preservation

Exchanges containing `@@` file references MUST be preserved in full regardless of their position relative to `max_full_exchanges`.

---

## Visual Highlighting

When a valid chat buffer is entered or modified, the plugin MUST apply syntax highlighting with the following highlight groups:

| Content | Highlight Group | Default Link |
|---|---|---|
| Lines in a question block | `ParleyQuestion` / `Question` | `Keyword` |
| `@@`-prefixed file reference lines | `ParleyFileReference` / `FileLoading` | `WarningMsg` |
| `🧠:` and `📝:` lines | `ParleyThinking` / `Think` | `Comment` |
| `@...@` inline annotations | `ParleyAnnotation` / `Annotation` | `DiffAdd` |
| `@@tag@@` closed tag patterns | `ParleyTag` / `Tag` | `Todo` |

Highlighting MUST refresh on `BufEnter`, `WinEnter`, `TextChanged`, and `TextChangedI` events.

Model parameters in the header MUST be concealed (replaced with `…`) when `chat_conceal_model_params` is `true` (default).

---

## Agent Selection

### Current Agent Display

When a valid chat buffer is entered, the current agent MUST be displayed as virtual text right-aligned on the first line in the format `Current Agent: [AgentName]`.

For Anthropic agents with web search enabled, the display appends `[w]`: `Current Agent: [AgentName[w]]`.

### Switching Agents

`:ParleyAgent` or `:GpNextAgent` (default shortcut: `<C-g>a`)

- If Telescope is available: MUST open a Telescope picker listing available agents.
- If Telescope is not available: cycles to the next available agent.

Agent selection is persisted to disk in `state_dir` and restored across Neovim sessions.

---

## Chat Finder

`:ParleyChatFinder` (default shortcut: `<C-g>f`)

Opens a floating window to search, preview, and open chat files.

### Default Behavior

- By default, shows only files modified within the last `chat_finder_recency.months` months (default: 6).
- Files are sorted by modification date, newest first.
- Each entry displays the filename, topic, and modification date.

### Toggle All

Pressing the configured `toggle_all` key (default: `<C-a>`) inside the finder MUST switch between showing recent files and all files. The dialog title MUST update to reflect the current filtering state.

### Deletion

Pressing the configured `delete` key (default: `<C-d>`) inside the finder MUST delete the selected chat file.

### Chat Deletion Command

`:GpChatDelete` (default shortcut: `<C-g>d`)

Deletes the current chat file. When `chat_confirm_delete` is `true` (default), MUST prompt for confirmation before deleting.

---

## Outline Navigation

`:ParleyOutline` (default shortcut: `<C-g>t` in chat buffers)

**Given** the user is in a valid chat buffer,
**When** the outline command is invoked,
**Then** the plugin MUST open a Telescope picker listing questions and Markdown headings in the file for navigation.

> **NOTE:** Behavior when Telescope is not available is not documented.

---

## Code Block Utilities

The following keybindings are available within chat buffers for working with fenced Markdown code blocks:

| Shortcut | Action |
|---|---|
| `<leader>gy` | Copy code block under cursor to clipboard |
| `<leader>gs` | Save code block to file (prompts for filename, or uses `file="..."` attribute) |
| `<leader>gx` | Execute code block in a split terminal window |
| `<leader>gc` | Copy terminal output to clipboard (from terminal buffer) |
| `<leader>ge` | Copy terminal output from the last terminal session (from chat buffer) |
| `<leader>gd` | Diff code block against a previous version of the same file in the chat |
| `<leader>g!` | Repeat the last set of commands run via `<leader>gx` |

---

## Export

### Export to HTML

`:ParleyExportHTML [dir]`

Exports the current chat buffer as a self-contained HTML file with inline styling. The output filename is derived from the topic line. If a directory argument is provided, it MUST override the configured `export_html_dir`.

### Export to Markdown (Jekyll)

`:ParleyExportMarkdown [dir]`

Exports the current chat buffer as a Jekyll-compatible Markdown file with front matter. Front matter includes `title`, `date`, `tags`, `layout`, and `comments` fields.

- `title` is extracted from the `# topic:` header line.
- `date` is extracted from the `- file:` header filename (timestamp prefix), falling back to the current filename, then to today's date.
- `tags` are extracted from a `- tags:` header line, defaulting to `"unclassified"`.

---

## System Prompt Selection

Default shortcut: `<C-g>p` (in chat buffers)

**When** invoked, MUST open a picker (Telescope if available) to select from configured named system prompts. The selected prompt becomes active for new responses in the session.

---

## Search Within Chat

Default shortcut: `<C-g>n` (in chat buffers)

**When** invoked, searches the buffer for lines beginning with either the user prefix (`💬:`) or the assistant prefix (`🤖:`), enabling quick navigation between turns.

---

## Notes and Ambiguities

- **Autosave**: The README states chats are "saved automatically," but no autosave code was identified. The save mechanism is undocumented at the code level.
- **Minimum Neovim version**: Not stated anywhere in the README, docs, or code.
- **Telescope requirement**: Several features (agent picker, outline, system prompt picker, template picker) require Telescope. Fallback behavior when Telescope is absent is only partially documented (agent switching only).
- **Legacy user prefix**: The code recognizes a legacy user prefix `🗨:` in addition to the current `💬:`. This backward compatibility behavior is not documented in the README.
- **`chat_free_cursor`**: When `true` (default), the cursor does not move to the end of the buffer after a response completes. Precise cursor behavior across all scenarios is not fully specified.
- **Web search toggle**: The `claude_web_search` state is per-session and defaults to the global config value. A toggle mechanism exists in the code but is not documented in the README.
