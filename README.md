<!-- panvimdoc-ignore-start -->

<a href="https://github.com/xianxu/parley.nvim/blob/main/LICENSE"><img alt="GitHub" src="https://img.shields.io/github/license/xianxu/parley.nvim"></a>

# Parley.nvim

<!-- panvimdoc-ignore-end -->

Parley is a Neovim chat notebook for LLM conversations. There are just many different ways we can leverage it. With Parley, you have all the power of Neovim at your fingertips in your LLM chat, thus making comprehensive research easier. All your chat history also lives in plain markdown files, you can easily search through using local tools. You can even direct your coding agent to act according to the "brainstorming" chat thread you had with other agents, for example. The possibilities seem endless.

The philosophy is Keep Things Simple, and a bit of Unix:
- Keep chats as plain Markdown files you can edit any place
- The chat transcript file has the full state of LLM chat
- Highly configurable but also have good default out-of-box
- Keep the workflow keyboard-first and fast
- Keep behavior predictable across different chat providers
- Leverage Neovim, and all its goodies
- Minimal dependencies, install and it works, all you need is your API keys

Despite of such simple interface, it's very powerful, sometimes more so than official app
- You can use "any" LLM providers, mix in the same conversation input from many different LLMs
- Your chat transcript can be as complex as a tree with branches, to allow you to explore into different directions, without being forced into a linear conversation
- You can jump easily between such tree branches
- You can access your private local file, and private Google Drive file through oauth
- You can edit anything in the transcript, including LLM responses, which presumably would influence the agent's future responses, a soft prompt engineering. You are constructing an understanding of a topic together with the help of LLMs
- All you chat history in one place locally, you can search and further refine with whatever tools you want
- Tweak system prompts to best suit your needs
- Have many different chat threads active in different vim buffers, terminals etc., no limits
- Easily switch between different chat threads, instant search experience with Chat Finder <C-g>f anywhere in Neovim
- Also a good learning tool for LLM interactions, e.g. in raw request/response modes, you see all request/response details
- New LLMs support web search and grounding, you can easily enable or disable if you want it to be faster
- Publish your chat as markdown or HTML, for blogging or sharing, e.g. [a chat about async programming](https://xianxu.github.io/2025/05/12/conversation_around_concurrent_programming_models.html)
- Share your brainstorming transcripts with your coding agents to start materializing it!

## Quick Install

Optional dependencies:
- [`lualine.nvim`](https://github.com/nvim-lualine/lualine.nvim) for status line integration. Not missing much if not available.
- `curl` for oauth and fetching web content.

Example with `lazy.nvim`

```lua
{
    "xianxu/parley.nvim",
    config = function()
        require("parley").setup({
            -- supply at least one
            api_keys = {
                -- openai = "sk-...", -- or set env vars and fetch with os.getenv
                openai = os.getenv("OPENAI_API_KEY"),
                -- anthropic = ...
                -- googleai = ...
                -- ollama = ...
            },
        })
    end,
}
```

A bit safer, macOS Keychain example:

1. First save API keys to Keychain (replace `your_username` and key values):

```bash
security add-generic-password -a "your_username" -s "OPENAI_API_KEY" -w "sk-..." -U
...
```

2. Then fetch keys from Keychain in `api_keys`:

```lua
{
    "xianxu/parley.nvim",
    config = function()
        require("parley").setup({
            -- supply at least one
            api_keys = {
                openai = { "security", "find-generic-password", "-a", "your_username", "-s", "OPENAI_API_KEY", "-w" },
                -- anthropic = ...
                -- googleai = ...
                -- ollama = ...
            },
        })
    end,
}
```

Notes:
- Configure at least one provider key.
- `api_keys` values can be strings or shell commands (for password managers/Keychain) resolve to a string.

## First 60 Seconds

1. Run `:ParleyChatNew` (default shortcut: `<C-g>c`) to create a new chat.
2. Type your question after `💬:`, no need for anything else. `Topic: ?` will be automatically filled with summary of your question.
3. Run `:ParleyChatRespond` (default shortcut: `<C-g><C-g>`) with mouse on the question line.
4. Get response from the agent after `🤖:`, streaming in real time.

A Parley chat is a normal markdown file with a header and alternating `💬:` / `🤖:` blocks.

## Basic Commands

Most-used defaults:

**Global**
- `<C-g>c` new chat - global hotkey
- `<C-g>f` find chat - global hotkey

**In Chat Buffer**
- `<C-g>?` show key bindings
- `<C-g><C-g>` respond
- `<C-g>G` respond all
- `<C-g>s` stop
- `<C-g>t` chat outline
- `<C-g>a` change agent
- `<C-g>p` next system prompt
- `<C-g>l` toggle follow cursor

**Corresponding commands**
- `:ParleyChatNew` create a new chat
- `:ParleyChatFinder` chat finder
- `:ParleyChatRespond` answer current question
- `:ParleyChatRespondAll` regenerate from start to cursor
- `:ParleyStop` stop running generation
- `:ParleyOutline` display questions in this buffer for navigation
- `:ParleyKeyBindings` show active Parley keyboard shortcuts
- `:ParleyAgent` switch agent
- `:ParleySystemPrompt` switch system prompt
- `:ParleyToggleFollowCursor` toggle live cursor-follow during streaming

## What Parley Supports

- Providers: OpenAI, Anthropic, Google AI, Ollama, OpenAI-compatible endpoints, and `CLI Proxy API``:w
- File context with `@@path/to/file` and directory patterns.
- Web search toggle for supported providers.
- Outline navigation, highlighting.
- Export chat to markdown or HTML, for blogging, e.g. [a chat about async programming](https://xianxu.github.io/2025/05/12/conversation_around_concurrent_programming_models.html).
- Misc: notes, interview mode, raw mode, and export.

## Configuration Entry Points

Common options live in `setup()`:
- `api_keys`
- `chat_dir`
- `notes_dir`

Merge behavior in `setup(opts)`:
- `agents`, `system_prompts`, and `hooks` are merged by key/name, so you can override only selected entries.
- Most other top-level keys are replaced when provided (for example `chat_dir`, `chat_dirs`, `notes_dir`, `chat_template`, `raw_mode`, `highlight`, `chat_memory`, `providers`, `api_keys`).
- Practical rule: for non-merged tables, provide the full table you want, not just one nested field.
- Reference [lua/parley/config.lua](https://github.com/xianxu/parley.nvim/blob/main/lua/parley/config.lua) for full defaults and examples.

Chat storage roots:
- `chat_dir` is the primary writable root used for new chats.
- `chat_dirs` is an optional list of additional roots that Chat Finder, chat validation, and chat-aware commands will scan alongside `chat_dir`.
- `:ParleyChatDirs` opens a picker to add or remove chat roots at runtime.
- `:ParleyChatDirAdd {dir}` adds a root directly, with directory completion.
- `:ParleyChatDirRemove {dir}` removes a configured root directly.
- `:ParleyChatMove {dir}` moves the current chat to another registered chat root.
- The primary `chat_dir` cannot be removed at runtime.
- The default shortcut for chat-root management is `<C-g>h`.

For full defaults and examples, see [`lua/parley/config.lua`](lua/parley/config.lua).

## Detailed Docs (Specs)

Advanced behavior is intentionally kept out of this README and documented in specs:

- Overview index: [`specs/index.md`](specs/index.md)

## Acknowledgement

Parley was adapted from [gp.nvim](https://github.com/Robitx/gp.nvim), but has since been largely redesigned and rewritten.
