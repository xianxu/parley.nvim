<!-- panvimdoc-ignore-start -->

<a href="https://github.com/xianxu/parley.nvim/blob/main/LICENSE"><img alt="GitHub" src="https://img.shields.io/github/license/xianxu/parley.nvim"></a>

# Parley.nvim - Streamlined Chat Plugin for Neovim

<!-- panvimdoc-ignore-end -->

<br>

**ChatGPT-like sessions with highlighting and navigation, focused on simplicity and readability.** 


# Goals and Features

Parley is a streamlined LLM chat plugin for NeoVIM, focusing exclusively on providing a clean and efficient interface for conversations with AI assistants. Imagine having full transcript of a chat session with ChatGPT (or Anthropic, or Gemini) that allows editing of all questions, and answers themselves! I created this as a way to construct research report, improve my understanding of new topics. It's a researcher's notebook.

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
  - Just good old neovim buffers formatted as markdown with autosave
  - Chat finder - management pop-up for searching, previewing, deleting and opening chat sessions
- **A live document**
  - Refresh answers on any questions
  - Insert questions in the middle of the transcript and expand with assistant's answers
  - You have the full NeoVIM behind you.

# The Format of Text

Each chat transcript is really just a markdown file, with some conventions. 

1. Questions and answers take turn. 
2. A question is a line prefixed by 💬:, and all following lines until next answer.
3. An Answer is a line prefixed by 🤖:, and all following lines until next question.
4. Two special lines in answer section, one is for assistant's reasoning output, prefixed with 🧠:. The other is for summary of one chat exchange prefixed with 📝:.
    1. We kept those two lines in the transcript itself for simplicity really, so that one transcript file's hermetic.

With this, any question asked is associated with context of all questions and answers coming before this question. When the chat gets too long and the chat_memory is enabled, chat exchanges earlier in the transcript will be represented by the summary line (📝:).

## Interaction
Place cursor in the question area, and `<C-g>g`, to ask assistant about it. If the question is at the end of document, it's a new question. Otherwise, a previously asked question is asked again, and previous answer replaced by new answers. You might want to do this, for example, if upon learning, you tweaks your questions more precisely. 

Because you can update previous questions and even assistant's answers, the answers of future questions, re-asked or not, will be different, subtly influenced by all those. After all, we are dealing with a statistical machine here.

The 🧠:, 📝: are done through system prompt. It seems to work fine, but there's no guarantee. If assistant omitted those lines, you can update the question to include: "remember to reply 🧠: lines for your reasoning, and 📝: for your summary". Something like that.

## Manual Curation
The transcript is really just a text document. So long you maintain the 💬:, 🤖:, 🧠:, 📝: pattern, things would work. You are free to edit any text in this transcript. For example, adding headings `#` and `##` to group your questions sections, which shows up in Table of Content with `<C-g>t`.

You are free to put bold on text, as a marker so you can remember things easier. The whole thing is markdown format, so you can use `backtick`, or [link], or **bold**, each having different visual effect. I may add some customized highlighter, just to make certain text jumping out.

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
        require("parley").setup(conf)

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
        require("parley").setup(conf)

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
require("parley").setup(conf)

-- Setup shortcuts here (see Usage > Shortcuts in the Documentation/Readme)
```

## 2. OpenAI API key

Make sure you have OpenAI API key. [Get one here](https://platform.openai.com/account/api-keys) and use it in the [4. Configuration](#4-configuration). Also consider setting up [usage limits](https://platform.openai.com/account/billing/limits) so you won't get surprised at the end of the month.

The OpenAI API key can be passed to the plugin in multiple ways:

| Method                    | Example                                                        | Security Level      |
| ------------------------- | -------------------------------------------------------------- | ------------------- |
| hardcoded string          | `openai_api_key: "sk-...",`                                    | Low                 |
| default env var           | set `OPENAI_API_KEY` environment variable in shell config      | Medium              |
| custom env var            | `openai_api_key = os.getenv("CUSTOM_ENV_NAME"),`               | Medium              |
| read from file            | `openai_api_key = { "cat", "path_to_api_key" },`               | Medium-High         |
| password manager          | `openai_api_key = { "bw", "get", "password", "OAI_API_KEY" },` | High                |

If `openai_api_key` is a table, Parley runs it asynchronously to avoid blocking Neovim (password managers can take a second or two).

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

Expose `OPENAI_API_KEY` env and it should work. Otherwise copy `lua/parley/config.lua` to your `~/.config/nvim/lua/parley/` and update.

# Usage

All commands can be configured in `config.lua`.

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

Cycles between available agents based on the current buffer (chat agents if current buffer is a chat and command agents otherwise). The agent setting is persisted on disk across Neovim instances. `<C-g>a`

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

To take advantage of this feature, instruct your LLM in the system prompt to include summaries of the conversation. For example the following, or check defaults.lua for details, which is already included as default. If LLM is not good at following after a long session, you can add those to your question to refresh its memory.

```
When thinking through complex problems, prefix your reasoning with 🧠: for clarity.
After answering my question, please include a brief summary of our exchange prefixed with 📝:
```

When the chat grows beyond the configured limit, the plugin will automatically replace older messages with the extracted summaries.

# Acknowledgement

This was adapted from [gp.nvim](https://github.com/Robitx/gp.nvim). I decided to fork as I wanted a simple transcript tool to talk to LLM providers.
