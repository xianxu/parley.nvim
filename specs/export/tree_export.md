# Spec: Tree Export

## Overview
When exporting a chat that is part of a tree (has `🌿:` links), export the entire tree as multiple linked files. Each chat file becomes one exported file, with `🌿:` lines converted to format-appropriate navigation links.

## Behavior

### Tree Discovery
1. From the current file, walk up `parent_link` references to find the root (a file with no parent link).
2. From the root, recursively collect all descendants via `branches`.
3. Export every file in the tree.

### Single-File Fallback
If a chat has no `🌿:` links, behavior is unchanged — exports the single file as today.

### Navigation Link Rendering

**Parent link** (first `🌿:` after header):
- Rendered as a breadcrumb at the top of the exported content: `← Back to: <topic>`
- Links to the exported parent file.

**Child branch links** (inline `🌿:` in body):
- Rendered inline where the branch occurs: `→ Branch: <topic>`
- Links to the exported child file.

### Format-Specific Links

**HTML export:**
- Use relative `<a href="...">` links.
- Target filename derived the same way as the export filename: `{date}-{sanitized_title}.html`.

**Markdown (Jekyll) export:**
- Use Jekyll `{% post_url %}` syntax: `{% post_url 2026-02-16-slug %}`.
- The slug is derived from the target file's headers (date + sanitized topic), matching the exported filename without extension.

### Filename Resolution
To generate the correct link target for a `🌿:` reference:
1. Read the referenced chat file's header to extract `topic`, `file`, `tags`, and date.
2. Apply the same filename sanitization logic used by `export_html`/`export_markdown`.
3. This ensures the link target matches the actual exported filename.

## Edge Cases
- **Missing file**: If a `🌿:` reference points to a file that doesn't exist, render as plain text label (no link) and log a warning.
- **Circular references**: Track visited files during tree traversal to avoid infinite loops.
- **Dangling branches**: Files referenced but not found are skipped during tree export; a summary of skipped files is printed after export.

## Content Cleaning (unchanged)
All existing content cleaning rules apply per-file:
- Exclude `🧠:` thinking lines, `📝:` summary lines, `🔒:` local sections.
- Format `@@` file references.
- Replace `💬:` with `## Question`.
