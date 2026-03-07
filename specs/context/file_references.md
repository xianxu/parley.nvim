# Spec: File References (@@)

## Overview
Parley's `@@` syntax allows including local file or directory contents directly in LLM prompts.

## Syntax Rules
- **Single File**: `@@/path/to/file.txt` (absolute, relative, or home-relative).
- **Directory**: `@@/path/to/dir/` (all files in a directory, non-recursive).
- **Glob Pattern**: `@@/path/to/dir/*.lua`.
- **Recursive Directory**: `@@/path/to/dir/**/`.
- **Recursive Glob**: `@@/path/to/dir/**/*.lua`.

## Inline and Block Usage
- Reference can be at the start of a line or inline within text.
- `review @@./file.lua and improve it`.

## Content Loading
- Files are loaded, prepended with their filename and line numbers.
- Large directories or files MUST be handled gracefully (e.g., within reasonable token limits).

## Interactivity
- `<C-g>o`: Open the file or directory under the cursor.
- If it's a file, it opens in a buffer.
- If it's a directory, it opens the file explorer.

## Memory Preservation
- Exchanges containing `@@` file references MUST be preserved in full (NOT summarized) during memory management.
