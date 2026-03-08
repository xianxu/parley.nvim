# Spec: Agents

## Overview
An agent combines a provider, a model, and a system prompt.

## Configuration
- `name`: Unique identifier for the agent.
- `provider`: Reference to the provider key (e.g., `openai`, `anthropic`).
- `model`: JSON object or string with model parameters.
- `system_prompt`: Initial prompt defining assistant behavior.
- `disable`: Set to `true` to exclude the agent from the active set.

## Default Agents
| Agent | Provider | Model |
|---|---|---|
| GPT5.4 | openai | gpt-5.4 |
| Claude-Sonnet | anthropic | claude-sonnet-4-6 |
| Gemini2.5-Pro | googleai | gemini-2.5-pro |
| Proxy-GPT5.4 | cliproxyapi | gpt-5.4 |
| Claude-Code | cliproxyapi | code_execution_20260120 |

Default config includes `Proxy-*` variants for major model families through `cliproxyapi`.

## Agent Selection
- `:ParleyAgent [name]`: Selects an agent via Telescope picker or name argument.
- `:ParleyNextAgent` (`<C-g>a`): Cycles to the next available agent.
- Persisted selection to `state_dir/last_agent`.

## Virtual Text Integration
- In chat buffers, the current agent MUST be displayed as virtual text on the first line: `[AgentName]`.
- Anthropic agents with web search MUST append `[w]`.
