# Architecture

## Project Overview
Parley.nvim is a Neovim plugin that provides a streamlined LLM chat interface with highlighting and navigation features. It supports multiple AI providers (OpenAI, Anthropic, Google AI, Ollama).

## Key Modules
- `lua/parley/init.lua` — entry point, command registration, keybindings
- `lua/parley/chat_parser.lua` — parses chat transcript format (headers, exchanges, file refs)
- `lua/parley/chat_respond.lua` — orchestrates LLM request/response lifecycle
- `lua/parley/providers.lua` — provider abstraction (OpenAI, Anthropic, GoogleAI, Ollama)
- `lua/parley/exporter.lua` — HTML and Markdown export
- `lua/parley/highlighter.lua` — syntax highlighting and decoration
- `lua/parley/notes.lua` — note management
- `lua/parley/config.lua` — configuration defaults and merging

## Specs
Detailed feature specs live in `../specs/`. See `specs/index.md` for an index.
