# Agents

- An agent = provider + model + system prompt
- Config fields: `name`, `provider`, `model` (string or object), `system_prompt`, `disable` (bool), `tools` (list of builtin tool names — or group sentinels `@all` / `@readonly`, see `providers/tool_use.md` — for client-side tool use; empty/absent = no tools; #81, anthropic-family only at present), `max_tool_iterations` (default 42, single-sourced in `defaults.lua`), `tool_result_max_bytes` (default 102400)
- Default agents: GPT5.4 (openai), Claude-Sonnet (anthropic), ToolSonnet (anthropic, all 7 builtin tools), ToolOpus (anthropic, all 7 builtin tools), Gemini2.5-Pro (googleai), `ToolOpus*` (cliproxyapi), `Claude-Opus` (cliproxyapi/code_execution_20260120)
- `Proxy-*` variants included for all major model families via cliproxyapi
- Selection: `:ParleyAgent [name]` (picker or explicit), `:ParleyNextAgent` (`<C-g>a`) cycles
- **Live cliproxy models (#205).** Below the configured agents the picker shows a
  `── live · cliproxy ──` section built from the proxy's own catalog, so a model
  never has to be written into `config.lua` to be usable. Rows read
  `Claude Opus 5 - claude-opus-5 (anthropic)` — the same `<name> - <model>` shape
  the configured rows above use, and once picked a model leaves the live section
  so it never shows twice; picking one registers a
  cliproxyapi agent named `<id>*` with `@all` tools and the web-search strategy
  its family supports, and persists it (`_state.live_agent`) so it survives a
  restart. `<C-a>` toggles the whole catalog, bypassing both the configured
  filter and the per-provider curation — curation decides the default view, never
  what is reachable. A configured provider the catalog advertises nothing for
  renders as `antigravity - (logged out)`; selecting it runs `:ParleyProxy login`.
  Which providers appear, and how many models each contributes, comes from
  `cliproxy.live_models` — see providers/cliproxy-managed.md.
- Persisted to `state_dir/last_agent`
- Virtual text on first chat line: `[AgentName]`. Indicator badges render as a single `[...]` group appended after the name: `🔧` when `tools` is non-empty, `🌎` when web_search is enabled and supported (`🌎?` when unsupported). Combined example: `ToolSonnet[🔧🌎]`. Helpers `highlighter.agent_tool_badge` / `agent_web_search_badge` are the single source, shared by picker, lualine, and the buffer-top extmark.
