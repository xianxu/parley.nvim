# Spec: Export Formats

## Overview
Parley exports chat buffers to blog-ready formats like Jekyll HTML and Markdown.

## Export to Jekyll HTML
### Command: `:ParleyExportHTML [dir]`
- Generates a self-contained HTML file.
- **Title**: Extracted from the `# topic:` line.
- **Styling**: Inline CSS for syntax highlighting and layout.
- **Output**: Written to `export_html_dir` or the provided argument.
- **Clipboard**: Full path of the generated file is copied to the system clipboard (`+` register).

## Export to Markdown (Jekyll)
### Command: `:ParleyExportMarkdown [dir]`
- Generates a Jekyll-compatible `.md` file with YAML front matter.
- **Front Matter Fields**: `title`, `date`, `tags`, `layout`, `comments`.
- **Title**: Extracted from the `# topic:` line.
- **Date**: Extracted from the timestamp prefix in the `- file:` header.
- **Tags**: Extracted from the `- tags:` header (defaults to `"unclassified"`).
- **Output**: Written to `export_markdown_dir` or the provided argument.
- **Clipboard**: Full path of the generated file is copied to the system clipboard (`+` register).
- **Styling**: Injects a `<style>` block after front matter with header colors matching the HTML export (h1: `#1a365d`, h2: `#2b6cb0`, h3: `#3182ce`).
- **Question headings**: `💬:` is replaced with `## Question` for blog-friendly rendering.

## Content Cleaning
- Excludes `🧠:` thinking lines and `📝:` summary lines from the exported file.
- Excludes local `🔒:` sections from the output.
- Formats `@@` file references for improved readability in the exported document.
