# Vision YAML Format

## Overview

The vision tracker uses a directory of YAML files to track company initiatives. Each file represents a namespace (e.g., `sync.yaml` → namespace `sync`), and contains a list of initiatives.

## Directory Layout

Two modes, auto-detected:

- **Flat mode**: `vision/*.yaml` files in a single directory (original behavior)
- **Quarterly mode**: `vision/25Q1/`, `vision/25Q2/`, etc. subdirectories. Each quarter folder contains YAML files. The latest quarter overlays on the previous — files with the same name in the current quarter override the base quarter's version. New files in the current quarter are added.

## File Format

Two entity types: **projects** and **persons**.

```yaml
- person: Alice Chen
  capacity: 11w

- project: Auth Service Rewrite
  type: tech
  size: 3m
  start_by: 25Q2
  need_by: 25Q4
  completion: 33
  description: "Bi-directional sync"
  link: "https://notion.so/auth"
  depends_on:
    - data-platform
```

Inline list syntax `depends_on: [auth, data]` is also supported.

## Fields

### Person fields

| Field | Description |
|-------|-------------|
| `person` | Person name (required) |
| `capacity` | Available capacity, e.g. `11w` (weeks) |

### Project fields

| Field | Description |
|-------|-------------|
| `project` | Human-readable project name (required) |
| `type` | Category: `tech`, `business`, or any custom string |
| `size` | Month duration (`3m`, `0.5m`) or T-shirt (`S`=1m, `M`=3m, `L`=6m, `XL`=12m) |
| `start_by` | Structured time: `25Q2` (quarter) or `25M6` (month) |
| `need_by` | Structured time: `25Q4` or `25M12` |
| `completion` | Percent complete, 0-100 |
| `depends_on` | List of ID references (multiline or inline) |

Additional fields (`description`, `link`, etc.) are preserved but not semantically interpreted.

## ID Resolution

- IDs are derived from names: `"Data Platform"` → `data-platform`, `"Self-Serve Onboarding"` → `self-serve-onboarding`
- Full ID includes namespace: `sync:data-platform`
- `depends_on` references use prefix matching:
  - Bare prefix resolves locally first: `auth` → `sync:auth-service-rewrite` (if in sync.yaml)
  - Cross-namespace with `ns:` prefix: `px: mobile` → `px:mobile-app`
  - Exact match preferred over prefix when names overlap: `auth` resolves to `sync:auth` not `sync:auth-v2`
  - Multi-prefix with `...`: `scope ... onprem` matches `scope-deletion-in-onprem-within-a-quarter`
  - Ambiguous or zero matches produce errors

## Typeahead Completion

Auto-triggers as you type in vision YAML files. nvim-cmp is disabled for vision buffers.

### `depends_on` list items

Two-level navigation:

1. **Default view** — bare local project names + namespace prefixes as entry points:
   ```
   mobile-app-v2            Mobile App v2
   self-serve-onboarding    Self-Serve Onboarding
   px:                      local namespace
   sync:                    sync.yaml
   ```
2. **After typing a namespace prefix** (e.g., `sync:`) — expands to that namespace's projects:
   ```
   sync: data-platform          Data Platform
   sync: auth-service-rewrite   Auth Service Rewrite
   ```
3. **Backspace** to remove prefix reverts to the default view.

Supports multi-prefix filtering with `...` (e.g., `some ... 1`).

### `type`, `size`, `start_by`, `need_by` fields

- `type` — `tech`, `business`, plus custom types seen in data
- `size` — `S`, `M`, `L`, `XL`, or month values like `3m`
- `start_by` / `need_by` — existing values from data, sorted

Menu is non-blocking (`noinsert,noselect`) — keep typing to narrow, `<C-y>` to accept.
