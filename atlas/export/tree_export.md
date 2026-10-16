# Tree Export

Triggered automatically when exported chat has `🌿:` links. Takes the tree from `chat_tree.root` and `chat_tree.files` (#349): the root as the request context sees it, then every descendant depth-first, read from disk. It exports every file in the tree.

## Navigation Links
- Parent: `<- Back to: <topic>` breadcrumb at top
- Children: `-> Branch: <topic>` inline
- HTML uses relative `<a href>`, Markdown uses Jekyll `{% post_url %}` syntax
- The topic and href are HTML-escaped where each link is built (`make_branch_div`,
  `make_branch_anchor`). Neither format escapes them later: HTML restores the
  link after the body's escape, and Markdown carries it as a raw HTML block (#243).
  The page `<title>` and the body go through the same `escape_html`.

## Edge Cases
Missing files get plain text labels (no link). Circular refs tracked via visited set. Dangling branches skipped with summary printed after export.

## Assets (#231)
- Each exported chat's `assets/<ts>/` folder is copied beside the exported files (`assets.copy_into`); HTML renders `![…](…)` as `<img class="asset-image">` via the same placeholder mechanism as branch links. Relative links resolve for an HTML export opened from disk; a Jekyll `_posts/` URL does not resolve them. A failed copy is reported, never silent.

## Implementation and checks

`lua/parley/exporter.lua` owns link rewriting and supplies the walker its loader;
`lua/parley/assets.lua` owns sidecar copying. See
`tests/integration/tree_export_spec.lua` and `tests/unit/exporter_tree_spec.lua`.
[Export Formats](formats.md) describes commands, destinations, and offline limits.
