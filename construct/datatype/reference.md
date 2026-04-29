---
type: reference
name: reference
description: Use when the user wants to capture evergreen, non-time-sensitive information they'll come back to — vendors, contacts, lists, a curated set of items. Triggers on "save this list", "remember these contractors", "track our family doctors", etc.
---

# reference

Evergreen, mostly-static information the user will read repeatedly and edit occasionally. Not pinned to a moment in time, not a procedure to follow, not a project. Lists, tables, curated sets of items, contact records, glossaries.

## Frontmatter shape

| Field | Required | Notes |
|---|---|---|
| `type` | yes | `reference` |
| `topic` | yes | Short phrase identifying what this references (e.g., "home contractors", "family doctors"). |
| `last-reviewed` | no | ISO date the user last confirmed the content is still accurate. Useful for things that go stale (phone numbers, hours). |

## Body skeleton

1. `# <Topic>` — title.
2. **One-line lede** — what's in this file and when to use it.
3. The reference content itself, shaped to match the data: bulleted list, markdown table, sub-headings per item, etc. Pick the shape that's quickest to scan, not the most "formal."
4. **Notes** (optional) — caveats, edge cases, things the user wishes they'd remembered last time.

No fixed section count beyond the lede — references are heterogeneous by nature.

## Authoring instructions

When the dispatcher applies this prototype:

1. Pull items mentioned in the conversation. Don't ask the user to re-list things they just said.
2. Pick the shape based on the data:
   - **Table** when items have parallel attributes (name + phone + notes).
   - **Bulleted list** when items are mostly names or one-liners.
   - **Sub-headings** when each item warrants a paragraph.
3. **Default location:** under a `memory/` directory if one exists, in a subdirectory whose name reflects the *category*, not the *topic*. E.g., `memory/life/contractors/` for a list of contractors, not `memory/contractors-list/`. Run `find memory -type d` first; if a fitting subdirectory exists, use it; otherwise propose 1–2.
4. Filename: kebab-case slug of the topic.
5. Don't add `last-reviewed` unless the data is the kind that goes stale.

## Search recipes

```sh
# All references
rg -l "^type: reference"

# References mentioning a specific term (matches topic and body)
rg -l "^type: reference" | xargs rg -l -i "plumber"

# References by topic prefix
rg -l "^type: reference" | xargs rg -l "^topic: contractors"

# Stale references (not reviewed since 2025)
rg -l "^type: reference" | xargs rg -L "^last-reviewed: 2026"

# References that have never been reviewed
rg -L "^last-reviewed:" $(rg -l "^type: reference")
```
