# Inline Branch Links

## Syntax
- `[🌿:display text](file.md)` — inline within any line (vs full-line `🌿:` on its own line)

## Creation (`<M-i>`, `<M-S-CR>`, `<C-g>i`)
One action, one implementation: `branch_inserters(buf, abs_link)` in `init.lua`,
with the pure line editing in `lua/parley/branch_ref.lua`. Chat and markdown
buffers differ **only** in the link target — chat links its sibling by basename,
markdown by absolute path — so the two used to be four near-identical functions
that had drifted (#214).

- **Visual mode**: wraps the selection as `[🌿:selected text](target)` and creates
  the child with topic `what is "selected text"`.
- **Normal / insert mode**: inserts a full-line `🌿: <filename>: `, creates the
  child, and **opens it** — the question is typed in the child, not on the
  parent's ref line. Before #214 this path created no file at all, so it wrote a
  reference to something that did not exist; that gap is what made the two
  invocations feel like different actions.
- The no-selection child starts with an **empty topic**. It gains its slug on
  first write (the `ParleySlug` `BufWritePost` autocmd, which skips an empty or
  `?` topic), and the parent's link keeps resolving because `resolve_chat_path`
  falls back to globbing the timestamp for any slug variant
  (`init.lua:2812-2816`).
- Child gets a `🌿:` parent back-link.

## Parser
- Detected by `parse_chat`, added to `parsed.branches` with `{ path, topic, line, after_exchange }`
- Context unpacking: `[🌿:text](file)` => `text` in LLM context
- Containing line is NOT excluded (unlike full-line `🌿:`)
- Multiple inline links per line supported

## Navigation
- `<C-g>o` on inline link opens referenced file
- `<C-g>o` on full-line `🌿:` references works from both chat and markdown buffers (shared `open_branch_ref`)
- Bare filenames resolved by searching base_dir first, then all configured chat roots

## Export
- HTML: `<a href="child.html" class="branch-inline">display text</a>`
- Jekyll: `<a href="{% post_url slug %}" class="branch-inline">display text</a>`

## Edge Cases
- Missing file: rendered as plain text in export; `<C-g>o` warns
- Preserved across answer regeneration
- Included in tree traversal and collision detection
