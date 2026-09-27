---
id: 000151
status: open
created: 2026-06-29
updated: 2026-06-29
estimate_hours:
github_issue:
---

# local browser-backed web fetch tool

## Problem

Parley has two context paths today:

- `@@...@@` references are resolved locally before submit and embedded into the model request as content snapshots.
- Agent tool calls can read local filesystem paths, while URL fetching is mostly provider-side web search/fetch when the selected provider supports it.

The missing capability is a local web-fetch tool for URLs reachable from Parley chat. Provider-side fetch cannot see pages that require the user's local authenticated browser session: SSO docs, paywalled pages, private dashboards, local dev apps, and sites where login/navigation must happen interactively.
