<!-- panvimdoc-ignore-start -->

<a href="https://github.com/xianxu/parley.nvim/blob/main/LICENSE"><img alt="GitHub" src="https://img.shields.io/github/license/xianxu/parley.nvim"></a>

# Parley.nvim

<!-- panvimdoc-ignore-end -->

Parley is a Neovim chat notebook for LLM conversations. You have all the power of Neovim at your fingertips in your LLM chat, thus making comprehensive research easier. All your chat history also lives in plain markdown files, you can easily search through using local tools.

The philosophy is simple:
- Keep chats as plain Markdown files you can edit anytime. The chat transcript file has the full state of LLM chat.
- Highly configurable but also have good default out of box.
- Keep the workflow keyboard-first and fast.
- Keep behavior predictable across providers.

Why is it better than official UI?
- You can access your private local file, and private Google Drive file through oauth.
- All you chat history in one place locally, you can search and do many other things with it.
- Pick models from different vendors.
- Tweak system prompts to best suit your needs.
- Also a good learning tool for LLM interactions, e.g. in raw modes, you see all request/response details.

## Quick Install

Requirements:
- Neovim
- `curl`
- `grep`

Optional dependencies:
- [`telescope.nvim`](https://github.com/nvim-telescope/telescope.nvim) for pickers and finder UI.
- [`lualine.nvim`](https://github.com/nvim-lualine/lualine.nvim) for status line integration.

Example with `lazy.nvim`:

```lua
{
    "xianxu/parley.nvim",
    config = function()
        require("parley").setup({
            api_keys = {
                openai = os.getenv("OPENAI_API_KEY"),
                anthropic = os.getenv("ANTHROPIC_API_KEY"),
                googleai = os.getenv("GOOGLEAI_API_KEY"),
                ollama = "dummy_secret",
            },
        })
    end,
}
```

macOS Keychain example:

1. Save API keys to Keychain (replace `your_username` and key values):

```bash
security add-generic-password -a "your_username" -s "OPENAI_API_KEY" -w "sk-..." -U
security add-generic-password -a "your_username" -s "ANTHROPIC_API_KEY" -w "sk-ant-..." -U
security add-generic-password -a "your_username" -s "GOOGLEAI_API_KEY" -w "AIza..." -U
```

2. Fetch keys from Keychain in `api_keys`:

```lua
{
    "xianxu/parley.nvim",
    config = function()
        require("parley").setup({
            api_keys = {
                openai = { "security", "find-generic-password", "-a", "your_username", "-s", "OPENAI_API_KEY", "-w" },
                anthropic = { "security", "find-generic-password", "-a", "your_username", "-s", "ANTHROPIC_API_KEY", "-w" },
                googleai = { "security", "find-generic-password", "-a", "your_username", "-s", "GOOGLEAI_API_KEY", "-w" },
                ollama = "dummy_secret",
            },
        })
    end,
}
```

Notes:
- Configure at least one provider key.
- `api_keys` values can be strings or shell commands (for password managers/keychain).

## First 60 Seconds

1. Run `:ParleyChatNew` (default shortcut: `<C-g>c`).
2. Type your prompt after `💬:`.
3. Run `:ParleyChatRespond` (default shortcut: `<C-g><C-g>`).
4. Edit any part of the transcript and ask again.

A Parley chat is a normal markdown file with a header and alternating `💬:` / `🤖:` blocks.

## Basic Commands

- `:ParleyChatNew` create a new chat.
- `:ParleyChatRespond` answer current question.
- `:ParleyChatRespondAll` regenerate from start to cursor.
- `:ParleyStop` stop running generation.
- `:ParleyChatFinder` find/open/delete chat files.
- `:ParleyKeyBindings` show active Parley keyboard shortcuts.
- `:ParleyAgent` switch agent.
- `:ParleySystemPrompt` switch system prompt.
- `:ParleyToggleFollowCursor` toggle live cursor-follow during streaming.

Most-used defaults:
- `<C-g>c` new chat
- `<C-g>?` show key bindings
- `<C-g><C-g>` respond
- `<C-g>G` respond all
- `<C-g>s` stop
- `<C-g>f` chat finder
- `<C-g>a` change agent
- `<C-g>p` next system prompt
- `<C-g>l` toggle follow cursor

## What Parley Supports

- Providers: OpenAI, Anthropic, Google AI, Ollama, and OpenAI-compatible endpoints.
- File context with `@@path/to/file` and directory patterns.
- Web search toggle for supported providers.
- Outline navigation, highlighting.
- Export chat to markdown or HTML, for blogging, e.g. [a chat about async programming](https://xianxu.github.io/2025/05/12/conversation_around_concurrent_programming_models.html).
- Misc: notes, interview mode, raw mode, and export.

## Configuration Entry Points

Common options live in `setup()`:
- `api_keys`
- `providers`
- `agents`
- `chat_dir`
- `notes_dir`
- `web_search`

Merge behavior in `setup(opts)`:
- `agents`, `system_prompts`, and `hooks` are merged by key/name, so you can override only selected entries.
- Most other top-level keys are replaced when provided (for example `chat_dir`, `notes_dir`, `chat_template`, `raw_mode`, `highlight`, `chat_memory`, `providers`, `api_keys`).
- Practical rule: for non-merged tables, provide the full table you want, not just one nested field.

For full defaults and examples, see [`lua/parley/config.lua`](lua/parley/config.lua).

## Detailed Docs (Specs)

Advanced behavior is intentionally kept out of this README and documented in specs:

- Overview index: [`specs/index.md`](specs/index.md)
- Chat format/parsing/lifecycle:
  - [`specs/chat/format.md`](specs/chat/format.md)
  - [`specs/chat/parsing.md`](specs/chat/parsing.md)
  - [`specs/chat/lifecycle.md`](specs/chat/lifecycle.md)
  - [`specs/chat/memory.md`](specs/chat/memory.md)
- Providers and agents:
  - [`specs/providers/architecture.md`](specs/providers/architecture.md)
  - [`specs/providers/openai.md`](specs/providers/openai.md)
  - [`specs/providers/anthropic.md`](specs/providers/anthropic.md)
  - [`specs/providers/googleai.md`](specs/providers/googleai.md)
  - [`specs/providers/agents.md`](specs/providers/agents.md)
- Context tools:
  - [`specs/context/file_references.md`](specs/context/file_references.md)
  - [`specs/context/google_drive.md`](specs/context/google_drive.md)
  - [`specs/context/web_search.md`](specs/context/web_search.md)
- UI/features:
  - [`specs/ui/pickers.md`](specs/ui/pickers.md)
  - [`specs/ui/keybindings.md`](specs/ui/keybindings.md)
  - [`specs/ui/outline.md`](specs/ui/outline.md)
  - [`specs/ui/highlights.md`](specs/ui/highlights.md)
  - [`specs/ui/lualine.md`](specs/ui/lualine.md)
- Notes/modes/export:
  - [`specs/notes/structure.md`](specs/notes/structure.md)
  - [`specs/notes/templates.md`](specs/notes/templates.md)
  - [`specs/modes/interview.md`](specs/modes/interview.md)
  - [`specs/modes/raw_mode.md`](specs/modes/raw_mode.md)
  - [`specs/export/formats.md`](specs/export/formats.md)

## Acknowledgement

Parley was adapted from [gp.nvim](https://github.com/Robitx/gp.nvim).
