# Export Formats

## HTML (`:ParleyExportHTML [dir]`)
Self-contained HTML with inline CSS. Title from `# topic:` line; path copied to `+` register.

## Markdown/Jekyll (`:ParleyExportMarkdown [dir]`)
Jekyll `.md` with YAML front matter (`title`, `date`, `tags`, `layout`). Title/date/tags extracted from chat header.

## Tree Export
If chat has `🌿:` links, both commands auto-export entire tree (see `tree_export.md`).

## Content Cleaning (both formats)
Exclude `🧠:`, `📝:`, `🔒:`; convert `🌿:` to navigation links; format `@@` file references.
