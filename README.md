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
  - Referencing other local files, for example, to get critics for that file and ask questions about them, essentially adding context.

# The Format of the Transcript

Each chat transcript is really just a markdown file, with some additional conventions. So think them as markdown files with benefits (of Parley).

1. There is a header section that contains metadata and can override configuration parameters:
   - Standard metadata like `file: filename.md` (required)
   - Model information like `model: {"model":"gpt-4o","temperature":1.1,"top_p":1}`
   - Provider information like `provider: openai`
   - Configuration overrides like `max_full_exchanges: 20` to customize behavior for this specific chat (controls how many full exchanges to keep before summarizing)
2. User's questions and Assistant's answers take turns.
3. A question is a line starting with 💬:, and all following lines until next answer.
4. An Answer is a line starting with 🤖:, and all following lines until next question.
5. Two special lines in answers. Those are states maintained by Parley, and not designed for human consumption. They are grayed out by default.
    1. The first is the Assistant's reasoning output, prefixed with 🧠:. 
	2. The second is the summary of one chat exchange prefixed with 📝:, in the format of "you asked ..., I answered ...".
    3. We keep those two lines in the transcript itself for simplicity, so that one transcript file's hermetic.
6. File and directory inclusion: a line that starts with @@ followed by a path will automatically load content into the prompt when sending to the LLM. This works in several ways:

   - `@@/path/to/file.txt` - Include a single file
   - `@@/path/to/directory/` - Include all files in a directory (non-recursive)
   - `@@/path/to/directory/*.lua` - Include all matching files in a directory (non-recursive)
   - `@@/path/to/directory/**/` - Include all files in a directory and its subdirectories (recursive)
   - `@@/path/to/directory/**/*.lua` - Include all matching files in a directory and its subdirectories (recursive)

   You can open referenced files or directories directly by placing the cursor on the line with the @@ syntax and pressing `<C-g>o`. For directories or glob patterns, this will open the file explorer. Use this feature when you want LLM to help you understand, debug, or improve existing code.

With this, any question asked is associated with context of all questions and answers coming before this question. When the chat gets too long and the chat_memory is enabled, chat exchanges earlier in the transcript will be represented by the concatenation of their summary lines (📝:).

## Interaction

Place cursor in the question area, and `<C-g>g`, to ask assistant about it. If the question is at the end of document, it's a new question. Otherwise, a previously asked question is asked again, and previous answer replaced by the new answer. You might want to do this, for example, if upon learning, you tweaks your questions. Or you updated referenced file (with the `@@` syntax).

If you see a message saying "Another Parley process is already running", you can either:
1. Use `<C-g>s` to stop the current process and then try again
2. Add a `!` at the end of the command (`:ParleyChatRespond!`) to force a new response even if a process is running

For more extensive revisions, you can place the cursor on a question and use `<C-g>G` to resubmit all questions from the beginning of the chat up to and including the current question. Each question will be processed in sequence, with responses replacing the existing answers at their correct positions. This is particularly useful when you've edited multiple previous questions, and/or referenced files and want to update all previously asked questions.

During the resubmission, a visual indicator will highlight each question as it's being processed, and notifications will display progress. You can stop the resubmission at any time with the stop shortcut (`<C-g>s`). When complete, the cursor will return to your original position.

Because you can update previous questions and even assistant's answers, the answers of future questions, will be different, subtly influenced by all those. After all, we are dealing with a `large scale statistical machine` here.

The 🧠:, 📝: are done through system prompt. It seems to work fine, but there's no guarantee. If assistant omitted those lines, you can update the question to reinforce it: "remember to reply with 🧠: lines for your reasoning, and 📝: for your summary". Something like that.

## Manual Curation
The transcript is really just a text document. So long the 💬:, 🤖:, 🧠:, 📝: pattern is maintained, things would work. You are free to edit any text in this transcript. For example, adding headings `#` and `##` to group your questions sections, which shows up in Table of Content with `<C-g>t`.

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
			-- Typically you should override the api_keys, e.g. if you are using Mac Keychain to store API keys.
            -- Use the following to add api keys to Mac Keychain.
	        -- security add-generic-password -a "your_username" -s "OPENAI_API_KEY" -w "your_api_key" -U
			api_keys = {
                openai = { "security", "find-generic-password", "-a", "your_username", "-s", "OPENAI_API_KEY", "-w" },
                anthropic = { "security", "find-generic-password", "-a", "your_username", "-s", "ANTHROPIC_API_KEY", "-w" },
                googleai = { "security", "find-generic-password", "-a", "your_username", "-s", "GOOGLEAI_API_KEY", "-w" },
                ollama = "dummy_secret",
            },

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
			-- Typically you should override the api_keys, e.g. if you are using Mac Keychain to store API keys.
            -- Use the following to add api keys to Mac Keychain.
	        -- security add-generic-password -a "your_username" -s "OPENAI_API_KEY" -w "your_api_key" -U
			api_keys = {
                openai = { "security", "find-generic-password", "-a", "your_username", "-s", "OPENAI_API_KEY", "-w" },
                anthropic = { "security", "find-generic-password", "-a", "your_username", "-s", "ANTHROPIC_API_KEY", "-w" },
                googleai = { "security", "find-generic-password", "-a", "your_username", "-s", "GOOGLEAI_API_KEY", "-w" },
                ollama = "dummy_secret",
            },
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
	-- Typically you should override the api_keys, e.g. if you are using Mac Keychain to store API keys.
    -- Use the following to add api keys to Mac Keychain.
    -- security add-generic-password -a "your_username" -s "OPENAI_API_KEY" -w "your_api_key" -U
	api_keys = {
        openai = { "security", "find-generic-password", "-a", "your_username", "-s", "OPENAI_API_KEY", "-w" },
        anthropic = { "security", "find-generic-password", "-a", "your_username", "-s", "ANTHROPIC_API_KEY", "-w" },
        googleai = { "security", "find-generic-password", "-a", "your_username", "-s", "GOOGLEAI_API_KEY", "-w" },
        ollama = "dummy_secret",
    },
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

# Customizing Appearance

Parley is designed to work well with all color schemes while providing clear visual distinction between different elements.

## Default Highlighting

By default, Parley links its highlight groups to common built-in Neovim highlight groups:

- Questions (user messages): Linked to `Keyword` - stands out in most themes
- File references (@@filename): Linked to `WarningMsg` - clearly visible in all themes
- Thinking/reasoning lines (🧠:): Linked to `Comment` - appropriately dimmed in most themes
- Annotations (@...@): Linked to `DiffAdd` - typically has a subtle background color

## Custom Highlighting

You can customize these highlight groups by adding a `highlight` section to your configuration:

```lua
highlight = {
    -- Override with your own highlight settings
    question = { fg = "#ffaf00", italic = true },         -- Orange text for questions
    file_reference = { fg = "#ffffff", bg = "#5c2020" },  -- White text on red for file refs
    thinking = { fg = "#777777" },                        -- Gray text for reasoning lines
    annotation = { bg = "#205c2c", fg = "#ffffff" },      -- White text on green background
},
```

Each field is optional - set only the ones you want to customize and leave the others as `nil`.

# Lualine Integration

Parley includes built-in integration with lualine, allowing you to display the current agent in your statusline when working with chat buffers.

## Configuration

The lualine integration can be configured in your setup:

```lua
lualine = {
    -- enable lualine integration
    enable = true,
    -- which section to add the component to
    section = "lualine_x",
},
```

## How It Works

1. When working in a chat buffer, the lualine component will show the current agent
2. The component will only appear when you're in a chat buffer
3. The integration automatically registers itself with lualine if enabled

To set this up, no additional configuration is needed beyond enabling it in your Parley config.

## Manual Integration

You can also manually add the Parley component to your lualine configuration if you need more control:

```lua
-- In your lualine setup
require('lualine').setup {
  sections = {
    lualine_x = {
      -- Other components...
      require('parley.lualine').create_component(),
    }
  }
}
```

This is useful if you want to position the component precisely within your statusline configuration.

# Acknowledgement

This was adapted from [gp.nvim](https://github.com/Robitx/gp.nvim). I decided to fork as I wanted a simple transcript tool to talk to LLM providers.
