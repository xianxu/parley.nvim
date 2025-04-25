<!-- panvimdoc-ignore-start -->

<a href="https://github.com/Robitx/gp.nvim/blob/main/LICENSE"><img alt="GitHub" src="https://img.shields.io/github/license/robitx/gp.nvim"></a>
<a href="https://github.com/Robitx/gp.nvim/stargazers"><img alt="GitHub Repo stars" src="https://img.shields.io/github/stars/Robitx/gp.nvim"></a>
<a href="https://github.com/Robitx/gp.nvim/issues"><img alt="GitHub closed issues" src="https://img.shields.io/github/issues-closed/Robitx/gp.nvim"></a>
<a href="https://github.com/Robitx/gp.nvim/pulls"><img alt="GitHub closed pull requests" src="https://img.shields.io/github/issues-pr-closed/Robitx/gp.nvim?label=PRs"></a>
<a href="https://github.com/Robitx/gp.nvim/graphs/contributors"><img alt="GitHub contributors" src="https://img.shields.io/github/contributors-anon/Robitx/gp.nvim"></a>
<a href="https://github.com/search?q=%2F%5E%5B%5Cs%5D*require%5C%28%5B%27%22%5Dgp%5B%27%22%5D%5C%29%5C.setup%2F+language%3ALua&type=code&p=1"><img alt="Static Badge" src="https://img.shields.io/badge/Use%20in%20the%20Wild-8A2BE2"></a>
<a href="https://discord.gg/dYyHmyNpv7"><img alt="Discord" src="https://img.shields.io/discord/1200485978725433484?label=Discord"></a>


# Gp.nvim (GPT prompt) Neovim AI plugin

<!-- panvimdoc-ignore-end -->

<br>

**ChatGPT-like sessions with highlighting and navigation, focused on simplicity and readability.**

<p align="left">
<img src="https://github.com/Robitx/gp.nvim/assets/8431097/cb288094-2308-42d6-9060-4eb21b3ba74c" width="49%">
<img src="https://github.com/Robitx/gp.nvim/assets/8431097/c538f0a2-4667-444e-8671-13f8ea261be1" width="49%">
</p>

### Youtube demos

- [5-min-demo](https://www.youtube.com/watch?v=X-cT7s47PLo) (December 2023)
- [older-5-min-demo](https://www.youtube.com/watch?v=wPDcBnQgNCc) (screen capture, no sound)

# Goals and Features

This is a simplified fork of gp.nvim focused exclusively on chat functionality. The goal is to provide a streamlined experience for LLM conversations in Neovim with easy navigation and beautiful highlighting.

- **Streamlined Chat Experience**
  - Markdown-formatted chat transcripts with syntax highlighting
  - Question/response highlighting with custom colors
  - Navigate chat Q&A exchanges using Telescope outline
  - Easy keybindings for creating and managing chats
- **Streaming responses**
  - No spinner wheel and waiting for the full answer
  - Response generation can be canceled half way through
  - Properly working undo (response can be undone with a single `u`)
- **Minimum dependencies** (`neovim`, `curl`, `grep`)
  - Zero dependencies on other lua plugins to minimize chance of breakage
- **ChatGPT like sessions**
  - Just good old neovim buffers formated as markdown with autosave
  - Last chat also quickly accessible via toggable popup window
  - Chat finder - management popup for searching, previewing, deleting and opening chat sessions

# Install

## 1. Install the plugin

Snippets for your preferred package manager:

```lua
-- lazy.nvim
{
    "robitx/gp.nvim",
    config = function()
        local conf = {
            -- For customization, refer to Install > Configuration in the Documentation/Readme
        }
        require("gp").setup(conf)

        -- Setup shortcuts here (see Usage > Shortcuts in the Documentation/Readme)
    end,
}
```

```lua
-- packer.nvim
use({
    "robitx/gp.nvim",
    config = function()
        local conf = {
            -- For customization, refer to Install > Configuration in the Documentation/Readme
        }
        require("gp").setup(conf)

        -- Setup shortcuts here (see Usage > Shortcuts in the Documentation/Readme)
    end,
})
```

```lua
-- vim-plug
Plug 'robitx/gp.nvim'

local conf = {
    -- For customization, refer to Install > Configuration in the Documentation/Readme
}
require("gp").setup(conf)

-- Setup shortcuts here (see Usage > Shortcuts in the Documentation/Readme)
```
## 2. OpenAI API key

Make sure you have OpenAI API key. [Get one here](https://platform.openai.com/account/api-keys) and use it in the [4. Configuration](#4-configuration). Also consider setting up [usage limits](https://platform.openai.com/account/billing/limits) so you won't get suprised at the end of the month.

The OpenAI API key can be passed to the plugin in multiple ways:

| Method                    | Example                                                        | Security Level      |
| ------------------------- | -------------------------------------------------------------- | ------------------- |
| hardcoded string          | `openai_api_key: "sk-...",`                                    | Low                 |
| default env var           | set `OPENAI_API_KEY` environment variable in shell config      | Medium              |
| custom env var            | `openai_api_key = os.getenv("CUSTOM_ENV_NAME"),`               | Medium              |
| read from file            | `openai_api_key = { "cat", "path_to_api_key" },`               | Medium-High         |
| password manager          | `openai_api_key = { "bw", "get", "password", "OAI_API_KEY" },` | High                |

If `openai_api_key` is a table, Gp runs it asynchronously to avoid blocking Neovim (password managers can take a second or two).

## 3. Multiple providers
The following LLM providers are currently supported besides OpenAI:

- [Ollama](https://github.com/ollama/ollama) for local/offline open-source models. The plugin assumes you have the Ollama service up and running with configured models available (the default Ollama agent uses Llama3).
- [GitHub Copilot](https://github.com/settings/copilot) with a Copilot license ([zbirenbaum/copilot.lua](https://github.com/zbirenbaum/copilot.lua) or [github/copilot.vim](https://github.com/github/copilot.vim) for autocomplete). You can access the underlying GPT-4 model without paying anything extra (essentially unlimited GPT-4 access).
- [Perplexity.ai](https://www.perplexity.ai/pro) Pro users have $5/month free API credits available (the default PPLX agent uses Mixtral-8x7b).
- [Anthropic](https://www.anthropic.com/api) to access Claude models, which currently outperform GPT-4 in some benchmarks.
- [Google Gemini](https://ai.google.dev/) with a quite generous free range but some geo-restrictions (EU).
- Any other "OpenAI chat/completions" compatible endpoint (Azure, LM Studio, etc.)

Below is an example of the relevant configuration part enabling some of these. The `secret` field has the same capabilities as `openai_api_key` (which is still supported for compatibility).

```lua
	providers = {
		openai = {
			endpoint = "https://api.openai.com/v1/chat/completions",
			secret = os.getenv("OPENAI_API_KEY"),
		},

		-- azure = {...},

		copilot = {
			endpoint = "https://api.githubcopilot.com/chat/completions",
			secret = {
				"bash",
				"-c",
				"cat ~/.config/github-copilot/hosts.json | sed -e 's/.*oauth_token...//;s/\".*//'",
			},
		},

		pplx = {
			endpoint = "https://api.perplexity.ai/chat/completions",
			secret = os.getenv("PPLX_API_KEY"),
		},

		ollama = {
			endpoint = "http://localhost:11434/v1/chat/completions",
		},

		googleai = {
			endpoint = "https://generativelanguage.googleapis.com/v1beta/models/{{model}}:streamGenerateContent?key={{secret}}",
			secret = os.getenv("GOOGLEAI_API_KEY"),
		},

		anthropic = {
			endpoint = "https://api.anthropic.com/v1/messages",
			secret = os.getenv("ANTHROPIC_API_KEY"),
		},
	},
```

Each of these providers has some agents preconfigured. Below is an example of how to disable predefined ChatGPT3-5 agent and create a custom one. If the `provider` field is missing, OpenAI is assumed for backward compatibility.

```lua
	agents = {
		{
			name = "ChatGPT3-5",
			disable = true,
		},
		{
			name = "MyCustomAgent",
			provider = "copilot",
			chat = true,
			command = true,
			model = { model = "gpt-4-turbo" },
			system_prompt = "Answer any query with just: Sure thing..",
		},
	},

```


## 4. Dependencies

The core plugin only needs `curl` installed to make calls to OpenAI API and `grep` for ChatFinder. So Linux, BSD and Mac OS should be covered.

## 5. Configuration

Below is a linked snippet with the default values, but I suggest starting with minimal config possible (just `openai_api_key` if you don't have `OPENAI_API_KEY` env set up). Defaults change over time to improve things, options might get deprecated and so on - it's better to change only things where the default doesn't fit your needs.

<!-- README_REFERENCE_MARKER_REPLACE_NEXT_LINE -->
https://github.com/Robitx/gp.nvim/blob/8dd99d85adfcfcb326f85a1f15bcd254f628df59/lua/gp/config.lua#L10-L627

# Usage

## Chat commands

#### `:GpChatNew` <!-- {doc=:GpChatNew}  -->

Open a fresh chat in the current window. It can be either empty or include the visual selection or specified range as context. This command also supports subcommands for layout specification:

- `:GpChatNew vsplit` Open a fresh chat in a vertical split window.
- `:GpChatNew split` Open a fresh chat in a horizontal split window.
- `:GpChatNew tabnew` Open a fresh chat in a new tab.
- `:GpChatNew popup` Open a fresh chat in a popup window.

#### `:GpChatPaste` <!-- {doc=:GpChatPaste}  -->

Paste the selection or specified range into the latest chat, simplifying the addition of code from multiple files into a single chat buffer. This command also supports subcommands for layout specification:

- `:GpChatPaste vsplit` Paste into the latest chat in a vertical split window.
- `:GpChatPaste split` Paste into the latest chat in a horizontal split window.
- `:GpChatPaste tabnew` Paste into the latest chat in a new tab.
- `:GpChatPaste popup` Paste into the latest chat in a popup window.

#### `:GpChatToggle` <!-- {doc=:GpChatToggle}  -->

Open chat in a toggleable popup window, showing the last active chat or a fresh one with selection or a range as a context. This command also supports subcommands for layout specification:

- `:GpChatToggle vsplit` Toggle chat in a vertical split window.
- `:GpChatToggle split` Toggle chat in a horizontal split window.
- `:GpChatToggle tabnew` Toggle chat in a new tab.
- `:GpChatToggle popup` Toggle chat in a popup window.

#### `:GpChatFinder` <!-- {doc=:GpChatFinder}  -->

Open a dialog to search through chats.

#### `:GpChatRespond` <!-- {doc=:GpChatRespond}  -->

Request a new GPT response for the current chat. Usin`:GpChatRespond N` request a new GPT response with only the last N messages as context, using everything from the end up to the Nth instance of `🗨:..` (N=1 is like asking a question in a new chat).

#### `:GpChatDelete` <!-- {doc=:GpChatDelete}  -->

Delete the current chat. By default requires confirmation before delete, which can be disabled in config using `chat_confirm_delete = false,`.

## Agent commands

#### `:GpNextAgent` <!-- {doc=:GpNextAgent}  -->

Cycles between available agents based on the current buffer (chat agents if current buffer is a chat and command agents otherwise). The agent setting is persisted on disk across Neovim instances.

#### `:GpAgent` <!-- {doc=:GpAgent}  -->

Displays currently used agents for chat and command instructions.

#### `:GpAgent XY` <!-- {doc=:GpAgent-XY}  -->

Choose a new agent based on its name, listing options based on the current buffer (chat agents if current buffer is a chat and command agents otherwise). The agent setting is persisted on disk across Neovim instances.

## Other commands

#### `:GpStop` <!-- {doc=:GpStop}  -->

Stops all currently running responses and jobs.

# Shortcuts

There are no default global shortcuts to mess with your own config. Below are examples for you to adjust or just use directly.

## Native

You can use the good old `vim.keymap.set` and paste the following after `require("gp").setup(conf)` call
(or anywhere you keep shortcuts if you want them at one place).

```lua
local function keymapOptions(desc)
    return {
        noremap = true,
        silent = true,
        nowait = true,
        desc = "GPT prompt " .. desc,
    }
end

-- Chat commands
vim.keymap.set({"n", "i"}, "<C-g>c", "<cmd>GpChatNew<cr>", keymapOptions("New Chat"))
vim.keymap.set({"n", "i"}, "<C-g>t", "<cmd>GpChatToggle<cr>", keymapOptions("Toggle Chat"))
vim.keymap.set({"n", "i"}, "<C-g>f", "<cmd>GpChatFinder<cr>", keymapOptions("Chat Finder"))

vim.keymap.set("v", "<C-g>c", ":<C-u>'<,'>GpChatNew<cr>", keymapOptions("Visual Chat New"))
vim.keymap.set("v", "<C-g>p", ":<C-u>'<,'>GpChatPaste<cr>", keymapOptions("Visual Chat Paste"))
vim.keymap.set("v", "<C-g>t", ":<C-u>'<,'>GpChatToggle<cr>", keymapOptions("Visual Toggle Chat"))

vim.keymap.set({ "n", "i" }, "<C-g><C-x>", "<cmd>GpChatNew split<cr>", keymapOptions("New Chat split"))
vim.keymap.set({ "n", "i" }, "<C-g><C-v>", "<cmd>GpChatNew vsplit<cr>", keymapOptions("New Chat vsplit"))
vim.keymap.set({ "n", "i" }, "<C-g><C-t>", "<cmd>GpChatNew tabnew<cr>", keymapOptions("New Chat tabnew"))

vim.keymap.set("v", "<C-g><C-x>", ":<C-u>'<,'>GpChatNew split<cr>", keymapOptions("Visual Chat New split"))
vim.keymap.set("v", "<C-g><C-v>", ":<C-u>'<,'>GpChatNew vsplit<cr>", keymapOptions("Visual Chat New vsplit"))
vim.keymap.set("v", "<C-g><C-t>", ":<C-u>'<,'>GpChatNew tabnew<cr>", keymapOptions("Visual Chat New tabnew"))

vim.keymap.set({"n", "i", "v", "x"}, "<C-g>s", "<cmd>GpStop<cr>", keymapOptions("Stop"))
vim.keymap.set({"n", "i", "v", "x"}, "<C-g>n", "<cmd>GpNextAgent<cr>", keymapOptions("Next Agent"))
```

## Whichkey

Or go more fancy by using [which-key.nvim](https://github.com/folke/which-key.nvim) plugin:

```lua
require("which-key").add({
    -- VISUAL mode mappings
    -- s, x, v modes are handled the same way by which_key
    {
        mode = { "v" },
        nowait = true,
        remap = false,
        { "<C-g><C-t>", ":<C-u>'<,'>GpChatNew tabnew<cr>", desc = "ChatNew tabnew" },
        { "<C-g><C-v>", ":<C-u>'<,'>GpChatNew vsplit<cr>", desc = "ChatNew vsplit" },
        { "<C-g><C-x>", ":<C-u>'<,'>GpChatNew split<cr>", desc = "ChatNew split" },
        { "<C-g>c", ":<C-u>'<,'>GpChatNew<cr>", desc = "Visual Chat New" },
        { "<C-g>n", "<cmd>GpNextAgent<cr>", desc = "Next Agent" },
        { "<C-g>p", ":<C-u>'<,'>GpChatPaste<cr>", desc = "Visual Chat Paste" },
        { "<C-g>s", "<cmd>GpStop<cr>", desc = "GpStop" },
        { "<C-g>t", ":<C-u>'<,'>GpChatToggle<cr>", desc = "Visual Toggle Chat" },
    },

    -- NORMAL mode mappings
    {
        mode = { "n" },
        nowait = true,
        remap = false,
        { "<C-g><C-t>", "<cmd>GpChatNew tabnew<cr>", desc = "New Chat tabnew" },
        { "<C-g><C-v>", "<cmd>GpChatNew vsplit<cr>", desc = "New Chat vsplit" },
        { "<C-g><C-x>", "<cmd>GpChatNew split<cr>", desc = "New Chat split" },
        { "<C-g>c", "<cmd>GpChatNew<cr>", desc = "New Chat" },
        { "<C-g>f", "<cmd>GpChatFinder<cr>", desc = "Chat Finder" },
        { "<C-g>n", "<cmd>GpNextAgent<cr>", desc = "Next Agent" },
        { "<C-g>s", "<cmd>GpStop<cr>", desc = "GpStop" },
        { "<C-g>t", "<cmd>GpChatToggle<cr>", desc = "Toggle Chat" },
    },

    -- INSERT mode mappings
    {
        mode = { "i" },
        nowait = true,
        remap = false,
        { "<C-g><C-t>", "<cmd>GpChatNew tabnew<cr>", desc = "New Chat tabnew" },
        { "<C-g><C-v>", "<cmd>GpChatNew vsplit<cr>", desc = "New Chat vsplit" },
        { "<C-g><C-x>", "<cmd>GpChatNew split<cr>", desc = "New Chat split" },
        { "<C-g>c", "<cmd>GpChatNew<cr>", desc = "New Chat" },
        { "<C-g>f", "<cmd>GpChatFinder<cr>", desc = "Chat Finder" },
        { "<C-g>n", "<cmd>GpNextAgent<cr>", desc = "Next Agent" },
        { "<C-g>s", "<cmd>GpStop<cr>", desc = "GpStop" },
        { "<C-g>t", "<cmd>GpChatToggle<cr>", desc = "Toggle Chat" },
    },
})
```

# Chat Memory Management

The plugin supports automatic summarization of longer chat histories to maintain context while reducing token usage. This feature is particularly useful for long conversations where earlier parts can be summarized instead of sending the full transcript to the API.

## How It Works

1. When chat messages exceed a configured threshold, older exchanges are replaced with a summary
2. Summaries are extracted from assistant responses with a specific prefix (default: "📝:")
3. This allows the LLM to maintain context of the conversation without the full token cost

## Configuration

The chat memory feature can be configured in your setup:

```lua
chat_memory = {
    -- enable summary feature for older messages
    enable = true,
    -- maximum number of full exchanges to keep (a user and assistant pair)
    max_full_exchanges = 3,
    -- prefix for note lines in assistant responses (used to extract summaries)
    summary_prefix = "📝:",
    -- prefix for reasoning lines in assistant responses (used to extract summaries)
    reasoning_prefix = "🧠:",
    -- text to replace omitted user messages
    omit_user_text = "Summarize previous chat",
},
```

## Usage

To take advantage of this feature, instruct your LLM in the system prompt to include summaries of the conversation. For example the following, or check defaults.lua for details.

```
When thinking through complex problems, prefix your reasoning with 🧠: for clarity.
After answering my question, please include a brief summary of our exchange prefixed with 📝:
```

When the chat grows beyond the configured limit, the plugin will automatically replace older messages with the extracted summaries.