# Export Formats

## HTML (`:ParleyExportHTML [dir]`)
- Self-contained HTML with inline CSS
- Title from `# topic:` line; output to `export_html_dir` or arg
- File path copied to `+` register

## Markdown/Jekyll (`:ParleyExportMarkdown [dir]`)
- Jekyll `.md` with YAML front matter (`title`, `date`, `tags`, `layout`, `comments`, `hidden`)
- Title from `# topic:`, date from `- file:` timestamp, tags from `- tags:` (default `"unclassified"`)
- Titles single-quoted in YAML; embedded `'` escaped as `''`
- Injects `<style>` block (h1: `#1a365d`, h2: `#2b6cb0`, h3: `#3182ce`)
- `💬:` replaced with `## Question`
- Output to `export_markdown_dir` or arg; path copied to `+` register

## Tree Export
- If chat has `🌿:` links, both commands auto-export entire tree (see `tree_export.md`)

## Content Cleaning (both formats)
- Exclude: `🧠:` thinking, `📝:` summary, `🔒:` local sections
- Convert `🌿:` to navigation links
- Format `@@` file references for readability
