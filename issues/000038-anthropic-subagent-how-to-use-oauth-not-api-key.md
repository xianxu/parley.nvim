---
id: 000038
status: done
deps: []
created: 2026-03-30
updated: 2026-03-30
---

# anthropic subagent how to use oauth not API key

## Done when

- Subagent uses OAuth instead of API key

## Plan

- [x] Unset ANTHROPIC_API_KEY environment variable so Claude Code falls back to OAuth

## Log

### 2026-03-30

Resolved by unsetting the ANTHROPIC_API_KEY env variable. When the API key is not set, Claude Code uses OAuth authentication instead.
