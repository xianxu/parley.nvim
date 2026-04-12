# Agents

- An agent = provider + model + system prompt
- Config fields: `name`, `provider`, `model` (string or object), `system_prompt`, `disable` (bool), `tools` (list of builtin tool names for client-side tool use — #81, anthropic-family only at present), `max_tool_iterations` (default 20), `tool_result_max_bytes` (default 102400)
- Default agents: GPT5.4 (openai), Claude-Sonnet (anthropic), ToolSonnet (anthropic, all 6 builtin tools), ToolOpus (anthropic, all 6 builtin tools), Gemini2.5-Pro (googleai), Proxy-GPT5.4 (cliproxyapi), Claude-Code (cliproxyapi/code_execution_20260120)
- `Proxy-*` variants included for all major model families via cliproxyapi
- Selection: `:ParleyAgent [name]` (picker or explicit), `:ParleyNextAgent` (`<C-g>a`) cycles
- Persisted to `state_dir/last_agent`
- Virtual text on first chat line: `[AgentName]`. Indicator badges render as a single `[...]` group appended after the name: `🔧` when `tools` is non-empty, `🌎` when web_search is enabled and supported (`🌎?` when unsupported). Combined example: `ToolSonnet[🔧🌎]`. Helpers `highlighter.agent_tool_badge` / `agent_web_search_badge` are the single source, shared by picker, lualine, and the buffer-top extmark.
