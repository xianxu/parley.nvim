# Inline Branch Links

## Syntax
- `[🌿:display text](file.md)` — inline within any line (vs full-line `🌿:` on its own line)

## Creation (`<M-i>`, `<M-S-CR>`, `<C-g>i`)
One implementation — `branch_inserters(buf, abs_link)` in `init.lua`, with the
pure line editing in `lua/parley/branch_ref.lua`. It replaced four
near-identical functions that had drifted (#214).

**The two buffer types get different guarantees, deliberately.** A chat buffer is
parley's own file, so it can commit the reference; a foreign markdown document is
not, and `:write` would persist the user's unrelated pending edits.

| | chat buffer | foreign markdown |
|---|---|---|
| inserts the `🌿:` reference | yes | yes |
| creates the child on disk | yes | **no** — it would be an orphan reachable only through an unsaved line |
| saves the parent | yes | **no** — never writes a file parley does not own |
| after the keypress | opens the child | cursor on the new line, insert mode |

- **Visual mode**: wraps the selection as `[🌿:selected text](target)` and creates
  the child with topic `what is "selected text"`.
- **Normal / insert mode, chat buffer**: inserts a full-line `🌿: <filename>: `,
  creates the child, saves the parent, and **opens the child** — the question is
  typed there. Before #214 this path created no file at all, so it wrote a
  reference to something that did not exist.
- **Normal / insert mode, foreign markdown**: inserts the reference and puts the
  cursor on it in insert mode. No child, no write.
- The no-selection child starts with `topic: ?` — the sentinel the lifecycle
  keys off. `?` (not `""`) is what makes auto-titling fire on first respond;
  an empty topic left the child permanently anonymous (#214 BR-1). It gains its slug on
  first write (the `ParleySlug` `BufWritePost` autocmd, which skips an empty or
  `?` topic), and the parent's link keeps resolving because `resolve_chat_path`
  falls back to globbing the timestamp for any slug variant.
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
