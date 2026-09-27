---
id: '000062'
status: done
created: 2026-04-04
updated: 2026-04-04
actual_hours: N/A
---

# vision: multiline depends_on and hyphenated refs

## Problem

Simplify the vision YAML format:

1. **Multiline `depends_on`** — replace inline `[a, b]` with standard YAML multiline list
2. **Hyphenated refs** — ref is just `lowercase(name)` with spaces replaced by hyphens

Before:
```yaml
- name: Self-Serve Onboarding
  depends_on: [auth, data-platform]
```

After:
```yaml
- name: Self-Serve Onboarding
  depends_on:
    - auth-service
    - data-platform
```

Ref ↔ name: `"Self-Serve Onboarding"` → `"self-serve-onboarding"`

Parent: #52
