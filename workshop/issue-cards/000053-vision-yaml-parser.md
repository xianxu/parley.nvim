---
id: '000053'
status: done
created: 2026-04-04
updated: 2026-04-04
actual_hours: N/A
---

# vision YAML parser

## Problem

Parse the list-of-maps YAML format for company vision files into Lua tables. Purpose-built parser for this specific constrained format (follows codebase pattern of `chat_parser.lua`, `issues.lua`).

Multi-file: a vision directory contains multiple YAML files (`sync.yaml`, `px.yaml`). Each file's basename (without `.yaml`) becomes the namespace for its initiatives.

Format per file:

```yaml
- name: Auth Service Rewrite
  type: tech
  size: S
  quarter: Q3
  depends_on: []

- name: Data Platform
  type: tech
  size: XL
  quarter: Q3-Q4
  depends_on: [auth]
```

All fields are strings. `depends_on` is a list of strings (prefix IDs). Parser should be pure functions, no vim dependencies.

Parent: #52
