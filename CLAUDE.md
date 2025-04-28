# CLAUDE.md

## General
This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository. You should first discuss your overall strategy for a user request, before setting out to change code. When fixing bug, you should identify root cause of the bug before attempting fixes. Pay attention particularly to user's description of steps to reproduce the bug, and focus energy to find root course. For example, if the bug only appear in a commit, then you should theorize why that commit would cause issue.

## Project Overview
Parley.nvim is a Neovim plugin that provides a streamlined LLM chat interface with highlighting and navigation features. It supports multiple AI providers (OpenAI, Anthropic, Google AI, Ollama).

## Development Commands
- Manual testing: Start Neovim and use `:lua require('parley').setup()` followed by `:Parley`
- No automated testing infrastructure is currently in place
- Lint: None specified (consider using luacheck or lua-formatter if needed)

## Code Style Guidelines
- Use 4-space indentation consistently
- Follow Lua module pattern with `local M = {}` and `return M`
- Prefer local functions: `local function name()` or `M.name = function()`
- Use descriptive variable and function names (snake_case)
- Wrap Neovim API calls with pcall for error handling
- Prefer vim.api for Neovim API calls
- Use local variables to avoid polluting global namespace
- Use multi-line strings with `[[...]]` syntax for templates
- Document functions with inline comments explaining purpose and parameters
- Follow existing patterns for config handling and error messaging

## Architecture Notes
- Config is handled through `/lua/parley/config.lua`
- Logging through `/lua/parley/logger.lua`
- UI rendering in `/lua/parley/render.lua`
- LLM connections managed in dispatcher and provider-specific modules
