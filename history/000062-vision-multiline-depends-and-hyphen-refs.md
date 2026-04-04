---
id: 000062
status: done
deps: [53, 54]
created: 2026-04-04
updated: 2026-04-04
---

# vision: multiline depends_on and hyphenated refs

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

## Done when

- Parser handles multiline `- item` lists under `depends_on` (and any key)
- `name_to_id` uses hyphens instead of underscores, preserves hyphens
- Inline `[...]` syntax still supported for backward compat
- Existing vision YAML files migrated to new format
- All tests updated and passing
- Specs updated

## Plan

- [x] Update `name_to_id` to use hyphens: lowercase, spaces→hyphens, preserve existing hyphens
- [x] Update parser to handle multiline lists (indented `- item` lines under a key)
- [x] Keep inline `[...]` support as fallback
- [x] Update `resolve_ref` normalization to match new ID format
- [x] Update all tests for new ID format (44 vision tests passing)
- [x] Migrate existing vision YAML files (`vision/sync.yaml`, `vision/px.yaml`)
- [x] Update specs (`specs/vision/format.md`)
- [x] Run full test suite — all passing

## Log

### 2026-04-04

- `name_to_id` now produces hyphenated IDs: `"Self-Serve Onboarding"` → `"self-serve-onboarding"`
- Parser supports multiline lists (`- item` under a key with no inline value)
- Inline `[...]` still works as fallback
- Migrated `vision/sync.yaml` and `vision/px.yaml` to multiline format
- Added 3 new parser tests (multiline list, empty multiline, multiline followed by key)
