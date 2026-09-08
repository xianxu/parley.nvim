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

### What `<M-i>` does (#214 M3)

`<M-i>` / `<M-S-CR>` / `<C-g>i` are one binding. The chord **inserts a branch
reference at the cursor** and creates the child it points at:

| context | what happens | the child gets |
|---|---|---|
| visual selection | the selection becomes an inline `[🌿:…](child)` anchor, in place | `tell me more about "<sel>"` |
| pending `<M-q>` markers | the markers are gathered and stripped exactly as `<M-CR>` would strip them; a `🌿:` line lands at the cursor | those quote blocks as its first question |
| neither | a bare `🌿:` line at the cursor — a **placeholder** — and the child opens for you to type in | nothing |

**Placement is the cursor, deliberately** (operator, 2026-09-07, revising an
earlier end-of-answer rule). `<M-S-CR>` reads as a *submission*, whose effect is
not local to anywhere — but `<M-S-CR>` does not survive most terminals (zellij,
tmux, anything without CSI-u), so `<M-i>` is the key people actually press, and
it reads as an *insertion*. Relocating the line made the keypress jump.

**The cost, measured.** `🌿:` sets the parser's `line_before_local` — the same
mechanism `🔒:` uses to mark a local section — so a reference in the MIDDLE of an
answer excludes the text after it from the LLM context, and
`exchange_model.from_parsed_chat` truncates that exchange (its `summary` block
disappears, `append_pos` moves into the middle). Placing the reference at the end
of an answer avoids this entirely, which is why the first design did. This is
pre-existing behaviour — the pre-#214 path also inserted at the cursor — and the
operator's call is that a key that reads as "insert" must insert where you are.
Fixing it properly means teaching the parser that a standalone `🌿:` is a
one-line annotation rather than a local-section boundary.

**The chord never deletes.** An earlier M3 draft had it copy the question into
the child and delete the answer it replaced, mirroring `<M-CR>`'s resubmit. That
is coherent for a *submission* but not for an *insertion*, and the three keys
share one callback — so the destructive reading would have been reachable from
the key that says "insert here". Dropped.

**Refusals.** The chord declines while the buffer owns a pending response — a
streaming answer holds a chat lease on its `🤖:` line, and editing under it
corrupts the transcript rather than erroring.

- **Normal / insert mode, chat buffer, nothing to submit**: inserts a full-line
  `🌿: <filename>: `, creates the child, saves the parent, and **opens the
  child** — the question is typed there. Before #214 this path created no file at
  all, so it wrote a reference to something that did not exist.
- **Normal / insert mode, foreign markdown**: inserts the reference and puts the
  cursor on it in insert mode. No child, no write.
- Every child created without a selection starts with `topic: ?` — including the
  M3 question and quotes cases, whose reference line carries the question text as
  its *display label* while the child's own topic stays the sentinel the lifecycle
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
