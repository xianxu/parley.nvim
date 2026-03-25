# Spec: File References (@@)

## Overview
Parley's `@@` syntax allows including local file or remote URL contents directly in LLM prompts.

## Syntax Rules
**Canonical form:** `@@<ref>@@` — explicit open and close markers.

Supported `<ref>` types:
- `@@https://...@@` — remote URL
- `@@/absolute/path@@` — absolute path
- `@@~/home/relative@@` — home-relative path (`~` is expanded)
- `@@./relative/path@@` — explicitly relative path

Dropped forms (no longer supported):
- `@@path: topic` colon syntax
- Bare filenames (`@@name.lua`) — too ambiguous
- End-at-whitespace shorthand

## Inline and Block Usage
- Reference can appear anywhere inline within text.
- `review @@./file.lua@@ and improve it`.
- Chat file references use the same form: `@@2026-03-24.12-34-56.123.md@@`.

## Content Loading
- Files are loaded, prepended with their filename and line numbers.
- Large directories or files MUST be handled gracefully (e.g., within reasonable token limits).

## Chat Reference Rendering
- When a markdown `@@...@@` or leading `@@...` reference resolves to a valid chat transcript, Parley SHOULD render it with the chat topic for readability, for example `@@2026-03-24.12-34-56.123.md: Topic@@`.
- Non-chat file references MUST keep their original rendered text.

## Interactivity
- `<C-g>o`: Open the file or directory under the cursor.
- If it's a file, it opens in a buffer.
- If it's a directory, it opens the file explorer.

## Memory Preservation
- Exchanges containing `@@` file references MUST be preserved in full (NOT summarized) during memory management.
