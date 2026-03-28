# Provider Architecture

- Transport: `curl` subprocess with `--no-buffer -s`, payload via temp file (`-d @<file>`), global `curl_params` appended
- Payload: `{role, content}` messages, `model`, `temperature`, `top_p`, `max_tokens`/`max_completion_tokens`; streaming always enabled
- OpenAI-compatible adapters (OpenAI/Copilot/Azure/Ollama/CLIProxyAPI) share payload format and SSE parsing; differ in headers/endpoints
- CLIProxyAPI dynamically selects OpenAI-compatible or Anthropic-compatible behavior based on strategy and model family
- Query cache in `query_dir`; prune at >200 files; delete temp files after request completion
- Errors: line-by-line stream parsing; empty/HTTP errors trigger logger error + user notification
