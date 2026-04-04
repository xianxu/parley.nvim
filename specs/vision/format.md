# Vision YAML Format

## Overview

The vision tracker uses a directory of YAML files to track company initiatives. Each file represents a namespace (e.g., `sync.yaml` → namespace `sync`), and contains a list of initiatives.

## File Format

```yaml
# Each file is a list of initiative maps
- project: Auth Service Rewrite
  type: tech
  size: S
  need_by: Q3
  depends_on:

- project: Data Platform
  type: tech
  size: XL
  need_by: Q3-Q4
  depends_on:
    - auth
```

Inline list syntax `depends_on: [auth, data]` is also supported.

## Fields

All fields are strings. No strict typing — evolved incrementally.

| Field | Description |
|-------|-------------|
| `project` | Human-readable project name (required) |
| `type` | Category: `tech`, `business`, or any custom string |
| `size` | T-shirt size: `S`, `M`, `L`, `XL` (used for graph node sizing) |
| `need_by` | Timing, free-form string (e.g., `Q3`, `Q3-Q4`, `late Q3`) |
| `depends_on` | List of ID references (multiline or inline) |

Additional fields are preserved but not semantically interpreted.

## ID Resolution

- IDs are derived from names: `"Data Platform"` → `data-platform`, `"Self-Serve Onboarding"` → `self-serve-onboarding`
- Full ID includes namespace: `sync:data-platform`
- `depends_on` references use prefix matching:
  - Bare prefix resolves locally first: `auth` → `sync:auth-service-rewrite` (if in sync.yaml)
  - Cross-namespace with `ns:` prefix: `px: mobile` → `px:mobile-app`
  - Exact match preferred over prefix when names overlap: `auth` resolves to `sync:auth` not `sync:auth-v2`
  - Multi-prefix with `...`: `scope ... onprem` matches `scope-deletion-in-onprem-within-a-quarter`
  - Ambiguous or zero matches produce errors
