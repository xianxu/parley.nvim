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

### The chord is one rule (#214 M3)

> `<M-S-CR>` performs the submission `<M-CR>` would perform, into a new child
> chat, and leaves a `🌿:` reference where `<M-CR>`'s output would have appeared.

The parent always keeps its context; the only thing it ever loses is an answer
`<M-CR>` would itself have replaced. `<M-i>` and `<C-g>i` are aliases for the
same action.

| context | `<M-CR>` does | `<M-S-CR>` does | the ref lands |
|---|---|---|---|
| visual selection | inline term definition at the selection | child seeded `tell me more about "<sel>"` | inline `[🌿:<sel>](child)`, in place |
| cursor on a past exchange with `<M-q>` markers | strips them, inserts a new turn after that exchange's answer, original Q/A preserved | those gathered quote blocks become the child's first question | after **that** exchange's `📝:` |
| `<M-q>` markers elsewhere | strips them, appends the new turn at the buffer end | same payload → child | after the **last** exchange's `📝:` |
| cursor on an unanswered question | submits it; the answer appears after it | the question is **copied** to the child | after the question |
| cursor on an answered question | resubmits: the old answer is deleted and regenerated | old answer deleted, question copied to the child | where the answer was |

**Why the reference follows `📝:` and not precedes it.** Measured, not reasoned:
run both layouts through `exchange_model.from_parsed_chat` and the "before"
variant yields blocks `question, agent_header, text` — **the summary block is
gone** — with `append_pos` pointing into the middle of the exchange. After the
summary, the blocks stay contiguous and `append_pos` lands exactly on the
reference line. (At *parse* level the two are indistinguishable, so the parser is
not where this is decided.)

The reference is its own block with one blank line each side, which is the
exchange model's `MARGIN`.

**Refusals.** The chord declines while the buffer owns a pending response — a
streaming answer holds a chat lease on its `🤖:` line, and editing under it
corrupts the transcript rather than erroring. With *nothing* to submit (an empty
transcript, or the cursor outside every exchange) it falls back to the pre-M3
behaviour below rather than doing nothing: generalising the chord must not delete
the "make me a side chat" affordance, and it is never a no-op.

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
