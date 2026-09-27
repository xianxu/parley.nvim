---
id: 000271
status: open
created: 2026-09-19
updated: 2026-09-19
estimate_hours:
github_issue:
---

# Markdown export writes Astro posts to a chosen destination

## Problem

Blog posts now go to xianxu.dev, an Astro (AstroWind) site whose posts live in
`xianxu.dev/src/data/post/*.md`. `<C-g>em` (`:ParleyExportMarkdown`) still writes
the old Jekyll format for xianxu.github.io, so the export has to be converted by
hand before xianxu.dev accepts it. Copying it over unchanged fails like this:

| Export writes | xianxu.dev needs | Unchanged result |
|---|---|---|
| `YYYY-MM-DD-slug.markdown` | `slug.md` | The post is ignored, because the loader globs `*.md`/`*.mdx`. Renaming only the extension gives the URL `/YYYY/MM/YYYY-MM-DD-slug`, because the slug is the file id. |
| `date:` | `publishDate:` | `date` is stripped, and `publishDate` falls back to `new Date()` at build time. The date, URL and sort order change on every build. |
| no `published` | `published: true` | The post is a draft: it shows in dev and is left out of production. |
| `layout: post` | none | Stripped, which is harmless. |
| branch links `{% post_url slug %}` | `./slug.md` | Tree-export links break. |

The schema is in `xianxu.dev/src/content/config.ts`. Defaults and permalinks
(`/%year%/%month%/%slug%`) are in `src/utils/blog.ts`. The one Parley transcript
on the site, `conversation_around_concurrent_programming_models.md`, was converted
by hand when it was first committed there (xianxu.dev `f8d9ea1`).

In addition, `<C-g>em` always writes to `export_markdown_dir`. The only way to
choose a destination is to type `:ParleyExportMarkdown <dir>`.

A third gap: in a chat, tool blocks and summary lines are folded by default
because they are data rather than reading. The export flattens them, so a
published transcript shows every `📝:` summary and tool result at full length,
and a reader has to scroll past machine bookkeeping to follow the conversation.
