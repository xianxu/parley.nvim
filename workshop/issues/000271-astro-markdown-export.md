---
id: 000271
status: open
deps: []
github_issue:
created: 2026-09-19
updated: 2026-09-19
estimate_hours:
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

## Spec

- **Astro format.** The markdown export writes `<slug>.md` with front matter
  `title`, `publishDate`, `published`, `tags` (YAML list), `comments`, plus
  `hidden` and `excerpt` when the chat header sets them. It drops `layout` and
  `date`. The body keeps what it has now: the `<style>` block, the parley.nvim
  watermark and `## Question` headings.
- **Destination.** `<C-g>em` asks for a destination path, pre-filled with
  `export_markdown_dir` (or the last one used), so a post can go straight into
  `xianxu.dev/src/data/post/`. `:ParleyExportMarkdown [dir]` keeps working
  without the prompt.
- **Tree export.** Branch links, including the inline `class="branch-inline"`
  anchors, become relative `./<slug>.md` markdown links. xianxu.dev's
  `relativePostLinksRemarkPlugin` (`src/utils/frontmatter.ts:66`) rewrites those
  into permalinks. It works on markdown link nodes, so the raw `<a href>` anchors
  need checking.

Open questions (settle at claim):
1. Does Jekyll output go away, or stay behind a config/format option? Nothing
   seems to use it any more.
2. Should `published` default to `true`, or to `false` so the post can be
   previewed in dev first?
3. On re-export over an existing `<slug>.md`: should fields added by hand
   (`excerpt`, `highlight`, `project`, `published`) be kept, or should it ask
   before overwriting?

Related: #211 (neutral export-dir defaults) and #243 (unescaped branch topics in
export; its `post_url` check changes shape here).

## Done when

- In a chat buffer, `<C-g>em` asks for a destination and writes `<slug>.md` with
  Astro front matter there. `:ParleyExportMarkdown <dir>` still exports without
  asking.
- An export written into `xianxu.dev/src/data/post/` builds (`npm run build`) and
  appears in production at `/YYYY/MM/<slug>` with the chat's date, with no hand
  edits.
- A tree export's branch links resolve to the sibling posts on the built site.
- `tests/integration/export_spec.lua` and `tree_export_spec.lua` cover the new
  format and the destination prompt. `atlas/export/formats.md` describes it.

## Plan

- [ ]

## Log

### 2026-09-19

Filed from a parli session. The operator remembered moving from HTML to markdown
export for the blog but not whether the front matter needed converting. It does:
see the table in Problem, derived from xianxu.dev's content schema and
`blog.ts`. The operator's proposal: `<C-g>em` takes a destination path and writes
the Astro format.
