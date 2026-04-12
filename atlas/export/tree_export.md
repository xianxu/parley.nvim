# Tree Export

Triggered automatically when exported chat has `🌿:` links. Walks parent chain to root, recursively collects all descendants, exports every file in tree.

## Navigation Links
- Parent: `<- Back to: <topic>` breadcrumb at top
- Children: `-> Branch: <topic>` inline
- HTML uses relative `<a href>`, Markdown uses Jekyll `{% post_url %}` syntax

## Edge Cases
Missing files get plain text labels (no link). Circular refs tracked via visited set. Dangling branches skipped with summary printed after export.
