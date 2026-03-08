# Spec: Anthropic Provider

## Overview
Anthropic's provider for Claude Sonnet, Haiku, and Opus models.

## Endpoint
- Default: `https://api.anthropic.com/v1/messages`.

## Payload Structure
- `model`: Model name string.
- `stream`: `true`.
- `messages`: List of `{role, content}` objects.
- `system`: Array of content blocks extracted from system messages.
- `max_tokens`: Configurable; defaults to `4096`.
- `temperature`: Clamped to `[0, 1]`.
- `top_p`: Clamped to `[0, 1]`.

### Web Search & Fetch Tools
- Appended if `web_search` is active.
- `web_search`: `type: web_search_20260209`.
- `web_fetch`: `type: web_fetch_20260209`.
- Model capability override: `claude-haiku-4-5*` MUST set `allowed_callers: ["direct"]` on both web tools.

## Headers
- `x-api-key: <secret>`.
- `anthropic-version: 2023-06-01`.
- `anthropic-beta`: `messages-2023-12-15` or `web-fetch-2025-09-10`.

## Content Extraction
- From `delta.text` and `content_block.text` from the SSE stream.
- Metrics: `input_tokens`, `output_tokens`, `cache_read_input_tokens`.
