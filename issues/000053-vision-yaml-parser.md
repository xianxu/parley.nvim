---
id: 000053
status: done
deps: []
created: 2026-04-04
updated: 2026-04-04
---

# vision YAML parser

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

## Done when

- Parser converts a single YAML file into a Lua table of initiative maps
- `load_vision_dir(dir)` loads all `.yaml` files, tagging each initiative with its namespace
- Handles: string values, inline lists `[a, b]`, empty lists `[]`
- Graceful errors on malformed input with file/line context
- Unit tests pass

## Plan

- [x] Create `lua/parley/vision.lua` with `parse_vision_yaml(text)` function
- [x] Handle `- name:` as item delimiter
- [x] Handle `key: value` pairs within each item
- [x] Handle `depends_on: [a, b, c]` inline list syntax
- [x] Implement `load_vision_dir(dir)` — scan `*.yaml`, parse each, attach namespace from filename
- [x] Add unit tests in `tests/unit/vision_spec.lua` (8 tests)

## Log

### 2026-04-04

