# Spec: Inline Branch Links

## Overview
Inline branch links embed child chat references within the text of a question or answer, as opposed to full-line `🌿:` links which occupy their own line. They provide a footnote-like experience for quickly branching into terminology or sub-topic explorations.

## Syntax
`[🌿:display text](file.md)` — appears inline within any line of a chat transcript.

Coexists with full-line `🌿: file.md: topic` syntax. Full-line links are for branch points between or after exchanges. Inline links are for footnote-style references within text.

## Creation Workflow
1. User visually selects text anywhere in the chat buffer (question, answer, or other text).
2. Presses `<C-g>i`.
3. The selected text is replaced with `[🌿:selected text](new-file.md)`.
4. A new child chat file is created with:
   - `topic: what is "selected text"`
   - `🌿:` parent link back to the current file
   - `💬: what is "selected text"?` as the first question
5. Since the topic is not `?`, no automatic topic inference runs.
6. User can `<C-g>o` on the inline link to open the child and trigger the response.

Note: `<C-g>i` in normal mode (no selection) retains existing behavior — inserts a full-line `🌿:` reference.

## Parser Behavior
- `parse_chat` detects `[🌿:...](...)` patterns within lines.
- Each match is added to `parsed.branches` with the same fields as full-line branches: `{ path, topic, line, after_exchange }`.
- The `topic` is the display text between `[🌿:` and `]`.
- The `path` is the file reference between `(` and `)`.
- **Context unpacking**: when building LLM context, `[🌿:text](file.md)` is replaced with just `text`. The link is transparent to the LLM.
- The line containing an inline link is NOT excluded from exchange content (unlike full-line `🌿:` which excludes the entire line).

## Navigation
- `<C-g>o` on an inline link opens the referenced file, same as full-line `🌿:` links.
- Cursor must be positioned on or within the `[🌿:...](...) ` span.

## In-Buffer Display
- The inline link text is highlighted/decorated to visually indicate it's a branch reference (e.g., underline, distinct highlight group).
- The `🌿:` prefix and `(file.md)` portion may be concealed, showing only the display text as a styled link.

## Export

### HTML
- Rendered as `<a href="child.html" class="branch-inline">display text</a>` inline within the surrounding text.

### Markdown (Jekyll)
- Rendered as `<a href="{% post_url slug %}" class="branch-inline">display text</a>` inline.

## Tree Discovery
- Inline branch links are included in tree traversal (`collect_tree`, `find_tree_root`) alongside full-line links.
- `build_link_map` and collision detection apply to inline-linked files the same way.

## Edge Cases
- Multiple inline links on the same line: all are detected and added to `branches`.
- Inline link where the referenced file doesn't exist: rendered as plain text (display text only, no link) in export; `<C-g>o` shows a warning.
- Inline links are preserved across answer regeneration (same as full-line `🌿:` and `🔒:` lines).
