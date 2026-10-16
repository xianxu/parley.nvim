---
id: 000243
status: working
deps: []
github_issue:
created: 2026-09-13
updated: 2026-10-16
estimate_hours:
card_mirror: '98522bdee497d6483c38a6f749c0e79c14abb238' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-16T00:44:49-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "3904125b", done: "f76a2a6e"}
---

# HTML export: branch topic is inserted unescaped by make_branch_div

## Problem

Found during #231's M2 review (2026-09-13). `exporter.make_branch_div` inserts
the branch **topic** into the exported HTML without escaping `<`, `>`, `&` or
`"`. A topic containing `<script>` lands raw in the export. The placeholder
mechanism around it is now non-recursive (#231 BR-9), so this is the separate
output-escaping class, not placeholder recursion. The markdown export's Jekyll
`{% post_url %}` form and the inline branch anchors should be checked for the
same gap.

## Spec

The class: every chat string the exporter writes into HTML. On the branch
path (the first scope, widened by close review BR-1) that is the following. These are the nav div (`make_branch_div`) and the inline link (now
`make_branch_anchor`), in both formats. HTML restores them after
`simple_markdown_to_html`'s escape, and Markdown carries them as raw HTML
blocks, so neither format escapes them later. The topic and href are escaped
where the string is built, by one `escape_html` (`&`, `<`, `>`, `"`). Plain-text
fallbacks (an inline link with no target) are body text and follow their
format's body handling.

Checked, not changed: the Jekyll `post_url` slug is the post date plus
`sanitize_title`'s letters, digits, `_` and `-`, except the basename fallback
for an empty title. The attribute escape covers HTML there.

## Core concepts

| Concept | Meaning |
|---|---|
| `escape_html` | escapes chat text for HTML text or a double-quoted attribute |
| `make_branch_anchor` | builds the inline branch link, escaped like `make_branch_div` |

## Done when

- [x] A branch topic containing `<script>`, `&` or `"` is escaped in the nav div and the inline link, in both the HTML and the Markdown export.
- [x] The href is escaped as an attribute value.
- [x] An end-to-end HTML export of such a chat has no raw topic in the page, `<title>` included.

## Plan

- [x] `escape_html` and `make_branch_anchor`; `make_branch_div` escapes the topic and href.
- [x] Red-first unit cases (Group G2, 7 cases) and the end-to-end export case (A0).
- [x] Atlas: `export/tree_export.md` records where the escaping happens.

## Log

### 2026-09-13

### 2026-10-16

- Taken by parley.nvim:3. Red: all 7 Group G2 cases failed on the old code, and A0
  failed on the old code ("raw topic 1 in the page"). Green: exporter_tree_spec
  44/44, export_spec 16/16, tree_export_spec 13/13, luacheck clean.
- Close review round 1, BR-1 (Important): the HTML page's `<title>` took the
  chat topic raw. The class is any chat string written into HTML, not only
  branches. The sweep found the title (now escaped), the body (escaped since
  #231), and the Jekyll title (YAML, `''`-quoted, not HTML). A0 now gives the
  root a `<script>` topic, and a mutation removing the title escape fails it
  ("title not escaped"). Minor: `simple_markdown_to_html`'s own three gsubs and
  the image quote escape now use `escape_html`. Since the body escape covers
  `"`, the image attributes need no second pass. 44/16/13 green.

## Revisions

- 2026-10-16: the scope widens from the branch path to every chat string the
  export writes into HTML (BR-1). The page title is added; the body escape is
  single-sourced in `escape_html`.
