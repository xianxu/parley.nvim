# Vision YAML Format

## Overview

The vision tracker uses a directory of YAML files to track company initiatives. Each file represents a namespace (e.g., `sync.yaml` → namespace `sync`), and contains a list of initiatives.

## File Format

```yaml
# Each file is a list of initiative maps
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

## Fields

All fields are strings. No strict typing — evolved incrementally.

| Field | Description |
|-------|-------------|
| `name` | Human-readable initiative name (required) |
| `type` | Category: `tech`, `business`, or any custom string |
| `size` | T-shirt size: `S`, `M`, `L`, `XL` (used for graph node sizing) |
| `quarter` | Timing, free-form string (e.g., `Q3`, `Q3-Q4`, `late Q3`) |
| `depends_on` | Inline YAML list of ID references |

Additional fields are preserved but not semantically interpreted.

## ID Resolution

- IDs are derived from names: `"Data Platform"` → `data_platform`
- Full ID includes namespace: `sync.data_platform`
- `depends_on` references use prefix matching:
  - Bare prefix resolves locally first: `auth` → `sync.auth_rewrite` (if in sync.yaml)
  - Namespaced prefix resolves globally: `px.mobile` → `px.mobile_app`
  - Ambiguous or zero matches produce errors
