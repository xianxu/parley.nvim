# Spec: Provider Architecture

## Overview
Parley's provider architecture manages communication with LLM backends using a unified interface.

## Transport Layer
Requests are sent via a `curl` subprocess.
- `--no-buffer` and `-s` (silent) flags.
- `Content-Type: application/json`.
- Payload is passed through a temporary file via `-d @<file>`.
- Any `curl_params` from global config are appended.

## Payload Construction
The dispatcher module builds API payloads for different providers.
- **Messages**: Conversation history as `{role, content}`.
- **Parameters**: `model`, `temperature`, `top_p`, `max_tokens` (or `max_completion_tokens`).
- **Streaming**: All requests MUST enable streaming.

## Query Cache Management
- Queries are saved in `query_dir`.
- Cleanup occurs periodically (e.g., pruning when > 200 files).
- Temporary files MUST be deleted after successful request completion.

## Error Handling
- Response streams are parsed line by line.
- Empty responses or HTTP errors trigger a logger error and user notification.
