# Agents

- An agent = provider + model + system prompt
- Config fields: `name`, `provider`, `model` (string or object), `system_prompt`, `disable` (bool)
- Default agents: GPT5.4 (openai), Claude-Sonnet (anthropic), Gemini2.5-Pro (googleai), Proxy-GPT5.4 (cliproxyapi), Claude-Code (cliproxyapi/code_execution_20260120)
- `Proxy-*` variants included for all major model families via cliproxyapi
- Selection: `:ParleyAgent [name]` (picker or explicit), `:ParleyNextAgent` (`<C-g>a`) cycles
- Persisted to `state_dir/last_agent`
- Virtual text on first chat line: `[AgentName]`; Anthropic w/ web search appends `[w]`
