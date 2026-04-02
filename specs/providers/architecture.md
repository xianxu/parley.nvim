# Provider Architecture

- Transport: `curl` subprocess (no Lua HTTP deps). OpenAI-compatible adapters share payload format and SSE parsing; differ in headers/endpoints.
- CLIProxyAPI dynamically selects OpenAI or Anthropic behavior based on strategy and model family.
- Query cache in `query_dir`; pruned at >200 files.
