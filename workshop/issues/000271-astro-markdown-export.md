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

A third gap: in a chat, tool blocks and summary lines are folded by default
because they are data rather than reading. The export flattens them, so a
published transcript shows every `📝:` summary and tool result at full length,
and a reader has to scroll past machine bookkeeping to follow the conversation.

## Spec

- **Astro format.** The markdown export writes `<slug>.md` with front matter
  `title`, `publishDate`, `published`, `tags` (YAML list), `comments`, plus
  `hidden` and `excerpt` when the chat header sets them. It drops `layout` and
  `date`. The body keeps the parley.nvim watermark and the `## Question`
  headings; the `<style>` block leaves, per **Styles move to the site** below.
- **Destination.** `<C-g>em` asks for a destination path, pre-filled with
  `export_markdown_dir` (or the last one used), so a post can go straight into
  `xianxu.dev/src/data/post/`. `:ParleyExportMarkdown [dir]` keeps working
  without the prompt.
- **Tree export.** Branch links, including the inline `class="branch-inline"`
  anchors, become relative `./<slug>.md` markdown links. xianxu.dev's
  `relativePostLinksRemarkPlugin` (`src/utils/frontmatter.ts:66`) rewrites those
  into permalinks. It works on markdown link nodes, so the raw `<a href>` anchors
  need checking.
- **Hidden by default.** Every exported chat gets `hidden: true`, the root
  included — a transcript should be reachable by link, not advertised in the blog
  listing. `published: true` still goes with it: the post is public, just not on
  a shelf. An operator who wants one listed deletes the line.
  Caveat, and it is a site-side gap rather than an export one: on xianxu.dev
  today `hidden` filters the home page, the blog list and tag pages, but
  `src/pages/rss.xml.ts` calls `fetchPosts()` unfiltered and `@astrojs/sitemap`
  takes every built page. Verified on a real build: all three parli transcripts
  appear in `dist/rss.xml` and `dist/sitemap-0.xml`. So "hidden" currently means
  unlisted, not undiscoverable — subscribers and crawlers still get them. If the
  stronger meaning is wanted, that is an xianxu.dev change (filter hidden in the
  RSS route, a `filter` on the sitemap integration, maybe `robots: noindex`).
- **Escape `$`.** xianxu.dev runs `remark-math`, so a bare dollar amount opens
  inline math and swallows everything up to the next `$` — links included. The
  export escapes every unescaped `$` as `\$`, skipping code spans and fenced
  blocks, where `$` is literal and a backslash would corrupt the code. Chats that
  really do contain math are the open question in 8 below.
- **Folds survive the export.** What a chat folds, a post collapses. `📝:`
  summaries, `🧠:` reasoning and `🔧:`/`📎:` tool blocks are wrapped in
  `<details class="parley-aside"><summary>…</summary>`, with a blank line before
  the content and before `</details>` so the body still parses as markdown.
  No JavaScript: the element is native, collapsed by default, and `open` makes
  one start expanded.
- **Styles move to the site.** The export stops writing the per-post `<style>`
  block and emits class names only (`parley-aside`, `branch-nav`, …). The
  stylesheet lives in the site — on xianxu.dev, `src/assets/styles/tailwind.css`.
  This is also a bug fix: the block's colors are hardcoded light, and xianxu.dev
  has class-based dark mode (`darkMode: 'class'`), so today's exported headings
  and link boxes are wrong in dark mode. Ship the stylesheet fragment alongside,
  so the site side is a paste, not a design exercise.

Open questions (settle at claim):
1. Does Jekyll output go away, or stay behind a config/format option? Nothing
   seems to use it any more.
2. Should `published` default to `true`, or to `false` so the post can be
   previewed in dev first?
3. On re-export over an existing `<slug>.md`: should fields added by hand
   (`excerpt`, `highlight`, `project`, `published`) be kept, or should it ask
   before overwriting?
4. **Settled (2026-09-19, operator):** every exported chat is `hidden: true`,
   not just the branches — see **Hidden by default** above. The follow-on
   question is whether the site should also keep hidden posts out of RSS and the
   sitemap; that belongs to xianxu.dev, not here.
5. Assets: `assets.copy_into` copies `assets/<ts>/` beside the export, which
   would put it in `src/data/post/assets/`. Check that Astro resolves relative
   image links from there.
6. Fold or drop? A folded aside is still in the page source, the RSS feed and
   the page weight. If these lines are clutter, fold them; if they should not be
   public at all, exclude them — which is what `atlas/export/formats.md` already
   claims happens to `📝:`. Decide per marker, and say whether it is
   configurable (e.g. `export_fold_prefixes`) or fixed.
7. Do folds belong in the HTML export too? It has the same problem and the same
   `<details>` answer, so the divergence would be arbitrary.
8. Escaping `$` unconditionally breaks a chat that contains real LaTeX, which
   xianxu.dev supports and its `AGENTS.local.md` asks for. Options: always escape
   (math in a transcript is rare), a chat-header opt-out, or detect `$$…$$` and
   leave that chat alone. Whatever the rule, `\$` must not leak into code blocks.

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
- On the built site, every folded marker is a collapsed disclosure that opens on
  click, and its contents (emphasis, links, code blocks) still render as markdown
  inside it.
- Exported posts carry no `<style>` block, and the site stylesheet they rely on
  is legible in both light and dark mode.
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

### 2026-09-19 — hand conversion of a real tree

Converted parli's "Parli debate prep format" tree (a root and two branches) by
hand into xianxu.dev and built it with `npm run build`. The steps are a spec for
the exporter:

- **Styled branch links work in Astro.** The pattern is
  `<div class="branch-nav child-link">`, a blank line, `[→ Topic](./slug.md)`, a
  blank line, `</div>`. `relativePostLinksRemarkPlugin` rewrites the link to
  `/2026/09/slug` and the div keeps its class. Drop kramdown's `markdown="0"`.
- **Q4 in practice:** `hidden: true` on the branches keeps them off the home,
  blog and tag pages, and the root's links to them still resolve.
- **The exporter keeps `📝:` summary lines** in markdown output, although
  `atlas/export/formats.md` says `📝:` is excluded. The one existing Parley post
  on xianxu.dev keeps them too. Either the code or the atlas is wrong; decide
  which.
- **The exporter emits an empty trailing `## Question`** for the chat's open
  `💬:` prompt. Drop it.

### 2026-09-19 — folds, and sequencing

Folded the published-transcript readability problem into this issue rather than
filing a second one: it is the same export pass, and splitting it would mean
touching the writer twice.

`<details>` is verified on xianxu.dev, not assumed. A probe post carrying
`<details class="parley-aside">` with a blank line around its body built and
rendered as a collapsed disclosure, with emphasis, a cross-post link (rewritten
to `/2025/10/how-to-parli`) and a syntax-highlighted code block intact inside it.
The probe was removed afterwards.

Sequencing: the operator wants #261 finished first, then this. Not a blocking
dependency — no `deps:` — just the order of work.

### 2026-09-19 — hidden by default

Operator: transcripts should publish with `hidden: true` by default — on the web,
but not advertised. Folded into Spec; open question 4 is settled.

Measured what `hidden` buys on xianxu.dev, rather than assuming. It keeps a post
off the home page, the blog list and its tag pages. It does not keep it out of
`rss.xml` (the route calls `fetchPosts()` with no filter) or `sitemap-0.xml` (the
sitemap integration takes every built page); both were checked in `dist/` after a
build with all three parli transcripts hidden. Unlisted, then, but not private:
the feed still carries them and the sitemap still hands them to crawlers.

The operator took the three hand-converted posts, added `hidden: true` to the
root, and committed + pushed them (xianxu.dev `c2fc04e`). That commit is the
reference output this issue's exporter has to reproduce without hand edits.

### 2026-09-19 — `$` eats the page, and a stale branch label

Republished the tree with a third branch ("Student debt debate prep"). Two new
defects, both caught on the built and then the live page:

- **Dollar amounts became math.** The student-debt transcript quotes figures like
  `$65,000 with $50,000 canceled would owe roughly $10,850 more ([Money](...))`.
  `remark-math` read the first `$` as an opening delimiter, so the text between
  amounts rendered in KaTeX italics and the Money link was swallowed whole.
  Seven KaTeX spans on one page; the other three transcripts had none, because a
  lone `$` in a paragraph has nothing to pair with. Escaping every `$` as `\$`
  and rebuilding brought it to zero. Now in Spec, with question 8 for chats that
  contain real math. Live evidence before the fix:
  https://xianxu.dev/2026/09/student-debt-debate-prep/
- **The parent's branch label was stale.** The root still carried
  `🌿: 2026-09-19.13-30-49.269.md: ?` — the pre-rename filename and a placeholder
  topic — so the export published a link reading "→ ?". The *reference* still
  resolved (the timestamp glob from #224 found the renamed file), so this is the
  label half of #270, not the path half. Worth folding into #270: a tree export
  should either rewrite the label or read the topic from the target's header
  instead of trusting the `🌿:` line.
