<!-- panvimdoc-ignore-start -->

<a href="https://github.com/xianxu/parley.nvim/blob/main/LICENSE"><img alt="GitHub" src="https://img.shields.io/github/license/xianxu/parley.nvim"></a>

# Parley.nvim - Streamlined Chat Plugin for Neovim

<!-- panvimdoc-ignore-end -->

<br>

**ChatGPT-like sessions with highlighting and navigation, focused on simplicity and readability.** 

NOTE: this was [gp.nvim](https://github.com/Robitx/gp.nvim). I decided to fork as I wanted a simple transcript tool to talk to LLM providers.

# Goals and Features

Parley is a streamlined LLM chat plugin for NeoVIM, focusing exclusively on providing a clean and efficient interface for conversations with AI assistants. With built-in highlighting, question tracking, memory management and navigation tools, it makes LLM interactions in your editor both pleasant and productive. You brainstorm with your favorite AI assistant while keeping track the discussion. You can go back to the discussion, update questions and refresh answers. You can update and markup in assistant's answers, as you learn more facts. Think a document more as a research draft on some topic.

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
  - Chat finder - management popup for searching, previewing, deleting and opening chat sessions
- **A live document**
  - Refresh answers on any questions
  - Insert questions in the middle of the transcript and expand with assistant's answers

# Install

## 1. Install the plugin

Snippets for your preferred package manager:

```lua
-- lazy.nvim
{
    "xianxu/parley.nvim",
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
    "xianxu/parley.nvim",
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
Plug 'xianxu/parley.nvim'

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

Expose `OPENAI_API_KEY` env and it should work.

# Usage

## Chat commands

#### `:GpChatNew` <!-- {doc=:GpChatNew}  -->

Open a fresh chat in the current window. `<C-g>c`

#### `:GpChatFinder` <!-- {doc=:GpChatFinder}  -->

Open a dialog to search through chats. `<C-g>f`

#### `:GpChatRespond` <!-- {doc=:GpChatRespond}  -->

Request a new GPT response for the current chat. `<C-g>g`

#### `:GpChatDelete` <!-- {doc=:GpChatDelete}  -->

Delete the current chat. By default requires confirmation before delete, which can be disabled in config using `chat_confirm_delete = false,`. `<C-g>d`

## Agent commands

#### `:GpNextAgent` <!-- {doc=:GpNextAgent}  -->

Cycles between available agents based on the current buffer (chat agents if current buffer is a chat and command agents otherwise). The agent setting is persisted on disk across Neovim instances. `<C-g>d`

## Other commands

#### `:GpStop` <!-- {doc=:GpStop}  -->

Stops all currently running responses and jobs. `<C-g>s`

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
