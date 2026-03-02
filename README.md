<!-- panvimdoc-ignore-start -->

<a href="https://github.com/xianxu/parley.nvim/blob/main/LICENSE"><img alt="GitHub" src="https://img.shields.io/github/license/xianxu/parley.nvim"></a>

# Parley.nvim - Streamlined LLM Chat Plugin for Neovim

<!-- panvimdoc-ignore-end -->

<br>

**Multi-provider LLM chat sessions with highlighting and navigation, focused on simplicity and readability.**

# Goals and Features

Parley is a streamlined LLM chat plugin for Neovim, focusing on providing a clean and efficient interface for conversations with AI assistants. It supports multiple providers including OpenAI, Anthropic (Claude), Google (Gemini), and Ollama. Imagine having a full transcript of a chat session that allows editing of all questions and answers! I created this as a way to construct research reports and improve my understanding of new topics. It's a researcher's notebook.

Beyond chat, Parley includes utilities for note-taking organized by week/day, interview mode with automatic timestamps, and export to blog formats.

- **Multi-provider support**
  - OpenAI (GPT-4, GPT-4o, GPT-5), Anthropic (Claude Sonnet, Claude Haiku), Google (Gemini 2.5 Pro/Flash), Ollama (local models)
  - Any OpenAI-compatible endpoint (Azure, LM Studio, etc.)
  - Switch between agents on the fly with Telescope picker
- **Streamlined chat experience**
  - Markdown-formatted chat transcripts with syntax highlighting
  - Question/response highlighting with custom colors
  - Navigate chat Q&A exchanges using outline navigator
  - Easy keybindings for creating and managing chats
- **Streaming responses**
  - No spinner wheel and waiting for the full answer
  - Response generation can be canceled halfway through
  - Properly working undo (response can be undone with a single `u`)
- **Minimum dependencies** (`neovim`, `curl`; optional: `telescope`)
  - Zero dependencies on other Lua plugins to minimize chance of breakage
- **Chat sessions as files**
  - Just good old Neovim buffers formatted as markdown with autosave
  - Chat finder - management pop-up for searching, previewing, deleting and opening chat sessions
- **A live document**
  - Refresh answers on any questions
  - Insert questions in the middle of the transcript and expand with assistant's answers
  - Referencing local files and directories for context (the `@@` syntax)
  - Resubmit all questions from the beginning to update the entire transcript
- **Interview mode**
  - Auto-inserted timestamps for interview tracking
  - Flashing timer in statusline showing elapsed time
- **Note-taking**
  - Weekly/daily organized notes with templates
- **Export**
  - Export to Jekyll blog post format with front matter. [Example](https://xianxu.github.io/2025/05/12/conversation_around_concurrent_programming_models.html).
  - Export to Markdown format

# The Format of the Transcript

Each chat transcript is a markdown file with some additional conventions. Think of them as markdown files with benefits.

1. There is a header section that contains metadata and can override configuration parameters:
   - Standard metadata like `file: filename.md` (required)
   - Model information like `model: {"model":"gpt-4o","temperature":1.1,"top_p":1}`
   - Provider information like `provider: openai`
   - Configuration overrides like `max_full_exchanges: 20` to customize behavior for this specific chat
   - Raw mode settings like `raw_mode.show_raw_response: true` to display raw JSON responses
2. User's questions and assistant's answers take turns.
3. A question is a line starting with 💬:, and all following lines until the next answer.
4. An answer is a line starting with 🤖:, and all following lines until the next question.
5. Two special lines in answers (maintained by Parley, grayed out by default):
    1. The assistant's reasoning output, prefixed with 🧠:.
    2. The summary of one chat exchange prefixed with 📝:, in the format of "you asked ..., I answered ...".
    3. We keep those in the transcript itself for simplicity, so that one transcript file is self-contained.
6. Smart memory management:
    1. By default, Parley keeps only a certain number of recent exchanges (controlled by `max_full_exchanges`, default: 5) and summarizes older ones to maintain context within token limits.
    2. Exchanges that include file references (@@filename) are always preserved in full, regardless of their age.
7. File and directory inclusion: a line that starts with @@ followed by a path will automatically load content into the prompt when sending to the LLM:

   - `@@/path/to/file.txt` - Include a single file
   - `@@/path/to/directory/` - Include all files in a directory (non-recursive)
   - `@@/path/to/directory/*.lua` - Include all matching files in a directory (non-recursive)
   - `@@/path/to/directory/**/` - Include all files in a directory and its subdirectories (recursive)
   - `@@/path/to/directory/**/*.lua` - Include all matching files in a directory and its subdirectories (recursive)

   All included files are displayed with line numbers for easier reference. You can open referenced files or directories directly by placing the cursor on the @@ line and pressing `<C-g>o`.

## Interaction

Place cursor in the question area and press `<C-g><C-g>` to ask the assistant. If the question is at the end of the document, it's a new question. Otherwise, a previously asked question is re-asked and the previous answer is replaced.

If you see a message saying "Another Parley process is already running", you can either:
1. Use `<C-g>s` to stop the current process and try again
2. Add a `!` at the end of the command (`:ParleyChatRespond!`) to force a new response

For more extensive revisions, place the cursor on a question and use `<C-g>G` to resubmit all questions from the beginning of the chat up to and including the current question. Each question will be processed in sequence, with responses replacing the existing answers. You can stop the resubmission at any time with `<C-g>s`.

## Manual Curation

The transcript is just a text document. So long as the 💬:, 🤖:, 🧠:, 📝: pattern is maintained, things work. You are free to edit any text. For example, adding headings `#` and `##` to group your questions into sections, which show up in the outline with `<C-g>t`.

# Install

## 1. Install the plugin

Snippets for your preferred package manager:

```lua
-- lazy.nvim
{
    "xianxu/parley.nvim",
    config = function()
        local conf = {
            -- For customization, refer to the Configuration section below
            -- Typically you should override the api_keys
            -- Example using macOS Keychain:
            -- security add-generic-password -a "your_username" -s "OPENAI_API_KEY" -w "your_api_key" -U
            api_keys = {
                openai = { "security", "find-generic-password", "-a", "your_username", "-s", "OPENAI_API_KEY", "-w" },
                anthropic = { "security", "find-generic-password", "-a", "your_username", "-s", "ANTHROPIC_API_KEY", "-w" },
                googleai = { "security", "find-generic-password", "-a", "your_username", "-s", "GOOGLEAI_API_KEY", "-w" },
                ollama = "dummy_secret",
            },
        }
        require("parley").setup(conf)
    end,
}
```

```lua
-- packer.nvim
use({
    "xianxu/parley.nvim",
    config = function()
        local conf = {
            api_keys = {
                openai = { "security", "find-generic-password", "-a", "your_username", "-s", "OPENAI_API_KEY", "-w" },
                anthropic = { "security", "find-generic-password", "-a", "your_username", "-s", "ANTHROPIC_API_KEY", "-w" },
                googleai = { "security", "find-generic-password", "-a", "your_username", "-s", "GOOGLEAI_API_KEY", "-w" },
                ollama = "dummy_secret",
            },
        }
        require("parley").setup(conf)
    end,
})
```

## 2. API Keys

You need at least one provider's API key configured. The API key can be provided in multiple ways:

| Method                    | Example                                                        | Security Level      |
| ------------------------- | -------------------------------------------------------------- | ------------------- |
| hardcoded string          | `api_keys = { openai = "sk-..." }`                             | Low                 |
| default env var           | set `OPENAI_API_KEY` env variable in shell config              | Medium              |
| custom env var            | `api_keys = { openai = os.getenv("CUSTOM_ENV_NAME") }`        | Medium              |
| read from file            | `api_keys = { openai = { "cat", "path_to_api_key" } }`        | Medium-High         |
| password manager          | `api_keys = { openai = { "bw", "get", "password", "KEY" } }`  | High                |
| macOS Keychain            | `api_keys = { openai = { "security", "find-generic-password", "-a", "user", "-s", "OPENAI_API_KEY", "-w" } }` | High |

If the value is a table, Parley runs it asynchronously to avoid blocking Neovim.

## 3. Providers

The following LLM providers are supported:

- **OpenAI** - GPT-4, GPT-4o, GPT-5 and other OpenAI models
- **Anthropic** - Claude Sonnet 4.6, Claude Haiku 4.5
- **Google AI** - Gemini 2.5 Pro, Gemini 2.5 Flash
- **Ollama** - Local/offline open-source models (disabled by default)
- Any other OpenAI chat/completions compatible endpoint (Azure, LM Studio, etc.)

Provider configuration example:

```lua
providers = {
    openai = {
        endpoint = "https://api.openai.com/v1/chat/completions",
    },
    anthropic = {
        endpoint = "https://api.anthropic.com/v1/messages",
    },
    googleai = {
        endpoint = "https://generativelanguage.googleapis.com/v1beta/models/{{model}}:streamGenerateContent?key={{secret}}",
    },
    ollama = {
        disable = false, -- enable Ollama
        endpoint = "http://localhost:11434/v1/chat/completions",
    },
}
```

## 4. Agents

Each agent combines a provider, model, and system prompt. Default agents:

| Agent | Provider | Model |
| ----- | -------- | ----- |
| ChatGPT4 | OpenAI | gpt-4 |
| ChatGPT5 | OpenAI | gpt-5 |
| ChatGPT4o | OpenAI | gpt-4o |
| ChatGPT-4o-search | OpenAI | gpt-4o-search-preview |
| Claude-Sonnet | Anthropic | claude-sonnet-4-6 |
| Claude-Haiku | Anthropic | claude-haiku-4-5 |
| Gemini2.5-Pro | Google AI | gemini-2.5-pro |
| Gemini2.5-Flash | Google AI | gemini-2.5-flash |
| ChatOllamaLlama3.1-8B | Ollama | llama3.1 (disabled) |

You can disable or add custom agents:

```lua
agents = {
    {
        name = "ChatGPT4",
        disable = true, -- disable a default agent
    },
    {
        name = "MyCustomAgent",
        provider = "openai",
        model = { model = "gpt-4-turbo", temperature = 0.7 },
        system_prompt = "You are a helpful assistant.",
    },
},
```

## 5. System Prompts

Parley includes named system prompts that can be switched independently of agents: `default`, `creative`, `concise`, `teacher`, `code_reviewer`. Switch between them with `<C-g>p` or `:ParleyNextSystemPrompt`.

## 6. Dependencies

The core plugin only needs `curl` installed. [Telescope](https://github.com/nvim-telescope/telescope.nvim) is optional but enhances the agent picker, system prompt picker, and outline navigation.

# Usage

All commands use the `:Parley` prefix (configurable via `cmd_prefix`).

## Chat Commands

#### `:ParleyChatNew`

Open a fresh chat in the current window. Global shortcut: `<C-g>c`

#### `:ParleyChatRespond`

Request a new response for the current question. `<C-g><C-g>`

Append `!` to force a new response even if a process is already running.

#### `:ParleyChatRespondAll`

Resubmit all questions from the beginning up to the cursor position. `<C-g>G`

#### `:ParleyChatDelete`

Delete the current chat. Requires confirmation by default (configurable with `chat_confirm_delete = false`). `<C-g>d`

#### `:ParleyChatFinder`

Open a dialog to search through chats. Global shortcut: `<C-g>f`

By default, shows chat files from the last 6 months (configurable via `chat_finder_recency.months`). While in the dialog:
- `<C-a>` to toggle between recent and all chats
- `<C-d>` to delete the selected chat
- Files are sorted by modification date with newest first

#### `:ParleyOutline`

Open an outline navigator showing questions and headings in the chat. `<C-g>t`

#### `:ParleyOpenFileUnderCursor`

Open the file or directory referenced by `@@` syntax under the cursor. `<C-g>o`

## Agent and System Prompt Commands

#### `:ParleyAgent [name]`

Opens a Telescope picker for selecting an agent. Optionally specify a name directly: `:ParleyAgent Claude-Sonnet`.

#### `:ParleyNextAgent`

Cycle to the next available agent. `<C-g>a`

#### `:ParleySystemPrompt [name]`

Opens a Telescope picker for selecting a system prompt. Optionally specify a name directly.

#### `:ParleyNextSystemPrompt`

Cycle to the next available system prompt. `<C-g>p`

## Toggle Commands

#### `:ParleyToggleClaudeWebSearch`

Toggle Claude's server-side web search tool for the current session. `<C-g>w`

Only available when using a provider that supports web search (currently Anthropic).

#### `:ParleyToggleInterview`

Toggle interview mode. `<C-n>i`

When enabled:
- Inserts a `:00min` marker at the cursor position
- Every time you press Enter in insert mode, a timestamp (e.g., `:05min`) is automatically inserted showing elapsed time since the interview started
- A flashing timer appears in the lualine statusline showing the current elapsed time
- Timestamp lines are highlighted with a distinct color

If you toggle interview mode while the cursor is on an existing timestamp line (e.g., `:12min`), the timer will resume from that point instead of resetting to zero. This is useful for continuing an interview after a break.

#### `:ParleyToggleRaw`

Toggle both raw request and raw response modes at once.

#### `:ParleyToggleRawRequest`

Toggle parsing of user JSON input as direct API requests.

#### `:ParleyToggleRawResponse`

Toggle display of raw JSON API responses.

## Export Commands

#### `:ParleyExportHTML`

Export the current chat to Jekyll blog post HTML format.

#### `:ParleyExportMarkdown`

Export the current chat to Markdown format.

## Note Commands

Parley includes a note-taking system that organizes notes by year, month, and week. Notes are stored in the configured `notes_dir` directory.

#### `:ParleyNoteNew`

Create a new note. Prompts for a subject, then creates a markdown file organized by date in the directory structure: `notes_dir/YYYY/MM/weekNN/DD-subject.md`. Global shortcut: `<C-n>c`

If the first word of the subject matches a subdirectory under `notes_dir`, the note is created in that subdirectory instead (without the date prefix). This allows organizing notes by project or category.

#### `:ParleyNoteNewFromTemplate`

Create a new note from a template. `<C-n>t`

Opens a Telescope picker (or vim.ui.select fallback) to choose from available templates in `notes_dir/templates/`. Built-in templates are created automatically on first use:
- **meeting-notes** - Meeting notes with attendees, agenda, action items
- **daily-note** - Daily note with tasks, notes, reflection sections
- **interview** - Interview template with `:00min` timestamp marker (pairs with interview mode)
- **basic** - Simple note with title and date

The `<C-n>r` shortcut changes the working directory to the current year's notes folder.

## Other Commands

#### `:ParleyStop`

Stop all currently running responses and jobs. `<C-g>s`

# Keybinding Summary

## Chat Buffer Shortcuts

| Shortcut | Action |
| -------- | ------ |
| `<C-g><C-g>` | Send current question / get response |
| `<C-g>G` | Resubmit all questions up to cursor |
| `<C-g>d` | Delete current chat |
| `<C-g>s` | Stop running response |
| `<C-g>a` | Switch agent |
| `<C-g>p` | Switch system prompt |
| `<C-g>n` | Search chats (in-buffer) |
| `<C-g>o` | Open file under cursor (@@) |
| `<C-g>t` | Outline navigator |
| `<C-g>w` | Toggle Claude web search |

## Global Shortcuts

| Shortcut | Action |
| -------- | ------ |
| `<C-g>c` | New chat |
| `<C-g>f` | Chat finder |
| `<C-g>a` | Add chat reference (in non-chat markdown files) |
| `<C-n>c` | New note |
| `<C-n>t` | New note from template |
| `<C-n>i` | Toggle interview mode |
| `<C-n>r` | Open year root (notes) |
| `<leader>fo` | Open oil.nvim file explorer |

# Chat Memory Management

The plugin supports automatic summarization of longer chat histories to maintain context while reducing token usage.

## How It Works

1. When chat messages exceed a configured threshold, older exchanges are replaced with their summaries
2. Summaries are extracted from assistant responses with the 📝: prefix
3. This allows the LLM to maintain context without the full token cost

## Configuration

```lua
chat_memory = {
    enable = true,
    max_full_exchanges = 5,
    summary_prefix = "📝:",
    reasoning_prefix = "🧠:",
    omit_user_text = "Summarize our chat",
},
```

# Raw Mode for API Debugging

Parley includes a "raw mode" for debugging and advanced use cases.

## Configuration

```lua
raw_mode = {
    enable = true,
    show_raw_response = false,
    parse_raw_request = false,
},
```

Or in a chat file header:

```
- raw_mode.show_raw_response: true
- raw_mode.parse_raw_request: true
```

## How It Works

1. **Raw Response Mode** (`show_raw_response`): Displays the API's raw JSON response as a code block, revealing usage statistics and metadata.

2. **Raw Request Mode** (`parse_raw_request`): Allows you to craft custom JSON requests to send directly to the API. Format your request as a JSON code block in your question:
   ```
   💬:
   ```json
   {
     "model": "gpt-4o",
     "messages": [
       {"role": "user", "content": "Hello"}
     ]
   }
   ```
   ```

# Customizing Appearance

## Highlighting

By default, Parley links its highlight groups to common built-in Neovim highlight groups:

- Questions (user messages): Linked to `Keyword`
- File references (@@filename): Linked to `WarningMsg`
- Thinking/reasoning lines (🧠:): Linked to `Comment`
- Annotations (@...@): Linked to `DiffAdd`

You can customize these:

```lua
highlight = {
    question = { fg = "#ffaf00", italic = true },
    file_reference = { fg = "#ffffff", bg = "#5c2020" },
    thinking = { fg = "#777777" },
    annotation = { bg = "#205c2c", fg = "#ffffff" },
},
```

# Lualine Integration

Parley includes built-in [lualine](https://github.com/nvim-lua/lualine.nvim) integration to display the current agent and cache metrics in your statusline.

## Configuration

```lua
lualine = {
    enable = true,
    section = "lualine_x",
},
```

When working in a chat buffer, the lualine component shows the current agent. No additional configuration is needed beyond enabling it.

## Manual Integration

For more control over positioning:

```lua
require('lualine').setup {
  sections = {
    lualine_x = {
      require('parley.lualine').create_component(),
    }
  }
}
```

# Configuration Reference

Below are additional configuration options beyond those covered in earlier sections. See `lua/parley/config.lua` for the full default configuration.

## Directory Paths

```lua
-- directory for storing chat files
chat_dir = vim.fn.stdpath("data"):gsub("/$", "") .. "/parley/chats",
-- directory for storing notes
notes_dir = vim.fn.stdpath("data"):gsub("/$", "") .. "/parley/notes",
-- export directories
export_html_dir = "~/blogs/static",
export_markdown_dir = "~/blogs/_posts",
```

## Chat Behavior

```lua
-- prefix for all commands (e.g., :ParleyChatNew)
cmd_prefix = "Parley",
-- optional curl parameters (for proxy, etc.)
curl_params = { "--proxy", "http://X.X.X.X:XXXX" },
-- default agent on startup (nil = last used agent)
default_agent = nil,
-- enable Claude web search tool by default
claude_web_search = true,
-- don't move cursor to end of buffer after response completes
chat_free_cursor = true,
-- require confirmation before deleting a chat
chat_confirm_delete = true,
-- conceal model parameters in the chat header
chat_conceal_model_params = true,
```

## Chat Prefixes

These control the markers used in chat transcripts:

```lua
chat_user_prefix = "💬:",
chat_assistant_prefix = { "🤖:", "[{{agent}}]" },
-- local section prefix (content ignored by parley processing)
chat_local_prefix = "🔒:",
```

## Chat Finder Styling

```lua
style_chat_finder_border = "single",  -- "single" | "double" | "rounded" | "solid" | "shadow" | "none"
style_chat_finder_margin_bottom = 8,
style_chat_finder_margin_left = 1,
style_chat_finder_margin_right = 2,
style_chat_finder_margin_top = 2,
style_chat_finder_preview_ratio = 0.5,  -- 0.0 to 1.0
```

## Logging

```lua
log_file = vim.fn.stdpath("log"):gsub("/$", "") .. "/parley.nvim.log",
-- write sensitive data (like api keys) to log for debugging
log_sensitive = false,
```

## Hooks

Hooks are custom Lua functions registered as commands. Two built-in hooks are provided:

```lua
hooks = {
    -- :ParleyInspectPlugin - shows plugin state in a buffer
    InspectPlugin = function(plugin, params) ... end,
    -- :ParleyInspectLog - opens the log file
    InspectLog = function(plugin, params) ... end,
},
```

You can add your own hooks to extend functionality. Each hook becomes a `:Parley<HookName>` command.

# Acknowledgement

This was adapted from [gp.nvim](https://github.com/Robitx/gp.nvim). I decided to fork as I wanted a simple transcript tool to talk to LLM providers.
