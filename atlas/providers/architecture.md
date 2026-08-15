# Provider Architecture

- Transport: `curl` subprocess (no Lua HTTP deps). OpenAI-compatible adapters share payload format and SSE parsing; differ in headers/endpoints. Note that "OpenAI-compatible" does not mean "delegates to `openai.format_payload`": cliproxyapi's openai route (`cliproxy_openai_payload`) and `ollama` each build their own payload, and only `copilot` and `azure` delegate — so anything that must apply to every openai-shaped request belongs at `dispatcher.prepare_payload`, the single point upstream of all of them.
- SSE line primitives (`safe_json_decode`, `strip_data_prefix`) live in `lua/parley/sse.lua`, shared by the adapters and the [tool wires](tool_use.md).
- CLIProxyAPI dynamically selects OpenAI or Anthropic behavior based on strategy and model family.
- Query cache in `query_dir`; pruned at >200 files.
