# Tree Export

Triggered automatically when exported chat has `🌿:` links. Walks parent chain to root, recursively collects all descendants, exports every file in tree.

## Navigation Links
- Parent: `<- Back to: <topic>` breadcrumb at top
- Children: `-> Branch: <topic>` inline
- HTML uses relative `<a href>`, Markdown uses Jekyll `{% post_url %}` syntax

## Edge Cases
Missing files get plain text labels (no link). Circular refs tracked via visited set. Dangling branches skipped with summary printed after export.

## Assets (#231)
- Each exported chat's `assets/<ts>/` folder is copied beside the exported files (`assets.copy_into`); HTML renders `![…](…)` as `<img class="asset-image">` via the same placeholder mechanism as branch links. Relative links resolve for an HTML export opened from disk; a Jekyll `_posts/` URL does not resolve them. A failed copy is reported, never silent.
