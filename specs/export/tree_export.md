# Tree Export

- Triggered automatically when exported chat has `🌿:` links; single-file fallback if none

## Tree Discovery
- Walk up `parent_link` to find root (no parent), then recursively collect all descendants via `branches`
- Export every file in tree

## Navigation Links
- **Parent** (`🌿:` after header): rendered as `← Back to: <topic>` breadcrumb at top
- **Children** (inline `🌿:`): rendered as `→ Branch: <topic>` inline

## Format-Specific Links
- **HTML**: relative `<a href="...">` with `{date}-{sanitized_title}.html` filenames
- **Markdown**: Jekyll `{% post_url 2026-02-16-slug %}` syntax

## Link Target Resolution
- Read referenced chat's header for topic/date/tags, apply same filename sanitization as export

## Edge Cases
- Missing file: plain text label (no link) + warning logged
- Circular refs: track visited files
- Dangling branches: skipped, summary printed after export

## Content Cleaning
- Same per-file rules: exclude `🧠:`, `📝:`, `🔒:`; format `@@`; replace `💬:` with `## Question`
