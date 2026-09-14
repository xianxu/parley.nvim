# Export Formats

## HTML (`:ParleyExportHTML [dir]`)
HTML with inline page CSS. Title comes from `topic:` (or legacy `# topic:`); the
output path is copied to the `+` clipboard register. It is not fully self-contained:
syntax highlighting loads highlight.js CSS/JS from a CDN, and images use copied
local asset files. Keep the exported `assets/` directory beside the HTML.

The chat-specific HTML exporter does not require pandoc.

## Markdown/Jekyll (`:ParleyExportMarkdown [dir]`)
Jekyll `.md` with YAML front matter (`title`, `date`, `tags`, `layout`). Title/date/tags extracted from chat header.

The chat-specific Markdown exporter also does not require pandoc.

## Ordinary Markdown to HTML (`<C-g>eh`)

In a non-chat Markdown buffer, the same export shortcut invokes a separate
pandoc path. This requires the `pandoc` executable (`brew install pandoc` on
macOS, or `sudo apt install pandoc` on Debian/Ubuntu). The buffer must have a
filename; modified text is saved before conversion. The output is a neighboring
`.html` file, generated with `pandoc -s --self-contained`, and its path is copied
to the clipboard. Missing pandoc produces an installation hint. This path is
`exporter.pandoc_export_html`, not the `:ParleyExportHTML` chat command.

## Tree Export
If chat has `🌿:` links, both commands auto-export entire tree (see [Tree Export](tree_export.md)).

## Content Cleaning (both formats)
Exclude `🧠:`, `📝:`, `🔒:`; convert `🌿:` to navigation links; format `@@` file references.

## Destination and requirements

An explicit `[dir]` overrides `export_html_dir` or `export_markdown_dir`. Defaults
are `exports/html` and `exports/markdown` beneath Parley's data directory. The
current buffer must be a recognized chat with a valid header. The current chat's
unsaved buffer text is exported; other tree members are read from disk.

## Implementation and checks

`lua/parley/exporter.lua` owns metadata extraction, tree discovery, cleaning,
and writers; `lua/parley/config.lua` owns destination defaults. See
`tests/integration/export_spec.lua`, `tests/integration/tree_export_spec.lua`,
and `tests/unit/exporter_tree_spec.lua`.
